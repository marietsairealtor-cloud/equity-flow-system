-- 10.12A: Intake Backend -- Submission Persistence tests
BEGIN;

SELECT plan(21);

-- Seed tenant 1
SELECT public.create_active_workspace_seed_v1(
  'b1120000-0000-0000-0000-000000000001'::uuid,
  'a1120000-0000-0000-0000-000000000001'::uuid,
  'owner'
);
INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES ('b1120000-0000-0000-0000-000000000001', 'test-intake-01')
ON CONFLICT DO NOTHING;

-- Seed tenant 2 (expired)
SELECT public.create_active_workspace_seed_v1(
  'b1120000-0000-0000-0000-000000000002'::uuid,
  'a1120000-0000-0000-0000-000000000002'::uuid,
  'owner'
);
INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES ('b1120000-0000-0000-0000-000000000002', 'expired-intake-01')
ON CONFLICT DO NOTHING;
UPDATE public.tenant_subscriptions
SET current_period_end = now() - interval '1 day'
WHERE tenant_id = 'b1120000-0000-0000-0000-000000000002';

-- All initial state verification runs as postgres (authenticated has no direct table access)
SET LOCAL ROLE postgres;

-- 1. intake_submissions table exists
SELECT has_table('public', 'intake_submissions', 'intake_submissions table exists');

-- 2. intake_buyers table exists
SELECT has_table('public', 'intake_buyers', 'intake_buyers table exists');

-- 3. seller submission persists to intake_submissions
SELECT public.submit_form_v1(
  'test-intake-01', 'seller',
  '{"spam_token":"tok1","address":"123 Main St","asking_price":"300000","repair_estimate":"20000"}'::jsonb
);
SELECT is(
  (SELECT count(*)::int FROM public.intake_submissions
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000001' AND form_type = 'seller'),
  1,
  'seller submission persisted to intake_submissions'
);

-- 4. seller submission also persists draft_deal (existing write path preserved)
SELECT is(
  (SELECT count(*)::int FROM public.draft_deals
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000001' AND form_type = 'seller'),
  1,
  'seller submission persisted to draft_deals (existing write path preserved)'
);

-- 5. buyer submission persists to intake_submissions
SELECT public.submit_form_v1(
  'test-intake-01', 'buyer',
  '{"spam_token":"tok2","name":"Alice","email":"alice@example.com"}'::jsonb
);
SELECT is(
  (SELECT count(*)::int FROM public.intake_submissions
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000001' AND form_type = 'buyer'),
  1,
  'buyer submission persisted to intake_submissions'
);

-- 6. birddog submission persists to intake_submissions
SELECT public.submit_form_v1(
  'test-intake-01', 'birddog',
  '{"spam_token":"tok3","name":"Bob","phone":"555-1234"}'::jsonb
);
SELECT is(
  (SELECT count(*)::int FROM public.intake_submissions
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000001' AND form_type = 'birddog'),
  1,
  'birddog submission persisted to intake_submissions'
);

-- 7. source field stored as web
SELECT is(
  (SELECT source FROM public.intake_submissions
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000001' AND form_type = 'birddog'
   LIMIT 1),
  'web',
  'intake_submissions.source stored as web'
);

-- 8. returns ok:true on success
SELECT is(
  (public.submit_form_v1(
    'test-intake-01', 'seller',
    '{"spam_token":"tok4","asking_price":"250000"}'::jsonb
  )->>'ok')::boolean,
  true,
  'submit_form_v1 returns ok:true on success'
);

-- 9. invalid form_type returns VALIDATION_ERROR
SELECT is(
  public.submit_form_v1('test-intake-01', 'garbage', '{"spam_token":"tok5"}'::jsonb)->>'code',
  'VALIDATION_ERROR',
  'submit_form_v1: invalid form_type returns VALIDATION_ERROR'
);

-- 10. unknown slug returns NOT_FOUND
SELECT is(
  public.submit_form_v1('no-such-slug-xyz', 'seller', '{"spam_token":"tok6"}'::jsonb)->>'code',
  'NOT_FOUND',
  'submit_form_v1: unknown slug returns NOT_FOUND'
);

-- 11. missing spam_token returns VALIDATION_ERROR
SELECT is(
  public.submit_form_v1('test-intake-01', 'seller', '{}'::jsonb)->>'code',
  'VALIDATION_ERROR',
  'submit_form_v1: missing spam_token returns VALIDATION_ERROR'
);

-- 12. expired workspace returns NOT_AUTHORIZED
SELECT is(
  public.submit_form_v1('expired-intake-01', 'seller', '{"spam_token":"tok7"}'::jsonb)->>'code',
  'NOT_AUTHORIZED',
  'submit_form_v1: expired workspace returns NOT_AUTHORIZED'
);

-- 13. empty numeric strings handled safely via NULLIF cast
SELECT is(
  (public.submit_form_v1(
    'test-intake-01', 'seller',
    '{"spam_token":"tok8","asking_price":"","repair_estimate":""}'::jsonb
  )->>'ok')::boolean,
  true,
  'submit_form_v1: empty asking_price/repair_estimate strings handled safely'
);

-- Owner-visible row count for tenant 1 (used vs list_intake RPC; captured as postgres only)
CREATE TEMP TABLE _10_12a_owner_tenant1_intake_count AS
SELECT count(*)::int AS n FROM public.intake_submissions
WHERE tenant_id = 'b1120000-0000-0000-0000-000000000001';
GRANT SELECT ON TABLE _10_12a_owner_tenant1_intake_count TO authenticated;

-- 14. intake_submissions: direct SELECT denied for authenticated (REVOKE firewall)
SELECT set_config('request.jwt.claims',
  '{"sub":"a1120000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1120000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
  $tap$SELECT 1 FROM public.intake_submissions LIMIT 1$tap$,
  '42501',
  NULL,
  'intake_submissions: direct SELECT denied for authenticated'
);

-- 15. intake_submissions: direct INSERT denied for authenticated
SELECT throws_ok(
  $tap$INSERT INTO public.intake_submissions (tenant_id, form_type, payload)
  VALUES ('b1120000-0000-0000-0000-000000000001'::uuid, 'seller', '{}'::jsonb)$tap$,
  '42501',
  NULL,
  'intake_submissions: direct INSERT denied for authenticated'
);

SET LOCAL ROLE postgres;

-- 16. list_intake_submissions_v1: item count matches owner-captured tenant row count
SELECT set_config('request.jwt.claims',
  '{"sub":"a1120000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1120000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;
SELECT is(
  jsonb_array_length((public.list_intake_submissions_v1())->'data'->'items'),
  (SELECT n FROM _10_12a_owner_tenant1_intake_count),
  'list_intake_submissions_v1: item count matches owner-captured tenant row count'
);

-- 17. list_intake_submissions_v1: no cross-tenant leakage
SELECT set_config('request.jwt.claims',
  '{"sub":"a1120000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"b1120000-0000-0000-0000-000000000002"}',
  true);
SELECT is(
  jsonb_array_length((public.list_intake_submissions_v1())->'data'->'items'),
  0,
  'list_intake_submissions_v1: tenant 2 sees zero items from tenant 1'
);

-- 18. list_intake_submissions_v1: no tenant context returns NOT_AUTHORIZED
--    current_tenant_id() prefers user_profiles over JWT; clear profile so missing jwt tenant_id matters
SET LOCAL ROLE postgres;
UPDATE public.user_profiles
SET current_tenant_id = NULL
WHERE id = 'a1120000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claims',
  '{"sub":"a1120000-0000-0000-0000-000000000001","role":"authenticated"}',
  true);
SET LOCAL ROLE authenticated;
SELECT is(
  public.list_intake_submissions_v1()->>'code',
  'NOT_AUTHORIZED',
  'list_intake_submissions_v1: no tenant context returns NOT_AUTHORIZED'
);

-- 19. list_intake_submissions_v1: p_limit=0 returns VALIDATION_ERROR (restore profile; exercise RPC as authenticated)
SET LOCAL ROLE postgres;
UPDATE public.user_profiles
SET current_tenant_id = 'b1120000-0000-0000-0000-000000000001'
WHERE id = 'a1120000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claims',
  '{"sub":"a1120000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1120000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;
SELECT is(
  public.list_intake_submissions_v1(0)->>'code',
  'VALIDATION_ERROR',
  'list_intake_submissions_v1: p_limit=0 returns VALIDATION_ERROR'
);

-- 20. list_buyers_v1: count matches actual tenant buyer row count
-- (10.12C: buyer submissions now upsert intake_buyers)
SET LOCAL ROLE postgres;
CREATE TEMP TABLE _10_12a_owner_tenant1_buyer_count AS
SELECT count(*)::int AS n FROM public.intake_buyers
WHERE tenant_id = 'b1120000-0000-0000-0000-000000000001';
GRANT SELECT ON TABLE _10_12a_owner_tenant1_buyer_count TO authenticated;
SELECT set_config('request.jwt.claims',
  '{"sub":"a1120000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1120000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;
SELECT is(
  jsonb_array_length((public.list_buyers_v1())->'data'->'items'),
  (SELECT n FROM _10_12a_owner_tenant1_buyer_count),
  'list_buyers_v1: item count matches actual tenant buyer row count'
);

-- 21. list_buyers_v1: no tenant context returns NOT_AUTHORIZED
SET LOCAL ROLE postgres;
UPDATE public.user_profiles
SET current_tenant_id = NULL
WHERE id = 'a1120000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claims',
  '{"sub":"a1120000-0000-0000-0000-000000000001","role":"authenticated"}',
  true);
SET LOCAL ROLE authenticated;
SELECT is(
  public.list_buyers_v1()->>'code',
  'NOT_AUTHORIZED',
  'list_buyers_v1: no tenant context returns NOT_AUTHORIZED'
);

SELECT finish();
ROLLBACK;
