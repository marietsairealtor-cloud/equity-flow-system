-- 10_8_2_entitlements_extension_tests.test.sql
-- Build Route 10.8.2: Entitlements Extension pgTAP Tests
-- Verifies subscription_status and subscription_days_remaining fields.

BEGIN;
SELECT plan(19);

-- ============================================================
-- Seed test tenant, user, membership
-- ============================================================
INSERT INTO public.tenants (id)
  VALUES ('a0820000-0000-0000-0000-000000000001'::uuid);

INSERT INTO auth.users (id, email)
  VALUES ('a0820000-0000-0000-0000-000000000002'::uuid, 'entitlements_ext_test@10_8_2.test');

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES (
    'a0820000-0000-0000-0000-000000000003'::uuid,
    'a0820000-0000-0000-0000-000000000001'::uuid,
    'a0820000-0000-0000-0000-000000000002'::uuid,
    'member'
  );

-- Set authenticated context
SELECT set_config('request.jwt.claims',
  '{"sub":"a0820000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"a0820000-0000-0000-0000-000000000001"}',
  true);

-- ============================================================
-- No subscription record -- status = none
-- ============================================================
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_status',
  'none',
  'get_user_entitlements_v1: no subscription -- status=none'
);
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_days_remaining',
  NULL,
  'get_user_entitlements_v1: no subscription -- days_remaining=null'
);

-- ============================================================
-- Active subscription > 5 days -- status = active
-- ============================================================
INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
  VALUES (
    'a0820000-0000-0000-0000-000000000001'::uuid,
    'active',
    now() + interval '30 days'
  );

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_status',
  'active',
  'get_user_entitlements_v1: active >5 days -- status=active'
);
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_days_remaining',
  NULL,
  'get_user_entitlements_v1: active >5 days -- days_remaining=null'
);

-- ============================================================
-- Active subscription <= 5 days -- status = expiring
-- ============================================================
UPDATE public.tenant_subscriptions
  SET current_period_end = now() + interval '3 days'
  WHERE tenant_id = 'a0820000-0000-0000-0000-000000000001'::uuid;

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_status',
  'expiring',
  'get_user_entitlements_v1: active <=5 days -- status=expiring'
);
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_days_remaining',
  '3',
  'get_user_entitlements_v1: active <=5 days -- days_remaining=3'
);

-- ============================================================
-- Expired subscription (period end in past) -- status = expired
-- ============================================================
UPDATE public.tenant_subscriptions
  SET current_period_end = now() - interval '1 day'
  WHERE tenant_id = 'a0820000-0000-0000-0000-000000000001'::uuid;

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_status',
  'expired',
  'get_user_entitlements_v1: period end past -- status=expired'
);

-- ============================================================
-- Canceled subscription -- status = expired
-- ============================================================
UPDATE public.tenant_subscriptions
  SET status = 'canceled', current_period_end = now() + interval '10 days'
  WHERE tenant_id = 'a0820000-0000-0000-0000-000000000001'::uuid;

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_status',
  'expired',
  'get_user_entitlements_v1: canceled -- status=expired'
);

-- ============================================================
-- Existing fields unchanged (non-breaking)
-- ============================================================
UPDATE public.tenant_subscriptions
  SET status = 'active', current_period_end = now() + interval '30 days'
  WHERE tenant_id = 'a0820000-0000-0000-0000-000000000001'::uuid;

SELECT is(
  (public.get_user_entitlements_v1()::json)->>'ok',
  'true',
  'get_user_entitlements_v1: ok=true'
);
SELECT is(
  (public.get_user_entitlements_v1()::json)->>'code',
  'OK',
  'get_user_entitlements_v1: code=OK'
);
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'tenant_id',
  'a0820000-0000-0000-0000-000000000001',
  'get_user_entitlements_v1: tenant_id present'
);
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'is_member',
  'true',
  'get_user_entitlements_v1: is_member=true'
);
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'role',
  'member',
  'get_user_entitlements_v1: role=member'
);
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'entitled',
  'true',
  'get_user_entitlements_v1: entitled=true'
);

-- ============================================================
-- NOT_AUTHORIZED path -- no JWT context
-- ============================================================
SELECT set_config('request.jwt.claims', '', true);

SELECT is(
  (public.get_user_entitlements_v1()::json)->>'ok',
  'false',
  'get_user_entitlements_v1 NOT_AUTHORIZED: ok=false'
);
SELECT is(
  (public.get_user_entitlements_v1()::json)->>'code',
  'NOT_AUTHORIZED',
  'get_user_entitlements_v1 NOT_AUTHORIZED: code=NOT_AUTHORIZED'
);
SELECT is(
  (public.get_user_entitlements_v1()::json)->>'data',
  '{}',
  'get_user_entitlements_v1 NOT_AUTHORIZED: data={}'
);
SELECT isnt(
  (public.get_user_entitlements_v1()::json)->>'error',
  NULL,
  'get_user_entitlements_v1 NOT_AUTHORIZED: error present'
);

-- ============================================================
-- Gate logic derivable from single RPC call
-- ============================================================
-- Verify subscription_status field is present in all success responses
SELECT set_config('request.jwt.claims',
  '{"sub":"a0820000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"a0820000-0000-0000-0000-000000000001"}',
  true);

SELECT isnt(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_status',
  NULL,
  'get_user_entitlements_v1: subscription_status always present in success response'
);

SELECT * FROM finish();
ROLLBACK;
