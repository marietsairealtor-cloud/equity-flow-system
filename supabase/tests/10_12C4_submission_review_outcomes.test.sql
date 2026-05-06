-- 10.12C4: Intake submission review outcomes + mark_submission_reviewed_v1
BEGIN;

SELECT plan(25);

-- Tenant A (primary), Tenant B (cross-tenant NOT_FOUND)
SELECT public.create_active_workspace_seed_v1(
  'cc442222-c444-4222-a444-cc4422220001'::uuid,
  'cc552222-c555-4222-a555-cc5522220001'::uuid,
  'member'
);

SELECT public.create_active_workspace_seed_v1(
  'cc442222-c444-4222-a444-cc4422220002'::uuid,
  'cc552222-c555-4222-a555-cc5522220002'::uuid,
  'member'
);

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES
  ('cc442222-c444-4222-a444-cc4422220001', 'test-12c4-a'),
  ('cc442222-c444-4222-a444-cc4422220002', 'test-12c4-b')
ON CONFLICT DO NOTHING;

SELECT public.submit_form_v1(
  'test-12c4-a', 'seller',
  '{"spam_token":"c4a","address":"100 Alpha","name":"A","phone":"1","email":"a@example.com"}'::jsonb
);
SELECT public.submit_form_v1(
  'test-12c4-a', 'seller',
  '{"spam_token":"c4b","address":"200 Beta","name":"B","phone":"2","email":"b@example.com"}'::jsonb
);
SELECT public.submit_form_v1(
  'test-12c4-a', 'buyer',
  '{"spam_token":"c4c","name":"Buy","email":"x@y.com","phone":"","areas_of_interest":"","budget_range":""}'::jsonb
);
SELECT public.submit_form_v1(
  'test-12c4-b', 'seller',
  '{"spam_token":"c4x","address":"999 Other Tenant","name":"X","phone":"9","email":"x@other.com"}'::jsonb
);

-- Deterministic KPI window (seller/birddog only; buyers excluded)
SET LOCAL ROLE postgres;
UPDATE public.intake_submissions
SET submitted_at = '2026-06-15 12:00:00+00'
WHERE tenant_id = 'cc442222-c444-4222-a444-cc4422220001'
  AND form_type IN ('seller', 'birddog');

-- authenticated has no SELECT on intake_submissions; resolve ids as superuser for RPC args.
DROP TABLE IF EXISTS _12c4_sid;
CREATE TEMP TABLE _12c4_sid (label text PRIMARY KEY, sid uuid NOT NULL);
INSERT INTO _12c4_sid (label, sid) VALUES
  (
    'alpha',
    (SELECT id FROM public.intake_submissions
     WHERE tenant_id = 'cc442222-c444-4222-a444-cc4422220001'
       AND form_type = 'seller'
       AND payload->>'address' = '100 Alpha'
     LIMIT 1)
  ),
  (
    'beta',
    (SELECT id FROM public.intake_submissions
     WHERE tenant_id = 'cc442222-c444-4222-a444-cc4422220001'
       AND form_type = 'seller'
       AND payload->>'address' = '200 Beta'
     LIMIT 1)
  ),
  (
    'buyer_a',
    (SELECT id FROM public.intake_submissions
     WHERE tenant_id = 'cc442222-c444-4222-a444-cc4422220001'
       AND form_type = 'buyer'
     LIMIT 1)
  ),
  (
    'seller_b',
    (SELECT id FROM public.intake_submissions
     WHERE tenant_id = 'cc442222-c444-4222-a444-cc4422220002'
       AND form_type = 'seller'
     LIMIT 1)
  );
GRANT SELECT ON _12c4_sid TO authenticated;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"cc552222-c555-4222-a555-cc5522220001","role":"authenticated","tenant_id":"cc442222-c444-4222-a444-cc4422220001"}',
  true
);
SET LOCAL ROLE authenticated;

-- ---------------------------------------------------------------------------
-- KPI: before any review — full seller pair counts as submissions + leads
-- ---------------------------------------------------------------------------
SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-06-01 00:00:00+00'::timestamptz,
      '2026-06-30 23:59:59+00'::timestamptz
    )->'data'->>'new_submissions'
  ),
  '2',
  '10.12C4 KPI: new_submissions counts both sellers in window'
);

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-06-01 00:00:00+00'::timestamptz,
      '2026-06-30 23:59:59+00'::timestamptz
    )->'data'->>'new_leads'
  ),
  '2',
  '10.12C4 KPI: new_leads matches submissions when none rejected_spam/test/invalid'
);

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-06-01 00:00:00+00'::timestamptz,
      '2026-06-30 23:59:59+00'::timestamptz
    )->'data'->>'rejected_count'
  ),
  '0',
  '10.12C4 KPI: rejected_count 0 before rejections'
);

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-06-01 00:00:00+00'::timestamptz,
      '2026-06-30 23:59:59+00'::timestamptz
    )->'data'->>'submission_to_deal_pct'
  ),
  '0',
  '10.12C4 KPI: submission_to_deal_pct 0 when nothing promoted'
);

SELECT is(
  (public.mark_submission_reviewed_v1(
    (SELECT sid FROM _12c4_sid WHERE label = 'alpha'),
    'garbage_outcome'::text
  )->>'code'),
  'VALIDATION_ERROR',
  '10.12C4: invalid p_outcome → VALIDATION_ERROR'
);

SELECT is(
  (
    public.mark_submission_reviewed_v1(
      (SELECT sid FROM _12c4_sid WHERE label = 'seller_b'),
      'rejected_spam'::text
    )->>'code'
  ),
  'NOT_FOUND',
  '10.12C4: cross-tenant submission id → NOT_FOUND'
);

SELECT is(
  jsonb_array_length((public.list_intake_submissions_v1(100))->'data'->'items'),
  2,
  '10.12C4: two unreviewed seller rows in Lead Intake list'
);

SELECT is(
  (public.mark_submission_reviewed_v1(NULL::uuid, 'rejected_spam'::text)->>'code'),
  'VALIDATION_ERROR',
  '10.12C4: NULL submission id → VALIDATION_ERROR'
);

SELECT is(
  (
    public.mark_submission_reviewed_v1(
      '00000000-0000-4000-8000-000000000099'::uuid,
      'rejected_spam'::text
    )->>'code'
  ),
  'NOT_FOUND',
  '10.12C4: unknown submission → NOT_FOUND'
);

SELECT is(
  (public.mark_submission_reviewed_v1(
    (SELECT sid FROM _12c4_sid WHERE label = 'alpha'),
    'promoted'::text
  )->>'code'),
  'VALIDATION_ERROR',
  '10.12C4: p_outcome=promoted rejected'
);

SELECT is(
  (public.mark_submission_reviewed_v1(
    (SELECT sid FROM _12c4_sid WHERE label = 'buyer_a'),
    'rejected_spam'::text
  )->>'code'),
  'VALIDATION_ERROR',
  '10.12C4: buyer submission rejected at mark RPC'
);

SELECT is(
  (public.mark_submission_reviewed_v1(
    (SELECT sid FROM _12c4_sid WHERE label = 'alpha'),
    'rejected_spam'::text
  )->>'code'),
  'OK',
  '10.12C4: dismiss seller as spam OK'
);

-- ---------------------------------------------------------------------------
-- KPI: rejected_spam drops from new_leads + denominator only; new_submissions unchanged
-- ---------------------------------------------------------------------------
SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-06-01 00:00:00+00'::timestamptz,
      '2026-06-30 23:59:59+00'::timestamptz
    )->'data'->>'new_submissions'
  ),
  '2',
  '10.12C4 KPI: new_submissions still counts rejected_spam row'
);

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-06-01 00:00:00+00'::timestamptz,
      '2026-06-30 23:59:59+00'::timestamptz
    )->'data'->>'new_leads'
  ),
  '1',
  '10.12C4 KPI: new_leads excludes rejected_spam from denominator'
);

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-06-01 00:00:00+00'::timestamptz,
      '2026-06-30 23:59:59+00'::timestamptz
    )->'data'->>'rejected_count'
  ),
  '1',
  '10.12C4 KPI: rejected_count includes rejected_spam'
);

SELECT is(
  jsonb_array_length((public.list_intake_submissions_v1(100))->'data'->'items'),
  1,
  '10.12C4: spam-dismissed row leaves inbox (one seller left)'
);

SELECT is(
  (public.mark_submission_reviewed_v1(
    (SELECT sid FROM _12c4_sid WHERE label = 'beta'),
    'dismissed_not_interested'::text
  )->>'code'),
  'OK',
  '10.12C4: dismiss second seller OK'
);

SELECT is(
  jsonb_array_length((public.list_intake_submissions_v1(100))->'data'->'items'),
  0,
  '10.12C4: inbox empty after both reviewed'
);

SELECT is(
  (public.mark_submission_reviewed_v1(
    (SELECT sid FROM _12c4_sid WHERE label = 'beta'),
    'dismissed_not_interested'::text
  )->>'code'),
  'OK',
  '10.12C4: idempotent same outcome returns OK'
);

SELECT is(
  (public.mark_submission_reviewed_v1(
    (SELECT sid FROM _12c4_sid WHERE label = 'beta'),
    'rejected_test'::text
  )->>'code'),
  'CONFLICT',
  '10.12C4: different outcome after review → CONFLICT'
);

-- ---------------------------------------------------------------------------
-- Trigger-only: setting draft_deals.promoted_deal_id syncs intake review columns
-- ---------------------------------------------------------------------------
RESET ROLE;
SELECT public.submit_form_v1(
  'test-12c4-a', 'seller',
  '{"spam_token":"c4p","address":"300 Trigger Path","name":"P","phone":"3","email":"p@example.com"}'::jsonb
);

SET LOCAL ROLE postgres;
UPDATE public.intake_submissions
SET submitted_at = '2026-06-15 14:00:00+00'
WHERE tenant_id = 'cc442222-c444-4222-a444-cc4422220001'
  AND form_type = 'seller'
  AND payload->>'address' = '300 Trigger Path';

INSERT INTO public.deals (
  id, tenant_id, row_version, calc_version, stage, updated_at, created_at
)
VALUES (
  'cc662222-c666-4222-a666-cc6622220001'::uuid,
  'cc442222-c444-4222-a444-cc4422220001'::uuid,
  1,
  1,
  'new',
  now(),
  now()
);

UPDATE public.draft_deals dd
SET promoted_deal_id = 'cc662222-c666-4222-a666-cc6622220001'::uuid
FROM public.intake_submissions s
WHERE s.tenant_id = 'cc442222-c444-4222-a444-cc4422220001'
  AND s.form_type = 'seller'
  AND s.payload->>'address' = '300 Trigger Path'
  AND dd.id = s.draft_deals_id
  AND dd.tenant_id = s.tenant_id;

SELECT is(
  (
    SELECT review_outcome FROM public.intake_submissions
    WHERE tenant_id = 'cc442222-c444-4222-a444-cc4422220001'
      AND payload->>'address' = '300 Trigger Path'
  ),
  'promoted',
  '10.12C4: trigger sets review_outcome promoted when promoted_deal_id set'
);

SELECT is(
  (
    SELECT review_status FROM public.intake_submissions
    WHERE tenant_id = 'cc442222-c444-4222-a444-cc4422220001'
      AND payload->>'address' = '300 Trigger Path'
  ),
  'reviewed',
  '10.12C4: trigger sets review_status reviewed'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"cc552222-c555-4222-a555-cc5522220001","role":"authenticated","tenant_id":"cc442222-c444-4222-a444-cc4422220001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-06-01 00:00:00+00'::timestamptz,
      '2026-06-30 23:59:59+00'::timestamptz
    )->'data'->>'submission_to_deal_pct'
  ),
  '50',
  '10.12C4 KPI: submission_to_deal_pct = promoted count / new_leads (1 of 2)'
);

-- Expired workspace blocks mark_submission_reviewed_v1
RESET ROLE;
SELECT public.submit_form_v1(
  'test-12c4-a', 'seller',
  '{"spam_token":"c4e","address":"400 Expire Row","name":"E","phone":"4","email":"e@example.com"}'::jsonb
);

INSERT INTO _12c4_sid (label, sid) VALUES (
  'expire',
  (SELECT id FROM public.intake_submissions
   WHERE tenant_id = 'cc442222-c444-4222-a444-cc4422220001'
     AND payload->>'address' = '400 Expire Row'
   LIMIT 1)
);

UPDATE public.tenant_subscriptions
SET current_period_end = now() - interval '1 day'
WHERE tenant_id = 'cc442222-c444-4222-a444-cc4422220001'::uuid;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"cc552222-c555-4222-a555-cc5522220001","role":"authenticated","tenant_id":"cc442222-c444-4222-a444-cc4422220001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.mark_submission_reviewed_v1(
    (SELECT sid FROM _12c4_sid WHERE label = 'expire'),
    'rejected_spam'::text
  )->>'code'),
  'WORKSPACE_NOT_WRITABLE',
  '10.12C4: expired workspace → WORKSPACE_NOT_WRITABLE'
);

-- Missing tenant (restore subscription so other tests stay isolated if extended later)
RESET ROLE;
UPDATE public.tenant_subscriptions
SET current_period_end = now() + interval '365 days'
WHERE tenant_id = 'cc442222-c444-4222-a444-cc4422220001'::uuid;

UPDATE public.user_profiles
SET current_tenant_id = NULL
WHERE id = 'cc552222-c555-4222-a555-cc5522220001'::uuid;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"cc552222-c555-4222-a555-cc5522220001","role":"authenticated"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.mark_submission_reviewed_v1(
    '00000000-0000-4000-8000-000000000088'::uuid,
    'rejected_spam'::text
  )->>'code'),
  'NOT_AUTHORIZED',
  '10.12C4: missing tenant → NOT_AUTHORIZED'
);

SELECT finish();
ROLLBACK;
