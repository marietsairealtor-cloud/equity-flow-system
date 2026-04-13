-- 10.8.11N: Expired Subscription Server-Side Write Lock tests
-- Tests behavior through protected write RPCs only
-- check_workspace_write_allowed_v1 is internal-only, not directly tested
BEGIN;

SELECT plan(7);

SELECT public.create_active_workspace_seed_v1(
  'f1000000-0000-0000-0000-000000000001'::uuid,
  'f0000000-0000-0000-0000-000000000001'::uuid,
  'admin'
);

SET LOCAL "request.jwt.claims" TO '{"sub":"f0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"f1000000-0000-0000-0000-000000000001"}';
SET LOCAL ROLE authenticated;

-- 1. write RPC allowed when active
SELECT is(
  (public.create_farm_area_v1('Lock Test Area') ->> 'ok')::boolean,
  true,
  'create_farm_area_v1 succeeds when subscription active'
);

-- 2. another write RPC allowed when active
SELECT is(
  (public.update_deal_v1(gen_random_uuid(), 1) ->> 'code'),
  'CONFLICT',
  'update_deal_v1 returns CONFLICT not NOT_AUTHORIZED when active'
);

-- Expire subscription
RESET ROLE;
UPDATE public.tenant_subscriptions
SET current_period_end = now() - interval '1 day'
WHERE tenant_id = 'f1000000-0000-0000-0000-000000000001';

SET LOCAL "request.jwt.claims" TO '{"sub":"f0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"f1000000-0000-0000-0000-000000000001"}';
SET LOCAL ROLE authenticated;

-- 3. write RPC blocked when expired
SELECT is(
  (public.create_farm_area_v1('Should Fail') ->> 'code'),
  'NOT_AUTHORIZED',
  'create_farm_area_v1 blocked when subscription expired'
);

-- 4. blocked write returns universal read-only message
SELECT is(
  (public.create_farm_area_v1('Should Fail') -> 'error' ->> 'message'),
  'This workspace is read-only. Renew your subscription to continue.',
  'blocked write returns universal read-only message'
);

-- 5. update_deal blocked when expired
SELECT is(
  (public.update_deal_v1(gen_random_uuid(), 1) ->> 'code'),
  'NOT_AUTHORIZED',
  'update_deal_v1 blocked when subscription expired'
);

-- 6. no subscription -- write blocked
RESET ROLE;
DELETE FROM public.tenant_subscriptions WHERE tenant_id = 'f1000000-0000-0000-0000-000000000001';

SET LOCAL "request.jwt.claims" TO '{"sub":"f0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"f1000000-0000-0000-0000-000000000001"}';
SET LOCAL ROLE authenticated;

SELECT is(
  (public.create_farm_area_v1('No Sub') ->> 'code'),
  'NOT_AUTHORIZED',
  'create_farm_area_v1 blocked when no subscription'
);

-- 7. submit_form_v1 blocked for expired workspace
RESET ROLE;
INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
VALUES ('f1000000-0000-0000-0000-000000000001', 'active', now() - interval '1 day');

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES ('f1000000-0000-0000-0000-000000000001', 'lock-test-ws')
ON CONFLICT DO NOTHING;

SELECT is(
  (public.submit_form_v1('lock-test-ws', 'seller', '{"spam_token":"test123","asking_price":"100000"}'::jsonb) ->> 'code'),
  'NOT_AUTHORIZED',
  'submit_form_v1 blocked when workspace expired'
);

SELECT finish();
ROLLBACK;