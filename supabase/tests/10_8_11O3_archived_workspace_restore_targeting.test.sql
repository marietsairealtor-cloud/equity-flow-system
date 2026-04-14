-- 10.8.11O3: Archived Workspace Restore Targeting tests
BEGIN;

SELECT plan(10);

-- ===================================================================
-- Tenant 1: owner + archived + active subscription -- restore succeeds
-- restore_token: a1111111-1111-1111-1111-111111111111
-- ===================================================================
SELECT public.create_active_workspace_seed_v1(
  'b1000000-0000-0000-0000-000000000001'::uuid,
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'owner'
);
UPDATE public.tenants
SET archived_at            = now() - interval '10 days',
    subscription_lapsed_at = now() - interval '70 days',
    restore_token          = 'a1111111-1111-1111-1111-111111111111'::uuid
WHERE id = 'b1000000-0000-0000-0000-000000000001';

-- ===================================================================
-- Tenant 2: admin caller -- must be rejected
-- restore_token: a2222222-2222-2222-2222-222222222222
-- ===================================================================
SELECT public.create_active_workspace_seed_v1(
  'b2000000-0000-0000-0000-000000000002'::uuid,
  'a0000000-0000-0000-0000-000000000002'::uuid,
  'admin'
);
UPDATE public.tenants
SET archived_at   = now() - interval '10 days',
    restore_token = 'a2222222-2222-2222-2222-222222222222'::uuid
WHERE id = 'b2000000-0000-0000-0000-000000000002';

-- ===================================================================
-- Tenant 3: owner + NOT archived -- no restore_token (not archived)
-- ===================================================================
SELECT public.create_active_workspace_seed_v1(
  'b3000000-0000-0000-0000-000000000003'::uuid,
  'a0000000-0000-0000-0000-000000000003'::uuid,
  'owner'
);

-- ===================================================================
-- Tenant 4: owner + archived + NO active subscription
-- restore_token: a4444444-4444-4444-4444-444444444444
-- ===================================================================
SELECT public.create_active_workspace_seed_v1(
  'b4000000-0000-0000-0000-000000000004'::uuid,
  'a0000000-0000-0000-0000-000000000004'::uuid,
  'owner'
);
UPDATE public.tenants
SET archived_at   = now() - interval '10 days',
    restore_token = 'a4444444-4444-4444-4444-444444444444'::uuid
WHERE id = 'b4000000-0000-0000-0000-000000000004';
UPDATE public.tenant_subscriptions
SET status = 'expired', current_period_end = now() - interval '70 days'
WHERE tenant_id = 'b4000000-0000-0000-0000-000000000004';

-- ===================================================================
-- Set JWT context for owner of tenant 1
-- ===================================================================
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1000000-0000-0000-0000-000000000001"}',
  true);

-- Capture first restore result
CREATE TEMP TABLE restore_result_1 AS
SELECT public.restore_workspace_v1('a1111111-1111-1111-1111-111111111111'::uuid)::json AS result;

-- Test 1: ok=true
SELECT is(
  (SELECT result->>'ok' FROM restore_result_1),
  'true',
  'owner + archived + active sub: restore returns ok=true'
);

-- Test 2: code=OK
SELECT is(
  (SELECT result->>'code' FROM restore_result_1),
  'OK',
  'owner + archived + active sub: restore returns code=OK'
);

-- Test 3: archived_at cleared
SELECT is(
  (SELECT archived_at FROM public.tenants WHERE id = 'b1000000-0000-0000-0000-000000000001'),
  NULL,
  'owner + archived + active sub: archived_at cleared after restore'
);

-- Test 4: subscription_lapsed_at cleared
SELECT is(
  (SELECT subscription_lapsed_at FROM public.tenants WHERE id = 'b1000000-0000-0000-0000-000000000001'),
  NULL,
  'owner + archived + active sub: subscription_lapsed_at cleared after restore'
);

-- Test 5: null p_restore_token → VALIDATION_ERROR
SELECT is(
  (public.restore_workspace_v1(NULL)::json)->>'code',
  'VALIDATION_ERROR',
  'null p_restore_token: returns VALIDATION_ERROR'
);

-- Test 6: non-existent token → NOT_FOUND
SELECT is(
  (public.restore_workspace_v1('ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)::json)->>'code',
  'NOT_FOUND',
  'non-existent restore_token: returns NOT_FOUND'
);

-- Test 7: admin caller → NOT_AUTHORIZED
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"b2000000-0000-0000-0000-000000000002"}',
  true);

SELECT is(
  (public.restore_workspace_v1('a2222222-2222-2222-2222-222222222222'::uuid)::json)->>'code',
  'NOT_AUTHORIZED',
  'admin caller: restore rejected with NOT_AUTHORIZED'
);

-- Test 8: not archived → NOT_FOUND (no restore_token set, token lookup fails)
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000003","role":"authenticated","tenant_id":"b3000000-0000-0000-0000-000000000003"}',
  true);

SELECT is(
  (public.restore_workspace_v1('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'::uuid)::json)->>'code',
  'NOT_FOUND',
  'unknown restore_token: returns NOT_FOUND'
);

-- Test 9: archived + no active subscription → CONFLICT
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000004","role":"authenticated","tenant_id":"b4000000-0000-0000-0000-000000000004"}',
  true);

SELECT is(
  (public.restore_workspace_v1('a4444444-4444-4444-4444-444444444444'::uuid)::json)->>'code',
  'CONFLICT',
  'archived + no active sub: restore rejected with CONFLICT'
);

-- Test 10: second restore attempt with consumed token → NOT_FOUND
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1000000-0000-0000-0000-000000000001"}',
  true);

SELECT is(
  (public.restore_workspace_v1('a1111111-1111-1111-1111-111111111111'::uuid)::json)->>'code',
  'NOT_FOUND',
  'second restore attempt: token consumed, returns NOT_FOUND'
);

SELECT finish();
ROLLBACK;