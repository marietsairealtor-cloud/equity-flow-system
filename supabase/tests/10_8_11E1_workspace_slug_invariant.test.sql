-- 10_8_11E1_workspace_slug_invariant.test.sql

BEGIN;

SELECT plan(4);

-- Seed tenant for all tests
INSERT INTO public.tenants (id)
VALUES ('b0000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES ('b0000000-0000-0000-0000-000000000001', 'slug-invariant-test')
ON CONFLICT DO NOTHING;

-- Test 1: unique index on tenant_id exists
SELECT has_index(
  'public',
  'tenant_slugs',
  'tenant_slugs_tenant_id_unique',
  'tenant_slugs has unique index on tenant_id'
);

-- Test 2: duplicate slug rejected (behavioral slug uniqueness)
INSERT INTO public.tenants (id)
VALUES ('b0000000-0000-0000-0000-000000000002')
ON CONFLICT DO NOTHING;

SELECT throws_ok(
  $tap$
    INSERT INTO public.tenant_slugs (tenant_id, slug)
    VALUES ('b0000000-0000-0000-0000-000000000002', 'slug-invariant-test')
  $tap$,
  '23505',
  null,
  'second insert for same slug violates unique constraint'
);

-- Test 3: duplicate tenant_id rejected (behavioral tenant_id uniqueness)
SELECT throws_ok(
  $tap$
    INSERT INTO public.tenant_slugs (tenant_id, slug)
    VALUES ('b0000000-0000-0000-0000-000000000001', 'slug-invariant-test-2')
  $tap$,
  '23505',
  null,
  'second insert for same tenant_id violates unique constraint'
);

-- Test 4: get_workspace_settings_v1 returns expected slug for valid tenant
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (
  'c0000000-0000-0000-0000-000000000099',
  'b0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000001',
  'admin'
)
ON CONFLICT DO NOTHING;

SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'b0000000-0000-0000-0000-000000000001';

SELECT is(
  (SELECT public.get_workspace_settings_v1() -> 'data' ->> 'slug'),
  'slug-invariant-test',
  'get_workspace_settings_v1 returns expected slug for valid tenant'
);

SELECT finish();

ROLLBACK;