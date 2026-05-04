-- 10.12C1: Intake Backend -- Manual Deal Creation + Draft Promotion tests
BEGIN;

SELECT plan(20);

-- ============================================================
-- Tenant A: member user + slug (primary flows)
-- Tenant B: member user + slug (cross-tenant promote)
-- ============================================================
SELECT public.create_active_workspace_seed_v1(
  'c12ca000-0000-4000-8000-000000000001'::uuid,
  'c12cb000-0000-4000-8000-000000000001'::uuid,
  'member'
);

SELECT public.create_active_workspace_seed_v1(
  'c12ca000-0000-4000-8000-000000000002'::uuid,
  'c12cb000-0000-4000-8000-000000000002'::uuid,
  'member'
);

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES
  ('c12ca000-0000-4000-8000-000000000001', 'test-12c1-a'),
  ('c12ca000-0000-4000-8000-000000000002', 'test-12c1-b')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 1–2. schema: promotion marker + intake ↔ draft link
-- ============================================================
SELECT has_column('public', 'draft_deals', 'promoted_deal_id',
  'draft_deals.promoted_deal_id column exists');

SELECT has_column('public', 'intake_submissions', 'draft_deals_id',
  'intake_submissions.draft_deals_id column exists');

-- ============================================================
-- 3. submit_form_v1 persists draft_deals_id on intake row (1:1)
-- ============================================================
SELECT public.submit_form_v1(
  'test-12c1-a', 'seller',
  '{"spam_token":"s1","address":"100 Intake Ln","name":"Public Name","phone":"555-1000","email":"pub@example.com"}'::jsonb
);

SET LOCAL ROLE postgres;
SELECT is(
  (
    SELECT isub.draft_deals_id = dd.id
    FROM public.intake_submissions isub
    JOIN public.draft_deals dd ON dd.id = isub.draft_deals_id
    WHERE isub.tenant_id = 'c12ca000-0000-4000-8000-000000000001'
      AND isub.form_type = 'seller'
    ORDER BY isub.submitted_at DESC
    LIMIT 1
  ),
  true,
  'submit_form_v1: intake_submissions.draft_deals_id links to draft_deals row'
);

-- ============================================================
-- Context: authenticated member, tenant A
-- ============================================================
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"c12cb000-0000-4000-8000-000000000001","role":"authenticated","tenant_id":"c12ca000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

-- ============================================================
-- 4–6. create_deal_from_intake_v1: ok, stage=new, tenant-scoped
-- ============================================================
SELECT is(
  (public.create_deal_from_intake_v1(
    '{"address":"200 Manual St","seller_name":"Manual Seller","seller_phone":"555-2000"}'::jsonb
  )->>'code'),
  'OK',
  'create_deal_from_intake_v1: returns code OK on success'
);

SET LOCAL ROLE postgres;
SELECT is(
  (
    SELECT stage FROM public.deals
    WHERE tenant_id = 'c12ca000-0000-4000-8000-000000000001'
      AND address = '200 Manual St'
    ORDER BY created_at DESC LIMIT 1
  ),
  'new',
  'create_deal_from_intake_v1: deal stage is new'
);

SELECT is(
  (
    SELECT tenant_id FROM public.deals
    WHERE tenant_id = 'c12ca000-0000-4000-8000-000000000001'
      AND seller_name = 'Manual Seller'
    ORDER BY created_at DESC LIMIT 1
  ),
  'c12ca000-0000-4000-8000-000000000001'::uuid,
  'create_deal_from_intake_v1: deal is tenant-scoped'
);

-- ============================================================
-- 7–8. property + pricing snapshot (deal_properties + deal_inputs.mao)
-- ============================================================
SET LOCAL ROLE authenticated;
SELECT is(
  (public.create_deal_from_intake_v1(
    jsonb_build_object(
      'address', '300 Prop Rd',
      'seller_email', 'prop@example.com',
      'property', jsonb_build_object(
        'condition_notes', 'Roof wear',
        'year_built', '1998',
        'repair_estimate', '12000'
      ),
      'assumptions', jsonb_build_object(
        'arv', '250000',
        'repair_estimate', '15000',
        'multiplier', '0.72',
        'assignment_fee', '0'
      )
    )
  )->>'code'),
  'OK',
  'create_deal_from_intake_v1: succeeds with property + assumptions'
);

SET LOCAL ROLE postgres;
SELECT is(
  (
    SELECT condition_notes FROM public.deal_properties dp
    JOIN public.deals d ON d.id = dp.deal_id AND d.tenant_id = dp.tenant_id
    WHERE d.tenant_id = 'c12ca000-0000-4000-8000-000000000001'
      AND d.address = '300 Prop Rd'
  ),
  'Roof wear',
  'create_deal_from_intake_v1: deal_properties.condition_notes persisted'
);

SELECT is(
  (
    SELECT ROUND((di.assumptions->>'mao')::numeric)
    FROM public.deal_inputs di
    JOIN public.deals d ON d.assumptions_snapshot_id = di.id
    WHERE d.tenant_id = 'c12ca000-0000-4000-8000-000000000001'
      AND d.address = '300 Prop Rd'
  ),
  ROUND((250000::numeric * 0.72) - 15000::numeric - 0::numeric),
  'create_deal_from_intake_v1: deal_inputs.assumptions.mao computed server-side'
);

-- ============================================================
-- 9–10. validation envelopes (no silent swallow)
-- ============================================================
SET LOCAL ROLE authenticated;
SELECT is(
  (public.create_deal_from_intake_v1(
    '{"assumptions":{"arv":"not-a-number"}}'::jsonb
  )->>'code'),
  'VALIDATION_ERROR',
  'create_deal_from_intake_v1: invalid arv → VALIDATION_ERROR'
);

SELECT is(
  (public.create_deal_from_intake_v1(
    '{"property":{"year_built":"nineteen"}}'::jsonb
  )->>'code'),
  'VALIDATION_ERROR',
  'create_deal_from_intake_v1: invalid year_built → VALIDATION_ERROR'
);

-- ============================================================
-- Draft for promote: fresh seller submission (lookup id as postgres — draft_deals not client-readable)
-- ============================================================
RESET ROLE;
SELECT public.submit_form_v1(
  'test-12c1-a', 'seller',
  '{"spam_token":"s2","address":"400 Draft Ave","name":"Draft Seller","phone":"555-4000","email":"draft@example.com"}'::jsonb
);

SET LOCAL ROLE postgres;
DROP TABLE IF EXISTS _12c1_draft_id;
CREATE TEMP TABLE _12c1_draft_id (id uuid PRIMARY KEY);
INSERT INTO _12c1_draft_id (id)
SELECT id FROM public.draft_deals
WHERE tenant_id = 'c12ca000-0000-4000-8000-000000000001'
  AND payload->>'address' = '400 Draft Ave'
ORDER BY created_at DESC
LIMIT 1;
GRANT SELECT ON TABLE _12c1_draft_id TO authenticated;

-- ============================================================
-- 11–14. promote_draft_deal_v1: success, reviewed_at, promoted_deal_id, deal stage
-- ============================================================
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"c12cb000-0000-4000-8000-000000000001","role":"authenticated","tenant_id":"c12ca000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.promote_draft_deal_v1(
    (SELECT id FROM _12c1_draft_id),
    '{"seller_name":"Reviewed Overlay","assumptions":{"arv":"200000","repair_estimate":"10000","multiplier":"0.65","assignment_fee":"5000"}}'::jsonb
  )->>'code'),
  'OK',
  'promote_draft_deal_v1: returns code OK'
);

SET LOCAL ROLE postgres;
SELECT is(
  (
    SELECT seller_name FROM public.deals
    WHERE tenant_id = 'c12ca000-0000-4000-8000-000000000001'
      AND address = '400 Draft Ave'
    ORDER BY created_at DESC LIMIT 1
  ),
  'Reviewed Overlay',
  'promote_draft_deal_v1: reviewed seller_name overlays draft payload name'
);

SELECT isnt(
  (
    SELECT reviewed_at FROM public.intake_submissions
    WHERE tenant_id = 'c12ca000-0000-4000-8000-000000000001'
      AND draft_deals_id = (SELECT id FROM _12c1_draft_id)
  ),
  NULL,
  'promote_draft_deal_v1: intake_submissions.reviewed_at is set'
);

SELECT is(
  (
    SELECT promoted_deal_id IS NOT NULL
    FROM public.draft_deals
    WHERE id = (SELECT id FROM _12c1_draft_id)
  ),
  true,
  'promote_draft_deal_v1: draft_deals.promoted_deal_id is set'
);

-- ============================================================
-- 15. duplicate promote → CONFLICT
-- ============================================================
SET LOCAL ROLE authenticated;
SELECT is(
  (public.promote_draft_deal_v1(
    (SELECT id FROM _12c1_draft_id),
    '{}'::jsonb
  )->>'code'),
  'CONFLICT',
  'promote_draft_deal_v1: duplicate promote → CONFLICT'
);

-- ============================================================
-- 16. cross-tenant promote → NOT_FOUND
-- ============================================================
RESET ROLE;
SELECT public.submit_form_v1(
  'test-12c1-b', 'seller',
  '{"spam_token":"s3","address":"500 Other","name":"Other","phone":"555-5000","email":"other@example.com"}'::jsonb
);

SET LOCAL ROLE postgres;
DROP TABLE IF EXISTS _12c1_b_draft_id;
CREATE TEMP TABLE _12c1_b_draft_id (id uuid PRIMARY KEY);
INSERT INTO _12c1_b_draft_id (id)
SELECT id FROM public.draft_deals
WHERE tenant_id = 'c12ca000-0000-4000-8000-000000000002'
  AND payload->>'address' = '500 Other'
ORDER BY created_at DESC
LIMIT 1;
GRANT SELECT ON TABLE _12c1_b_draft_id TO authenticated;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"c12cb000-0000-4000-8000-000000000001","role":"authenticated","tenant_id":"c12ca000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.promote_draft_deal_v1(
    (SELECT id FROM _12c1_b_draft_id),
    '{}'::jsonb
  )->>'code'),
  'NOT_FOUND',
  'promote_draft_deal_v1: cross-tenant draft → NOT_FOUND'
);

-- ============================================================
-- 17. no tenant in JWT and no profile default → NOT_AUTHORIZED
--     (current_tenant_id() COALESCE prefers user_profiles over JWT)
-- ============================================================
RESET ROLE;
UPDATE public.user_profiles
SET current_tenant_id = NULL
WHERE id = 'c12cb000-0000-4000-8000-000000000001';

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"c12cb000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.create_deal_from_intake_v1('{"address":"no tenant"}'::jsonb)->>'code'),
  'NOT_AUTHORIZED',
  'create_deal_from_intake_v1: missing tenant context → NOT_AUTHORIZED'
);

-- Restore profile tenant for expired-subscription test
RESET ROLE;
UPDATE public.user_profiles
SET current_tenant_id = 'c12ca000-0000-4000-8000-000000000001'
WHERE id = 'c12cb000-0000-4000-8000-000000000001';

-- ============================================================
-- 18. expired subscription → WORKSPACE_NOT_WRITABLE
-- ============================================================
RESET ROLE;
UPDATE public.tenant_subscriptions
SET current_period_end = now() - interval '1 day'
WHERE tenant_id = 'c12ca000-0000-4000-8000-000000000001';

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"c12cb000-0000-4000-8000-000000000001","role":"authenticated","tenant_id":"c12ca000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.create_deal_from_intake_v1('{"address":"expired ws"}'::jsonb)->>'code'),
  'WORKSPACE_NOT_WRITABLE',
  'create_deal_from_intake_v1: expired workspace → WORKSPACE_NOT_WRITABLE'
);

-- ============================================================
-- 19–20. EXECUTE: authenticated-only surface
-- ============================================================
SET LOCAL ROLE postgres;
SELECT ok(
  has_function_privilege('authenticated', 'public.create_deal_from_intake_v1(jsonb)', 'EXECUTE')
  AND has_function_privilege('authenticated', 'public.promote_draft_deal_v1(uuid, jsonb)', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'public.create_deal_from_intake_v1(jsonb)', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'public.promote_draft_deal_v1(uuid, jsonb)', 'EXECUTE'),
  'create_deal_from_intake_v1 / promote_draft_deal_v1: EXECUTE granted to authenticated only (not anon)'
);

SELECT finish();
ROLLBACK;
