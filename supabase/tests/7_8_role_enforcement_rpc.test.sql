-- pgTAP: 7.8 Role enforcement on privileged RPCs
-- Proves: require_min_role_v1 enforces role hierarchy correctly.
-- Catalog audit: no privileged RPCs exist without role guard.
-- Note: require_min_role_v1 is an internal helper (no EXECUTE grant to authenticated).
-- Tests run as superuser with JWT claims set to simulate calling context.
BEGIN;
SELECT plan(12);

-- Seed tenant + three users with different roles
INSERT INTO public.tenants (id) VALUES ('f0000000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role) VALUES
  ('f1000000-0000-0000-0000-000000000001'::uuid, 'f0000000-0000-0000-0000-000000000001'::uuid,
   'a0000000-0000-0000-0000-0000000000a1'::uuid, 'member'),
  ('f1000000-0000-0000-0000-000000000002'::uuid, 'f0000000-0000-0000-0000-000000000001'::uuid,
   'a0000000-0000-0000-0000-0000000000a2'::uuid, 'admin'),
  ('f1000000-0000-0000-0000-000000000003'::uuid, 'f0000000-0000-0000-0000-000000000001'::uuid,
   'a0000000-0000-0000-0000-0000000000a3'::uuid, 'owner');

-- ============================================================
-- Test 1: require_min_role_v1 function exists
-- ============================================================
SELECT has_function('public', 'require_min_role_v1', ARRAY['tenant_role'],
  'require_min_role_v1(tenant_role) exists');

-- ============================================================
-- Enum ordering invariant (QA guard against future reordering)
-- PostgreSQL enum order: owner(0) < admin(1) < member(2)
-- ============================================================
SELECT ok('owner'::public.tenant_role < 'admin'::public.tenant_role,
  'enum invariant: owner < admin');
SELECT ok('admin'::public.tenant_role < 'member'::public.tenant_role,
  'enum invariant: admin < member');

-- ============================================================
-- Member context: blocked from admin and owner operations
-- ============================================================
RESET ROLE;
SELECT set_config('request.jwt.claim.tenant_id', 'f0000000-0000-0000-0000-000000000001', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-0000000000a1', true);

-- Test 4: member calling require_min_role_v1('admin') raises NOT_AUTHORIZED
SELECT throws_ok(
  $tap$SELECT public.require_min_role_v1('admin'::public.tenant_role)$tap$,
  'P0001',
  'NOT_AUTHORIZED',
  'member: require_min_role_v1(admin) raises NOT_AUTHORIZED'
);

-- Test 5: member calling require_min_role_v1('owner') raises NOT_AUTHORIZED
SELECT throws_ok(
  $tap$SELECT public.require_min_role_v1('owner'::public.tenant_role)$tap$,
  'P0001',
  'NOT_AUTHORIZED',
  'member: require_min_role_v1(owner) raises NOT_AUTHORIZED'
);

-- Test 6: member calling require_min_role_v1('member') passes
SELECT lives_ok(
  $tap$SELECT public.require_min_role_v1('member'::public.tenant_role)$tap$,
  'member: require_min_role_v1(member) passes'
);

-- ============================================================
-- Admin context: passes admin, blocked from owner
-- ============================================================
RESET ROLE;
SELECT set_config('request.jwt.claim.tenant_id', 'f0000000-0000-0000-0000-000000000001', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-0000000000a2', true);

-- Test 7: admin calling require_min_role_v1('admin') passes
SELECT lives_ok(
  $tap$SELECT public.require_min_role_v1('admin'::public.tenant_role)$tap$,
  'admin: require_min_role_v1(admin) passes'
);

-- Test 8: admin calling require_min_role_v1('owner') raises NOT_AUTHORIZED
SELECT throws_ok(
  $tap$SELECT public.require_min_role_v1('owner'::public.tenant_role)$tap$,
  'P0001',
  'NOT_AUTHORIZED',
  'admin: require_min_role_v1(owner) raises NOT_AUTHORIZED'
);

-- Test 9: admin calling require_min_role_v1('member') passes
SELECT lives_ok(
  $tap$SELECT public.require_min_role_v1('member'::public.tenant_role)$tap$,
  'admin: require_min_role_v1(member) passes'
);

-- ============================================================
-- Owner context: passes all levels
-- ============================================================
RESET ROLE;
SELECT set_config('request.jwt.claim.tenant_id', 'f0000000-0000-0000-0000-000000000001', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-0000000000a3', true);

-- Test 10: owner calling require_min_role_v1('owner') passes
SELECT lives_ok(
  $tap$SELECT public.require_min_role_v1('owner'::public.tenant_role)$tap$,
  'owner: require_min_role_v1(owner) passes'
);

-- Test 11: owner calling require_min_role_v1('admin') passes
SELECT lives_ok(
  $tap$SELECT public.require_min_role_v1('admin'::public.tenant_role)$tap$,
  'owner: require_min_role_v1(admin) passes'
);

-- ============================================================
-- Catalog audit: no privileged RPCs missing role guard
-- ============================================================
RESET ROLE;

-- Test 12: All SECURITY DEFINER functions in public schema that match
-- privileged keywords (tenant, membership, role, seat, billing, plan, subscription)
-- either don't exist or contain require_min_role_v1 in their body.
SELECT is(
  (SELECT count(*)::int FROM pg_proc p
   JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.prosecdef = true
     AND p.proname ~* '(tenant|membership|role|seat|billing|plan|subscription)'
     AND p.proname != 'require_min_role_v1'
     AND p.proname != 'current_tenant_id'
     AND p.proname != 'create_tenant_v1'
     AND p.proname != 'list_user_tenants_v1'
     AND p.proname != 'upsert_subscription_v1'
     AND NOT (pg_get_functiondef(p.oid) ~* 'require_min_role_v1')),
  0,
  'Catalog audit: zero privileged RPCs missing require_min_role_v1 guard'
);

SELECT finish();
ROLLBACK;

