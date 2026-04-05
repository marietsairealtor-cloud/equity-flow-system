-- 10_8_11E_workspace_settings_read.test.sql

BEGIN;

SELECT plan(6);

-- Test 1: function exists
SELECT has_function(
  'public',
  'get_workspace_settings_v1',
  ARRAY[]::text[],
  'get_workspace_settings_v1 exists in public schema'
);

-- Test 2: authenticated can execute
SELECT ok(
  has_function_privilege('authenticated', 'public.get_workspace_settings_v1()', 'EXECUTE'),
  'authenticated can execute get_workspace_settings_v1'
);

-- Test 3: anon cannot execute
SELECT ok(
  NOT has_function_privilege('anon', 'public.get_workspace_settings_v1()', 'EXECUTE'),
  'anon cannot execute get_workspace_settings_v1'
);

-- Test 4: no tenant context returns NOT_AUTHORIZED
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;

SELECT is(
  (SELECT public.get_workspace_settings_v1() ->> 'code'),
  'NOT_AUTHORIZED',
  'get_workspace_settings_v1 returns NOT_AUTHORIZED with no tenant context'
);

-- Seed data for tests 5 and 6
RESET ROLE;

INSERT INTO public.tenants (id)
VALUES ('40ae3df8-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (
  'c0000000-0000-0000-0000-000000000011',
  '40ae3df8-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000001',
  'admin'
)
ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES ('40ae3df8-0000-0000-0000-000000000001', 'ws-alpha')
ON CONFLICT (tenant_id) DO UPDATE
SET slug = EXCLUDED.slug;

-- Test 5: authenticated success with tenant context
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO '40ae3df8-0000-0000-0000-000000000001';

SELECT is(
  (SELECT (public.get_workspace_settings_v1() ->> 'ok')::boolean),
  true,
  'get_workspace_settings_v1 returns ok=true with valid tenant context'
);

-- Test 6: correct slug returned
SELECT is(
  (SELECT public.get_workspace_settings_v1() -> 'data' ->> 'slug'),
  'ws-alpha',
  'get_workspace_settings_v1 returns correct slug for valid tenant'
);

SELECT finish();

ROLLBACK;