-- 10.12C6: get_draft_deal_v1 — draft read path for Lead Intake pre-fill
BEGIN;

SELECT plan(7);

SELECT public.create_active_workspace_seed_v1(
  'c12c6000-0000-4000-8000-000000000001'::uuid,
  'c12c6000-0000-4000-8000-0000000000b1'::uuid,
  'member'::public.tenant_role
);

SELECT public.create_active_workspace_seed_v1(
  'c12c6000-0000-4000-8000-000000000002'::uuid,
  'c12c6000-0000-4000-8000-0000000000b2'::uuid,
  'member'::public.tenant_role
);

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES
  ('c12c6000-0000-4000-8000-000000000001', 'test-12c6-a'),
  ('c12c6000-0000-4000-8000-000000000002', 'test-12c6-b')
ON CONFLICT DO NOTHING;

-- Draft in tenant A via public form path
SELECT public.submit_form_v1(
  'test-12c6-a', 'seller',
  '{"spam_token":"c6s1","address":"900 Draft Read Rd","name":"Read Tester","phone":"555-9000","email":"read@example.com"}'::jsonb
);

SET LOCAL ROLE postgres;
DROP TABLE IF EXISTS _12c6_draft_a;
CREATE TEMP TABLE _12c6_draft_a (id uuid PRIMARY KEY);
INSERT INTO _12c6_draft_a (id)
SELECT id FROM public.draft_deals
WHERE tenant_id = 'c12c6000-0000-4000-8000-000000000001'
  AND payload->>'address' = '900 Draft Read Rd'
ORDER BY created_at DESC
LIMIT 1;
GRANT SELECT ON TABLE _12c6_draft_a TO authenticated;

-- Draft in tenant B (cross-tenant probe)
RESET ROLE;
SELECT public.submit_form_v1(
  'test-12c6-b', 'seller',
  '{"spam_token":"c6s2","address":"901 Other Tenant","name":"Other","phone":"555-9001","email":"other@example.com"}'::jsonb
);

SET LOCAL ROLE postgres;
DROP TABLE IF EXISTS _12c6_draft_b;
CREATE TEMP TABLE _12c6_draft_b (id uuid PRIMARY KEY);
INSERT INTO _12c6_draft_b (id)
SELECT id FROM public.draft_deals
WHERE tenant_id = 'c12c6000-0000-4000-8000-000000000002'
  AND payload->>'address' = '901 Other Tenant'
ORDER BY created_at DESC
LIMIT 1;
GRANT SELECT ON TABLE _12c6_draft_b TO authenticated;

-- 1–2. member + tenant A can fetch own draft; payload present for pre-fill
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"c12c6000-0000-4000-8000-0000000000b1","role":"authenticated","tenant_id":"c12c6000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.get_draft_deal_v1((SELECT id FROM _12c6_draft_a))->>'code'),
  'OK',
  'get_draft_deal_v1: valid tenant fetches own draft → OK'
);

SELECT is(
  (
    SELECT (public.get_draft_deal_v1((SELECT id FROM _12c6_draft_a))->'data'->'payload'->>'address')
  ),
  '900 Draft Read Rd',
  'get_draft_deal_v1: payload returned for pre-fill (address)'
);

-- 3. cross-tenant → NOT_FOUND
SELECT is(
  (public.get_draft_deal_v1((SELECT id FROM _12c6_draft_b))->>'code'),
  'NOT_FOUND',
  'get_draft_deal_v1: cross-tenant draft → NOT_FOUND'
);

-- 4. missing draft → NOT_FOUND
SELECT is(
  (public.get_draft_deal_v1('a0000000-0000-4000-8000-000000000099'::uuid)->>'code'),
  'NOT_FOUND',
  'get_draft_deal_v1: missing draft id → NOT_FOUND'
);

-- 5. null draft id → NOT_FOUND
SELECT is(
  (public.get_draft_deal_v1(NULL::uuid)->>'code'),
  'NOT_FOUND',
  'get_draft_deal_v1: null p_draft_id → NOT_FOUND'
);

-- 6. no tenant context → NOT_AUTHORIZED
RESET ROLE;
UPDATE public.user_profiles
SET current_tenant_id = NULL
WHERE id = 'c12c6000-0000-4000-8000-0000000000b1';

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"c12c6000-0000-4000-8000-0000000000b1","role":"authenticated"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.get_draft_deal_v1((SELECT id FROM _12c6_draft_a))->>'code'),
  'NOT_AUTHORIZED',
  'get_draft_deal_v1: no tenant context → NOT_AUTHORIZED'
);

RESET ROLE;
UPDATE public.user_profiles
SET current_tenant_id = 'c12c6000-0000-4000-8000-000000000001'
WHERE id = 'c12c6000-0000-4000-8000-0000000000b1';

-- 7. EXECUTE: authenticated only
SET LOCAL ROLE postgres;
SELECT ok(
  has_function_privilege('authenticated', 'public.get_draft_deal_v1(uuid)', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'public.get_draft_deal_v1(uuid)', 'EXECUTE'),
  'get_draft_deal_v1: EXECUTE to authenticated only (not anon)'
);

SELECT finish();
ROLLBACK;
