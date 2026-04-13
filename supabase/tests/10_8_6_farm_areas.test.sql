-- 10.8.6: Farm Areas Table tests
BEGIN;

SELECT plan(13);

-- 1. tenant_farm_areas table exists
SELECT has_table('public', 'tenant_farm_areas', '10.8.6: tenant_farm_areas table exists');

-- 2. area_name column exists
SELECT has_column('public', 'tenant_farm_areas', 'area_name', '10.8.6: tenant_farm_areas has area_name');

-- 3. row_version column exists
SELECT has_column('public', 'tenant_farm_areas', 'row_version', '10.8.6: tenant_farm_areas has row_version');

-- 4. unique constraint on (tenant_id, area_name)
SELECT ok(
  EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_schema = 'public'
    AND table_name = 'tenant_farm_areas'
    AND constraint_type = 'UNIQUE'
    AND constraint_name = 'tenant_farm_areas_tenant_area_unique'
  ),
  '10.8.6: unique constraint on (tenant_id, area_name) exists'
);

-- 5. deals.farm_area_id column exists
SELECT has_column('public', 'deals', 'farm_area_id', '10.8.6: deals.farm_area_id FK column exists');

-- Seed tenant 1 + admin user
INSERT INTO public.tenants (id) VALUES
  ('e0000000-0000-0000-0000-000000000001'::uuid)
  ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role) VALUES
  ('e8000000-0000-0000-0000-000000000001'::uuid,
   'e0000000-0000-0000-0000-000000000001'::uuid,
   'e9000000-0000-0000-0000-000000000001'::uuid,
   'admin')
  ON CONFLICT DO NOTHING;

-- Seed tenant 2 + admin user for isolation tests
INSERT INTO public.tenants (id) VALUES
  ('e0000000-0000-0000-0000-000000000002'::uuid)
  ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role) VALUES
  ('e8000000-0000-0000-0000-000000000002'::uuid,
   'e0000000-0000-0000-0000-000000000002'::uuid,
   'e9000000-0000-0000-0000-000000000002'::uuid,
   'admin')
  ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end) VALUES
  ('e0000000-0000-0000-0000-000000000001'::uuid, 'active', now() + interval '1 year'),
  ('e0000000-0000-0000-0000-000000000002'::uuid, 'active', now() + interval '1 year');

SET LOCAL "request.jwt.claims" TO '{"sub":"e9000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'e0000000-0000-0000-0000-000000000001';

-- 6. create_farm_area_v1 succeeds
SELECT is(
  (public.create_farm_area_v1('Downtown Core') ->> 'code'),
  'OK',
  '10.8.6: create_farm_area_v1 succeeds for admin'
);

-- 7. create_farm_area_v1 returns CONFLICT on duplicate
SELECT is(
  (public.create_farm_area_v1('Downtown Core') ->> 'code'),
  'CONFLICT',
  '10.8.6: create_farm_area_v1 returns CONFLICT on duplicate area_name'
);

-- 8. list_farm_areas_v1 returns created area
SELECT is(
  jsonb_array_length(public.list_farm_areas_v1() -> 'data' -> 'items'),
  1,
  '10.8.6: list_farm_areas_v1 returns 1 item after create'
);

-- 9. delete_farm_area_v1 succeeds
SELECT is(
  public.delete_farm_area_v1(
    (SELECT (elem ->> 'farm_area_id')::uuid
     FROM jsonb_array_elements(public.list_farm_areas_v1() -> 'data' -> 'items') AS elem
     LIMIT 1)
  ) ->> 'code',
  'OK',
  '10.8.6: delete_farm_area_v1 succeeds'
);

-- 10. list_farm_areas_v1 returns empty after delete
SELECT is(
  jsonb_array_length(public.list_farm_areas_v1() -> 'data' -> 'items'),
  0,
  '10.8.6: list_farm_areas_v1 returns empty after delete'
);

-- 11. tenant isolation: tenant 2 sees zero farm areas
SET LOCAL "request.jwt.claims" TO '{"sub":"e9000000-0000-0000-0000-000000000002","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'e0000000-0000-0000-0000-000000000002';

SELECT is(
  (public.create_farm_area_v1('Tenant2 Area') ->> 'code'),
  'OK',
  '10.8.6: tenant 2 can create own farm area'
);

SET LOCAL "request.jwt.claims" TO '{"sub":"e9000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'e0000000-0000-0000-0000-000000000001';

SELECT is(
  jsonb_array_length(public.list_farm_areas_v1() -> 'data' -> 'items'),
  0,
  '10.8.6: tenant 1 sees zero items - tenant 2 area not visible'
);

-- 12. ON DELETE SET NULL: deleting farm area nulls deals.farm_area_id
RESET ROLE;

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage) VALUES
  ('e2000000-0000-0000-0000-000000000001'::uuid,
   'e0000000-0000-0000-0000-000000000001'::uuid,
   1, 1, 'New')
  ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_farm_areas (id, tenant_id, area_name) VALUES
  ('e4000000-0000-0000-0000-000000000001'::uuid,
   'e0000000-0000-0000-0000-000000000001'::uuid,
   'Test Area')
  ON CONFLICT DO NOTHING;

UPDATE public.deals
  SET farm_area_id = 'e4000000-0000-0000-0000-000000000001'::uuid
  WHERE id = 'e2000000-0000-0000-0000-000000000001'::uuid;

DELETE FROM public.tenant_farm_areas
  WHERE id = 'e4000000-0000-0000-0000-000000000001'::uuid;

SELECT is(
  (SELECT farm_area_id FROM public.deals
   WHERE id = 'e2000000-0000-0000-0000-000000000001'::uuid),
  NULL,
  '10.8.6: ON DELETE SET NULL - farm_area_id nulled when farm area deleted'
);

SELECT finish();
ROLLBACK;