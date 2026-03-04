-- pgTAP: 7.4 Entitlement truth
BEGIN;
SELECT plan(6);

-- Seed tenant + membership
INSERT INTO public.tenants (id) VALUES ('e0000000-0000-0000-0000-000000000001'::uuid);
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES ('e1000000-0000-0000-0000-000000000001'::uuid,
        'e0000000-0000-0000-0000-000000000001'::uuid,
        'a0000000-0000-0000-0000-000000000a01'::uuid,
        'admin');

-- 1) RPC exists
SELECT has_function('public', 'get_user_entitlements_v1', ARRAY[]::text[],
  'get_user_entitlements_v1 RPC exists');

-- 2) RPC is SECURITY DEFINER
SELECT results_eq(
  $tap$SELECT prosecdef FROM pg_proc WHERE proname = 'get_user_entitlements_v1' AND pronamespace = 'public'::regnamespace$tap$,
  ARRAY[true],
  'get_user_entitlements_v1 is SECURITY DEFINER'
);

-- 3) Member is entitled
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'e0000000-0000-0000-0000-000000000001', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000a01', true);

SELECT is(
  (public.get_user_entitlements_v1()::json -> 'data' ->> 'entitled')::boolean,
  true,
  'Member user is entitled'
);

-- 4) Role returned correctly
SELECT is(
  public.get_user_entitlements_v1()::json -> 'data' ->> 'role',
  'admin',
  'Member role returned as admin'
);

-- 5) Non-member is not entitled
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000a99', true);

SELECT is(
  (public.get_user_entitlements_v1()::json -> 'data' ->> 'entitled')::boolean,
  false,
  'Non-member user is not entitled'
);

-- 6) No tenant context returns NOT_AUTHORIZED
RESET ROLE;
SET ROLE authenticated;
RESET request.jwt.claim.tenant_id;
RESET request.jwt.claim.sub;

SELECT is(
  public.get_user_entitlements_v1()::json ->> 'code',
  'NOT_AUTHORIZED',
  'No context returns NOT_AUTHORIZED'
);

SELECT finish();
ROLLBACK;
