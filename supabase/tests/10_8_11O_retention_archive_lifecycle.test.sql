-- 10.8.11O: Expired Workspace Retention + Archive Lifecycle Automation tests
BEGIN;

SELECT plan(12);

-- ===================================================================
-- Seed base workspaces using create_active_workspace_seed_v1
-- Then mutate to the state under test
-- ===================================================================

-- Tenant 1: recovery path -- lapsed state + active subscription returned
SELECT public.create_active_workspace_seed_v1(
  'b1000000-0000-0000-0000-000000000001'::uuid,
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'owner'
);
UPDATE public.tenants
SET subscription_lapsed_at = now() - interval '10 days'
WHERE id = 'b1000000-0000-0000-0000-000000000001';
-- subscription already active + future period_end from seed helper

-- Tenant 2: lapse detection -- membership + no subscription, lapsed_at not set
SELECT public.create_active_workspace_seed_v1(
  'b2000000-0000-0000-0000-000000000002'::uuid,
  'a0000000-0000-0000-0000-000000000002'::uuid,
  'owner'
);
DELETE FROM public.tenant_subscriptions
WHERE tenant_id = 'b2000000-0000-0000-0000-000000000002';

-- Tenant 3: lapse anchor not overwritten -- lapsed 5 days ago, no subscription
SELECT public.create_active_workspace_seed_v1(
  'b3000000-0000-0000-0000-000000000003'::uuid,
  'a0000000-0000-0000-0000-000000000003'::uuid,
  'owner'
);
DELETE FROM public.tenant_subscriptions
WHERE tenant_id = 'b3000000-0000-0000-0000-000000000003';
UPDATE public.tenants
SET subscription_lapsed_at = now() - interval '5 days'
WHERE id = 'b3000000-0000-0000-0000-000000000003';

-- Tenant 4: archive subscription path -- expired, current_period_end 65 days ago
SELECT public.create_active_workspace_seed_v1(
  'b4000000-0000-0000-0000-000000000004'::uuid,
  'a0000000-0000-0000-0000-000000000004'::uuid,
  'owner'
);
UPDATE public.tenant_subscriptions
SET status = 'expired', current_period_end = now() - interval '65 days'
WHERE tenant_id = 'b4000000-0000-0000-0000-000000000004';

-- Tenant 5: archive no-subscription path -- lapsed 65 days ago, no subscription
SELECT public.create_active_workspace_seed_v1(
  'b5000000-0000-0000-0000-000000000005'::uuid,
  'a0000000-0000-0000-0000-000000000005'::uuid,
  'owner'
);
DELETE FROM public.tenant_subscriptions
WHERE tenant_id = 'b5000000-0000-0000-0000-000000000005';
UPDATE public.tenants
SET subscription_lapsed_at = now() - interval '65 days'
WHERE id = 'b5000000-0000-0000-0000-000000000005';

-- Tenant 6: hard delete path -- archived 7 months ago
SELECT public.create_active_workspace_seed_v1(
  'b6000000-0000-0000-0000-000000000006'::uuid,
  'a0000000-0000-0000-0000-000000000006'::uuid,
  'owner'
);
UPDATE public.tenants
SET archived_at = now() - interval '7 months'
WHERE id = 'b6000000-0000-0000-0000-000000000006';

-- ===================================================================
-- Run the processor
-- ===================================================================
SELECT public.process_workspace_retention_v1();

-- ===================================================================
-- Assertions
-- ===================================================================

-- 1. Recovery: subscription_lapsed_at cleared for tenant 1
SELECT is(
  (SELECT subscription_lapsed_at FROM public.tenants WHERE id = 'b1000000-0000-0000-0000-000000000001'),
  NULL,
  'recovery: subscription_lapsed_at cleared when active subscription returned'
);

-- 2. Lapse detection: subscription_lapsed_at set for tenant 2
SELECT ok(
  (SELECT subscription_lapsed_at FROM public.tenants WHERE id = 'b2000000-0000-0000-0000-000000000002') IS NOT NULL,
  'lapse detection: subscription_lapsed_at set for membership + no subscription'
);

-- 3. Lapse anchor not overwritten for tenant 3
SELECT ok(
  (SELECT subscription_lapsed_at FROM public.tenants WHERE id = 'b3000000-0000-0000-0000-000000000003') <= now() - interval '4 days',
  'lapse detection: existing subscription_lapsed_at not overwritten'
);

-- 4. Archive subscription path: tenant 4 archived
SELECT ok(
  (SELECT archived_at FROM public.tenants WHERE id = 'b4000000-0000-0000-0000-000000000004') IS NOT NULL,
  'archive subscription path: archived after 60-day current_period_end anchor'
);

-- 5. Archive no-subscription path: tenant 5 archived
SELECT ok(
  (SELECT archived_at FROM public.tenants WHERE id = 'b5000000-0000-0000-0000-000000000005') IS NOT NULL,
  'archive no-subscription path: archived after 60-day lapsed anchor'
);

-- 6. Tenant 1 not archived (active subscription, recovered)
SELECT is(
  (SELECT archived_at FROM public.tenants WHERE id = 'b1000000-0000-0000-0000-000000000001'),
  NULL,
  'active subscription workspace not archived'
);

-- 7. Tenant 3 not archived (lapsed only 5 days, within 60-day window)
SELECT is(
  (SELECT archived_at FROM public.tenants WHERE id = 'b3000000-0000-0000-0000-000000000003'),
  NULL,
  'no-subscription workspace within 60-day window not archived'
);

-- 8. Hard delete: tenants row gone for tenant 6
SELECT is(
  (SELECT count(*)::int FROM public.tenants WHERE id = 'b6000000-0000-0000-0000-000000000006'),
  0,
  'hard delete: tenants row deleted after 6-month archive window'
);

-- 9. Hard delete: tenant_memberships for tenant 6 gone
SELECT is(
  (SELECT count(*)::int FROM public.tenant_memberships WHERE tenant_id = 'b6000000-0000-0000-0000-000000000006'),
  0,
  'hard delete: tenant_memberships deleted explicitly'
);

-- 10. Tenant 4 not hard deleted (just archived, not 6 months old)
SELECT is(
  (SELECT count(*)::int FROM public.tenants WHERE id = 'b4000000-0000-0000-0000-000000000004'),
  1,
  'recently archived workspace not hard deleted'
);

-- 11. Return envelope ok=true
SELECT is(
  (public.process_workspace_retention_v1()::json)->>'ok',
  'true',
  'return envelope ok=true'
);

-- 12. Return envelope code=OK
SELECT is(
  (public.process_workspace_retention_v1()::json)->>'code',
  'OK',
  'return envelope code=OK'
);

SELECT finish();
ROLLBACK;