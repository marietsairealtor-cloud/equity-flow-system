-- 10.8.12: 1-Month Free Trial tests
BEGIN;

SELECT plan(14);

-- ===================================================================
-- Seed users and workspace
-- ===================================================================
SELECT public.create_active_workspace_seed_v1(
  'b1000000-0000-0000-0000-000000000001'::uuid,
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

-- Seed a second user (non-owner) for the same tenant
INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES ('a0000000-0000-0000-0000-000000000002', 'seed_member@test.local', now(), now(), '{}', '{}', 'authenticated', 'authenticated')
ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (gen_random_uuid(), 'b1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'member')
ON CONFLICT DO NOTHING;

INSERT INTO public.user_profiles (id, current_tenant_id)
VALUES ('a0000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

-- Seed a third user with has_used_trial = true
INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES ('a0000000-0000-0000-0000-000000000003', 'seed_usedtrial@test.local', now(), now(), '{}', '{}', 'authenticated', 'authenticated')
ON CONFLICT DO NOTHING;

INSERT INTO public.user_profiles (id, current_tenant_id, has_used_trial)
VALUES ('a0000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000001', true)
ON CONFLICT DO NOTHING;

-- ===================================================================
-- Tests 1-5: claim_trial_v1()
-- ===================================================================
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1000000-0000-0000-0000-000000000001"}',
  true);

-- 1. eligible user returns trial_eligible = true
SELECT is(
  (public.claim_trial_v1()::json)->'data'->>'trial_eligible',
  'true',
  'claim_trial_v1: eligible user returns trial_eligible=true'
);

-- 2. reservation sets trial_claimed_at
SELECT ok(
  (SELECT trial_claimed_at FROM public.user_profiles WHERE id = 'a0000000-0000-0000-0000-000000000001') IS NOT NULL,
  'claim_trial_v1: trial_claimed_at set after reservation'
);

-- 3. second call within 2 hours returns trial_eligible = false
SELECT is(
  (public.claim_trial_v1()::json)->'data'->>'trial_eligible',
  'false',
  'claim_trial_v1: second call within 2 hours returns trial_eligible=false'
);

-- 4. user with has_used_trial = true returns trial_eligible = false
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000003","role":"authenticated","tenant_id":"b1000000-0000-0000-0000-000000000001"}',
  true);

SELECT is(
  (public.claim_trial_v1()::json)->'data'->>'trial_eligible',
  'false',
  'claim_trial_v1: has_used_trial=true returns trial_eligible=false'
);

-- 5. expired reservation allows re-claim
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1000000-0000-0000-0000-000000000001"}',
  true);

UPDATE public.user_profiles
SET trial_claimed_at = now() - interval '3 hours'
WHERE id = 'a0000000-0000-0000-0000-000000000001';

SELECT is(
  (public.claim_trial_v1()::json)->'data'->>'trial_eligible',
  'true',
  'claim_trial_v1: expired reservation allows re-claim'
);

-- ===================================================================
-- Tests 6-11: confirm_trial_v1()
-- ===================================================================

-- 6. valid reservation finalizes trial (returns confirmed=true)
SELECT is(
  (public.confirm_trial_v1(
    'a0000000-0000-0000-0000-000000000001'::uuid,
    'b1000000-0000-0000-0000-000000000001'::uuid
  )::json)->'data'->>'confirmed',
  'true',
  'confirm_trial_v1: valid reservation finalizes trial'
);

-- 7. has_used_trial = true and trial_started_at set after confirm
SELECT is(
  (SELECT has_used_trial FROM public.user_profiles WHERE id = 'a0000000-0000-0000-0000-000000000001'),
  true,
  'confirm_trial_v1: has_used_trial = true after confirm'
);

SELECT ok(
  (SELECT trial_started_at FROM public.user_profiles WHERE id = 'a0000000-0000-0000-0000-000000000001') IS NOT NULL,
  'confirm_trial_v1: trial_started_at set after confirm'
);

-- 8. already confirmed is idempotent OK
SELECT is(
  (public.confirm_trial_v1(
    'a0000000-0000-0000-0000-000000000001'::uuid,
    'b1000000-0000-0000-0000-000000000001'::uuid
  )::json)->>'code',
  'OK',
  'confirm_trial_v1: already confirmed is idempotent OK'
);

-- 9. missing profile returns NOT_FOUND
SELECT is(
  (public.confirm_trial_v1(
    'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid,
    'b1000000-0000-0000-0000-000000000001'::uuid
  )::json)->>'code',
  'NOT_FOUND',
  'confirm_trial_v1: missing profile returns NOT_FOUND'
);

-- 10. expired reservation returns CONFLICT
-- Seed a fresh user with expired claim
INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES ('a0000000-0000-0000-0000-000000000004', 'seed_expiredclaim@test.local', now(), now(), '{}', '{}', 'authenticated', 'authenticated')
ON CONFLICT DO NOTHING;

INSERT INTO public.user_profiles (id, current_tenant_id, trial_claimed_at)
VALUES ('a0000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001', now() - interval '3 hours')
ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (gen_random_uuid(), 'b1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000004', 'owner')
ON CONFLICT DO NOTHING;

SELECT is(
  (public.confirm_trial_v1(
    'a0000000-0000-0000-0000-000000000004'::uuid,
    'b1000000-0000-0000-0000-000000000001'::uuid
  )::json)->>'code',
  'CONFLICT',
  'confirm_trial_v1: expired reservation returns CONFLICT'
);

-- 11. non-owner returns NOT_AUTHORIZED
-- Use member user with fresh claim
UPDATE public.user_profiles
SET trial_claimed_at = now()
WHERE id = 'a0000000-0000-0000-0000-000000000002';

SELECT is(
  (public.confirm_trial_v1(
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'b1000000-0000-0000-0000-000000000001'::uuid
  )::json)->>'code',
  'NOT_AUTHORIZED',
  'confirm_trial_v1: non-owner returns NOT_AUTHORIZED'
);

-- ===================================================================
-- Test 12: get_user_entitlements_v1() returns trialing
-- ===================================================================
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1000000-0000-0000-0000-000000000001"}',
  true);

UPDATE public.tenant_subscriptions
SET status = 'trialing', current_period_end = now() + interval '30 days'
WHERE tenant_id = 'b1000000-0000-0000-0000-000000000001';

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_status',
  'trialing',
  'get_user_entitlements_v1: trialing subscription returns subscription_status=trialing'
);

-- ===================================================================
-- Test 13: upsert_subscription_v1() accepts trialing
-- ===================================================================
SELECT is(
  (public.upsert_subscription_v1(
    'b1000000-0000-0000-0000-000000000001'::uuid,
    'sub_test_trialing',
    'trialing',
    now() + interval '30 days'
  )::jsonb)->>'ok',
  'true',
  'upsert_subscription_v1: accepts trialing status'
);

SELECT finish();
ROLLBACK;