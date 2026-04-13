-- 10_8_11H_workspace_farm_areas_rpcs.test.sql
-- Tests: list_farm_areas_v1, create_farm_area_v1, delete_farm_area_v1

BEGIN;

SELECT plan(17);

-- ============================================================
-- SEED DATA (superuser context — no role switch yet)
-- ============================================================

-- Tenants
INSERT INTO public.tenants (id)
VALUES
  ('a1000000-0000-0000-0000-000000000001'),
  ('a1000000-0000-0000-0000-000000000002')
ON CONFLICT DO NOTHING;

-- Memberships
--   Tenant 1: user 01 = admin, user 02 = member
--   Tenant 2: user 03 = admin, user 04 = member
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES
  ('a2000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'admin'),
  ('a2000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'member'),
  ('a2000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000003', 'admin'),
  ('a2000000-0000-0000-0000-000000000004', 'a1000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000004', 'member')
ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end) VALUES
  ('a1000000-0000-0000-0000-000000000001', 'active', now() + interval '1 year'),
  ('a1000000-0000-0000-0000-000000000002', 'active', now() + interval '1 year');

-- Tenant slugs (required by RPCs that resolve tenant context)
INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES
  ('a1000000-0000-0000-0000-000000000001', 'ws-farm-test-1'),
  ('a1000000-0000-0000-0000-000000000002', 'ws-farm-test-2')
ON CONFLICT (tenant_id) DO UPDATE SET slug = EXCLUDED.slug;

-- Pre-seed a farm area for tenant 2 (isolation test data)
-- Done here in superuser context to avoid RLS issues
INSERT INTO public.tenant_farm_areas (id, tenant_id, area_name)
VALUES ('a3000000-0000-0000-0000-000000000099', 'a1000000-0000-0000-0000-000000000002', 'Uptown');

-- ============================================================
-- FUNCTION EXISTENCE TESTS (1-3)
-- ============================================================

-- Test 1: list_farm_areas_v1 exists
SELECT has_function(
  'public', 'list_farm_areas_v1', ARRAY[]::text[],
  'list_farm_areas_v1 exists'
);

-- Test 2: create_farm_area_v1 exists
SELECT has_function(
  'public', 'create_farm_area_v1', ARRAY['text'],
  'create_farm_area_v1 exists'
);

-- Test 3: delete_farm_area_v1 exists
SELECT has_function(
  'public', 'delete_farm_area_v1', ARRAY['uuid'],
  'delete_farm_area_v1 exists'
);

-- ============================================================
-- PRIVILEGE TESTS (4-5)
-- ============================================================

-- Test 4: authenticated can execute list_farm_areas_v1
SELECT ok(
  has_function_privilege('authenticated', 'public.list_farm_areas_v1()', 'EXECUTE'),
  'authenticated can execute list_farm_areas_v1'
);

-- Test 5: anon cannot execute list_farm_areas_v1
SELECT ok(
  NOT has_function_privilege('anon', 'public.list_farm_areas_v1()', 'EXECUTE'),
  'anon cannot execute list_farm_areas_v1'
);

-- ============================================================
-- TENANT 1 ADMIN — CRUD TESTS (6-12)
-- ============================================================

-- Set tenant 1 admin context
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'a1000000-0000-0000-0000-000000000001';

-- Test 6: list returns ok=true
SELECT is(
  (public.list_farm_areas_v1() ->> 'ok')::boolean,
  true,
  'list_farm_areas_v1 returns ok=true for admin'
);

-- Test 7: create success
SELECT is(
  (public.create_farm_area_v1('Downtown') ->> 'ok')::boolean,
  true,
  'admin can create farm area'
);

-- Test 8: post-call state — verify via RPC (not direct table query)
-- list should now contain exactly 1 item for tenant 1
SELECT is(
  jsonb_array_length(public.list_farm_areas_v1() -> 'data' -> 'items'),
  1,
  'farm area exists after create (verified via list RPC)'
);

-- Test 9: duplicate rejection
SELECT is(
  public.create_farm_area_v1('Downtown') ->> 'code',
  'CONFLICT',
  'duplicate farm area name returns CONFLICT'
);

-- Test 10: blank area name returns VALIDATION_ERROR
SELECT is(
  public.create_farm_area_v1('') ->> 'code',
  'VALIDATION_ERROR',
  'blank area name returns VALIDATION_ERROR'
);

-- Test 11: delete success — get the farm_area_id from list RPC first
SELECT is(
  (public.delete_farm_area_v1(
    (public.list_farm_areas_v1() -> 'data' -> 'items' -> 0 ->> 'farm_area_id')::uuid
  ) ->> 'ok')::boolean,
  true,
  'admin can delete farm area'
);

-- Test 12: post-call state — list should now be empty for tenant 1
SELECT is(
  jsonb_array_length(public.list_farm_areas_v1() -> 'data' -> 'items'),
  0,
  'farm area removed after delete (verified via list RPC)'
);

-- ============================================================
-- CROSS-TENANT ISOLATION TEST (13)
-- ============================================================

-- Still tenant 1 admin context — tenant 2's "Uptown" must not be visible
-- Test 13: tenant 1 cannot see tenant 2's farm areas
SELECT is(
  jsonb_array_length(public.list_farm_areas_v1() -> 'data' -> 'items'),
  0,
  'tenant 1 cannot see tenant 2 farm areas (isolation)'
);

-- ============================================================
-- MEMBER DENIED TESTS (14-15)
-- ============================================================

-- Switch to tenant 2 member context
RESET ROLE;
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000004","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'a1000000-0000-0000-0000-000000000002';

-- Test 14: member denied on create
SELECT throws_ok(
  $tap$SELECT public.create_farm_area_v1('Suburbs')$tap$,
  'P0001',
  NULL,
  'member cannot create farm area (throws exception)'
);

-- Test 15: member denied on delete
SELECT throws_ok(
  $tap$SELECT public.delete_farm_area_v1('a3000000-0000-0000-0000-000000000099')$tap$,
  'P0001',
  NULL,
  'member cannot delete farm area (throws exception)'
);

-- ============================================================
-- DELETE NON-EXISTENT TEST (16)
-- ============================================================

-- Switch to tenant 1 admin context
RESET ROLE;
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'a1000000-0000-0000-0000-000000000001';

-- Test 16: delete non-existent returns NOT_FOUND
SELECT is(
  public.delete_farm_area_v1('00000000-0000-0000-0000-000000000000') ->> 'code',
  'NOT_FOUND',
  'delete non-existent farm area returns NOT_FOUND'
);

-- ============================================================
-- CROSS-TENANT DELETE PROTECTION (17)
-- ============================================================

-- Test 17: tenant 1 admin cannot delete tenant 2's farm area
SELECT is(
  public.delete_farm_area_v1('a3000000-0000-0000-0000-000000000099') ->> 'code',
  'NOT_FOUND',
  'tenant 1 cannot delete tenant 2 farm area (cross-tenant protection)'
);

-- ============================================================

SELECT finish();

ROLLBACK;