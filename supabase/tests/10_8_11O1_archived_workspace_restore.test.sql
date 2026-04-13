-- 10.8.11O1: Archived Workspace Restore tests
BEGIN;

SELECT plan(10);

-- ===================================================================
-- Tenant 1: owner + archived + active subscription -- restore succeeds
-- ===================================================================
SELECT public.create_active_workspace_seed_v1(
  'b1000000-0000-0000-0000-000000000001'::uuid,
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'owner'
);
UPDATE public.tenants
SET archived_at            = now() - interval '10 days',
    subscription_lapsed_at = now() - interval '70 days'
WHERE id = 'b1000000-0000-0000-0000-000000000001';

-- ===================================================================
-- Tenant 2: admin caller -- must be rejected
-- ===================================================================
SELECT public.create_active_workspace_seed_v1(
  'b2000000-0000-0000-0000-000000000002'::uuid,
  'a0000000-0000-0000-0000-000000000002'::uuid,
  'admin'
);
UPDATE public.tenants
SET archived_at = now() - interval '10 days'
WHERE id = 'b2000000-0000-0000-0000-000000000002';

-- ===================================================================
-- Tenant 3: owner + NOT archived -- must be rejected
-- ===================================================================
SELECT public.create_active_workspace_seed_v1(
  'b3000000-0000-0000-0000-000000000003'::uuid,
  'a0000000-0000-0000-0000-000000000003'::uuid,
  'owner'
);

-- ===================================================================
-- Tenant 4: owner + archived + NO active subscription -- must be rejected
-- ===================================================================
SELECT public.create_active_workspace_seed_v1(
  'b4000000-0000-0000-0000-000000000004'::uuid,
  'a0000000-0000-0000-0000-000000000004'::uuid,
  'owner'
);
UPDATE public.tenants
SET archived_at = now() - interval '10 days'
WHERE id = 'b4000000-0000-0000-0000-000000000004';
UPDATE public.tenant_subscriptions
SET status = 'expired', current_period_end = now() - interval '70 days'
WHERE tenant_id = 'b4000000-0000-0000-0000-000000000004';

-- ===================================================================
-- Tenant 5: hard deleted -- seed then delete tenant row
-- ===================================================================
SELECT public.create_active_workspace_seed_v1(
  'b5000000-0000-0000-0000-000000000005'::uuid,
  'a0000000-0000-0000-0000-000000000005'::uuid,
  'owner'
);
-- Simulate hard delete: remove memberships then tenant row
DELETE FROM public.tenant_memberships WHERE tenant_id = 'b5000000-0000-0000-0000-000000000005';
DELETE FROM public.tenants WHERE id = 'b5000000-0000-0000-0000-000000000005';

-- ===================================================================
-- Tests 1-4: owner + archived + active sub -- restore succeeds
-- Capture result once, assert ok and code, then check DB state
-- ===================================================================
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1000000-0000-0000-0000-000000000001"}',
  true);

-- Capture first restore result
CREATE TEMP TABLE restore_result_1 AS
SELECT public.restore_workspace_v1()::json AS result;

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

-- Test 5: second restore attempt returns CONFLICT (workspace no longer archived)
SELECT is(
  (public.restore_workspace_v1()::json)->>'code',
  'CONFLICT',
  'second restore attempt: workspace already restored, returns CONFLICT'
);

-- ===================================================================
-- Test 6: admin caller rejected
-- ===================================================================
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"b2000000-0000-0000-0000-000000000002"}',
  true);

SELECT is(
  (public.restore_workspace_v1()::json)->>'code',
  'NOT_AUTHORIZED',
  'admin caller: restore rejected with NOT_AUTHORIZED'
);

-- ===================================================================
-- Test 7: not archived rejected
-- ===================================================================
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000003","role":"authenticated","tenant_id":"b3000000-0000-0000-0000-000000000003"}',
  true);

SELECT is(
  (public.restore_workspace_v1()::json)->>'code',
  'CONFLICT',
  'not archived: restore rejected with CONFLICT'
);

-- ===================================================================
-- Test 8: archived + no active subscription rejected
-- ===================================================================
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000004","role":"authenticated","tenant_id":"b4000000-0000-0000-0000-000000000004"}',
  true);

SELECT is(
  (public.restore_workspace_v1()::json)->>'code',
  'CONFLICT',
  'archived + no active sub: restore rejected with CONFLICT'
);

-- ===================================================================
-- Test 9: hard-deleted workspace -- ok=false
-- ===================================================================
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000005","role":"authenticated","tenant_id":"b5000000-0000-0000-0000-000000000005"}',
  true);

SELECT is(
  (public.restore_workspace_v1()::json)->>'ok',
  'false',
  'hard-deleted workspace: restore returns ok=false'
);

-- Test 10: hard-deleted workspace returns contract-valid code
SELECT ok(
  (public.restore_workspace_v1()::json)->>'code' IS NOT NULL,
  'hard-deleted workspace: restore returns contract-valid code'
);

SELECT finish();
ROLLBACK;