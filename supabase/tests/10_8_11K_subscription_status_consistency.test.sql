-- 10.8.11K: Subscription Status Consistency corrective fix tests
-- Proves RPC reads only stored DB statuses (webhook-normalized)
-- tenant_subscriptions.status constraint: active | expiring | expired | canceled
BEGIN;

SELECT plan(9);

-- Seed tenant, user, membership
INSERT INTO public.tenants (id)
VALUES ('b0820000-0000-0000-0000-000000000001'::uuid);

INSERT INTO auth.users (id, email)
VALUES ('b0820000-0000-0000-0000-000000000002'::uuid, 'entitlements_k_test@10_8_11K.test');

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (
  'b0820000-0000-0000-0000-000000000003'::uuid,
  'b0820000-0000-0000-0000-000000000001'::uuid,
  'b0820000-0000-0000-0000-000000000002'::uuid,
  'member'
);

SELECT set_config('request.jwt.claims',
  '{"sub":"b0820000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"b0820000-0000-0000-0000-000000000001"}',
  true);

-- Seed subscription
INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
VALUES (
  'b0820000-0000-0000-0000-000000000001'::uuid,
  'active',
  now() + interval '30 days'
);

-- 1. active >5 days → active, days_remaining=null
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_status',
  'active',
  'active >5 days → active derived status'
);

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_days_remaining',
  NULL,
  'active >5 days → days_remaining=null'
);

-- 2. active <=5 days → expiring, days_remaining not null
UPDATE public.tenant_subscriptions
SET current_period_end = now() + interval '3 days'
WHERE tenant_id = 'b0820000-0000-0000-0000-000000000001'::uuid;

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_status',
  'expiring',
  'active <=5 days → expiring derived status'
);

SELECT ok(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_days_remaining' IS NOT NULL,
  'active <=5 days → days_remaining not null'
);

-- 3. expired (period end past) → expired, days_remaining=null
UPDATE public.tenant_subscriptions
SET status = 'active', current_period_end = now() - interval '1 day'
WHERE tenant_id = 'b0820000-0000-0000-0000-000000000001'::uuid;

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_status',
  'expired',
  'period end past → expired derived status'
);

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_days_remaining',
  NULL,
  'period end past → days_remaining=null'
);

-- 4. canceled → expired, days_remaining=null
UPDATE public.tenant_subscriptions
SET status = 'canceled', current_period_end = now() + interval '10 days'
WHERE tenant_id = 'b0820000-0000-0000-0000-000000000001'::uuid;

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_status',
  'expired',
  'canceled → expired derived status'
);

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_days_remaining',
  NULL,
  'canceled → days_remaining=null'
);

-- 5. expiring stored status <=5 days → expiring
UPDATE public.tenant_subscriptions
SET status = 'expiring', current_period_end = now() + interval '3 days'
WHERE tenant_id = 'b0820000-0000-0000-0000-000000000001'::uuid;

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_status',
  'expiring',
  'stored expiring <=5 days → expiring derived status'
);

SELECT finish();
ROLLBACK;