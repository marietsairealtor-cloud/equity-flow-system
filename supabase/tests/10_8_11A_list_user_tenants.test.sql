BEGIN;

SELECT plan(9);

-- 1. Function exists
SELECT has_function(
  'public', 'list_user_tenants_v1', ARRAY[]::text[],
  '10.8.11A: list_user_tenants_v1 exists'
);

-- Seed data (as postgres role, before switching to authenticated)
INSERT INTO public.tenants (id) VALUES ('b0000000-0000-0000-0000-000000000001') ON CONFLICT DO NOTHING;
INSERT INTO public.tenants (id) VALUES ('b0000000-0000-0000-0000-000000000002') ON CONFLICT DO NOTHING;
INSERT INTO public.user_profiles (id, current_tenant_id)
  VALUES ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001')
  ON CONFLICT (id) DO UPDATE SET current_tenant_id = EXCLUDED.current_tenant_id;
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'owner')
  ON CONFLICT DO NOTHING;
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'member')
  ON CONFLICT DO NOTHING;

-- 2. Authenticated user with no memberships returns empty items array
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000099","role":"authenticated"}';
SET LOCAL ROLE authenticated;

SELECT is(
  public.list_user_tenants_v1()->'data'->'items',
  '[]'::jsonb,
  '10.8.11A: authenticated user with no memberships returns empty items array'
);

RESET ROLE;

-- Switch to test user
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;

-- 3. Returns correct role
SELECT is(
  (SELECT value->>'role' FROM jsonb_array_elements(
    public.list_user_tenants_v1()->'data'->'items'
  ) WHERE (value->>'tenant_id') = 'b0000000-0000-0000-0000-000000000001'),
  'owner',
  '10.8.11A: returns correct role for owner'
);

-- 4. is_current true for current tenant
SELECT is(
  (SELECT value->>'is_current' FROM jsonb_array_elements(
    public.list_user_tenants_v1()->'data'->'items'
  ) WHERE (value->>'tenant_id') = 'b0000000-0000-0000-0000-000000000001'),
  'true',
  '10.8.11A: is_current true for current tenant'
);

-- 5. Returns both tenants
SELECT is(
  jsonb_array_length(public.list_user_tenants_v1()->'data'->'items'),
  2,
  '10.8.11A: returns both tenants for user with two memberships'
);

-- 6. Only one tenant marked as current
SELECT is(
  (SELECT COUNT(*)::int FROM jsonb_array_elements(
    public.list_user_tenants_v1()->'data'->'items'
  ) WHERE (value->>'is_current')::boolean = true),
  1,
  '10.8.11A: only one tenant marked as current'
);

RESET ROLE;
RESET "request.jwt.claims";

-- 7. anon cannot execute
SELECT ok(
  NOT has_function_privilege('anon', 'public.list_user_tenants_v1()', 'EXECUTE'),
  '10.8.11A: anon cannot EXECUTE list_user_tenants_v1'
);

-- 8. authenticated can execute
SELECT ok(
  has_function_privilege('authenticated', 'public.list_user_tenants_v1()', 'EXECUTE'),
  '10.8.11A: authenticated can EXECUTE list_user_tenants_v1'
);

-- 9. NOT_AUTHORIZED with no auth context
SELECT is(
  public.list_user_tenants_v1()->>'code',
  'NOT_AUTHORIZED',
  '10.8.11A: returns NOT_AUTHORIZED with no auth context'
);

SELECT * FROM finish();

ROLLBACK;