-- 10.8.11O2: Entitlement Archived-State Corrective Fix tests
BEGIN;

SELECT plan(8);

-- ===================================================================
-- Tenant 1: archived + active subscription
-- app_mode must be archived_unreachable, not normal
-- ===================================================================
SELECT public.create_active_workspace_seed_v1(
  'b1000000-0000-0000-0000-000000000001'::uuid,
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'owner'
);
UPDATE public.tenants
SET archived_at = now() - interval '10 days'
WHERE id = 'b1000000-0000-0000-0000-000000000001';
-- subscription remains active from seed helper

-- ===================================================================
-- Tenant 2: not archived + active subscription
-- app_mode must be normal
-- ===================================================================
SELECT public.create_active_workspace_seed_v1(
  'b2000000-0000-0000-0000-000000000002'::uuid,
  'a0000000-0000-0000-0000-000000000002'::uuid,
  'owner'
);

-- ===================================================================
-- Tests for Tenant 1: archived + active subscription
-- ===================================================================
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1000000-0000-0000-0000-000000000001"}',
  true);

-- 1. archived + active sub → app_mode = archived_unreachable
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'app_mode',
  'archived_unreachable',
  'archived + active sub: app_mode = archived_unreachable'
);

-- 2. archived overrides active subscription (not normal)
SELECT isnt(
  (public.get_user_entitlements_v1()::json)->'data'->>'app_mode',
  'normal',
  'archived state overrides active subscription: app_mode != normal'
);

-- 3. days_until_deletion is not null when archived
SELECT ok(
  (public.get_user_entitlements_v1()::json)->'data'->>'days_until_deletion' IS NOT NULL,
  'archived: days_until_deletion is not null'
);

-- 4. days_until_deletion computed from archived_at + 6 months (~170 days remaining)
SELECT ok(
  ((public.get_user_entitlements_v1()::json)->'data'->>'days_until_deletion')::integer > 0,
  'archived: days_until_deletion > 0 (archive began 10 days ago, 6 months not elapsed)'
);

-- 5. is_member = true when archived
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'is_member',
  'true',
  'archived: is_member = true preserved'
);

-- 6. entitled = true when archived
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'entitled',
  'true',
  'archived: entitled = true preserved'
);

-- ===================================================================
-- Test 7: non-archived + active subscription → app_mode = normal
-- ===================================================================
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"b2000000-0000-0000-0000-000000000002"}',
  true);

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'app_mode',
  'normal',
  'non-archived + active sub: app_mode = normal (existing logic unchanged)'
);

-- ===================================================================
-- Test 8: after restore (clear archived_at) → app_mode = normal
-- ===================================================================
SELECT set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1000000-0000-0000-0000-000000000001"}',
  true);

UPDATE public.tenants
SET archived_at = NULL
WHERE id = 'b1000000-0000-0000-0000-000000000001';

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'app_mode',
  'normal',
  'after restore (archived_at cleared): app_mode = normal'
);

SELECT finish();
ROLLBACK;