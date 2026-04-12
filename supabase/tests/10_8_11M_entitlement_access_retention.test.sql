-- 10.8.11M: Entitlement RPC Access + Retention State Extension tests
BEGIN;

SELECT plan(14);

-- Seed two users
INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES
  ('c0000000-0000-0000-0000-000000000001', 'owner-m@example.com', now(), now(), '{}', '{}', 'authenticated', 'authenticated'),
  ('c0000000-0000-0000-0000-000000000002', 'member-m@example.com', now(), now(), '{}', '{}', 'authenticated', 'authenticated'),
  ('c0000000-0000-0000-0000-000000000003', 'nomember-m@example.com', now(), now(), '{}', '{}', 'authenticated', 'authenticated');

-- Seed tenant
INSERT INTO public.tenants (id, name)
VALUES ('d1000000-0000-0000-0000-000000000001', 'pgTAP M Tenant');

-- Seed memberships
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES
  ('e1000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'owner'),
  ('e1000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'member');

-- Seed user profiles
INSERT INTO public.user_profiles (id, current_tenant_id)
VALUES
  ('c0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001'),
  ('c0000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001');

-- Seed active subscription
INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
VALUES ('d1000000-0000-0000-0000-000000000001', 'active', now() + interval '30 days');

-- === ACTIVE subscription tests ===
SELECT set_config('request.jwt.claims',
  '{"sub":"c0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"d1000000-0000-0000-0000-000000000001"}',
  true);

-- 1. active → app_mode = normal
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'app_mode',
  'normal',
  'active subscription → app_mode=normal'
);

-- 2. owner → can_manage_billing = true
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'can_manage_billing',
  'true',
  'owner → can_manage_billing=true'
);

-- 3. owner → renew_route = billing
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'renew_route',
  'billing',
  'owner → renew_route=billing'
);

-- 4. member → can_manage_billing = false
SELECT set_config('request.jwt.claims',
  '{"sub":"c0000000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"d1000000-0000-0000-0000-000000000001"}',
  true);

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'can_manage_billing',
  'false',
  'member → can_manage_billing=false'
);

-- 5. member → renew_route = none
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'renew_route',
  'none',
  'member → renew_route=none'
);

-- === EXPIRED within grace window ===
SELECT set_config('request.jwt.claims',
  '{"sub":"c0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"d1000000-0000-0000-0000-000000000001"}',
  true);

UPDATE public.tenant_subscriptions
SET status = 'expired', current_period_end = now() - interval '10 days'
WHERE tenant_id = 'd1000000-0000-0000-0000-000000000001';

-- 6. expired within grace → app_mode = read_only_expired
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'app_mode',
  'read_only_expired',
  'expired within grace → app_mode=read_only_expired'
);

-- 7. expired within grace + owner → renew_route = billing
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'renew_route',
  'billing',
  'expired within grace + owner → renew_route=billing'
);

-- 8. retention_deadline is not null
SELECT ok(
  (public.get_user_entitlements_v1()::json)->'data'->>'retention_deadline' IS NOT NULL,
  'expired within grace → retention_deadline not null'
);

-- === EXPIRED beyond grace window ===
UPDATE public.tenant_subscriptions
SET current_period_end = now() - interval '70 days'
WHERE tenant_id = 'd1000000-0000-0000-0000-000000000001';

-- 9. expired beyond grace → app_mode = archived_unreachable
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'app_mode',
  'archived_unreachable',
  'expired beyond grace → app_mode=archived_unreachable'
);

-- 10. archived → can_manage_billing = false
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'can_manage_billing',
  'false',
  'archived → can_manage_billing=false'
);

-- 11. archived → renew_route = none
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'renew_route',
  'none',
  'archived → renew_route=none'
);

-- 12. archived → days_until_deletion not null
SELECT ok(
  (public.get_user_entitlements_v1()::json)->'data'->>'days_until_deletion' IS NOT NULL,
  'archived → days_until_deletion not null'
);

-- === NO SUBSCRIPTION ===
DELETE FROM public.tenant_subscriptions
WHERE tenant_id = 'd1000000-0000-0000-0000-000000000001';

-- 13. no subscription → app_mode = read_only_expired
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'app_mode',
  'read_only_expired',
  'no subscription → app_mode=read_only_expired'
);

-- === NO MEMBERSHIP ===
INSERT INTO public.user_profiles (id, current_tenant_id)
VALUES ('c0000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

SELECT set_config('request.jwt.claims',
  '{"sub":"c0000000-0000-0000-0000-000000000003","role":"authenticated","tenant_id":"d1000000-0000-0000-0000-000000000001"}',
  true);

-- 14. no membership → is_member = false
SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'is_member',
  'false',
  'no membership → is_member=false'
);

SELECT finish();
ROLLBACK;