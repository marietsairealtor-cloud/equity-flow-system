-- 10.8.11I8: Corrective fix tests for list_user_tenants_v1
-- Proves workspace_name is sourced from public.tenants.name
BEGIN;

SELECT plan(3);

SET LOCAL session_replication_role = replica;

-- Seed tenant with name
INSERT INTO public.tenants (id, name)
VALUES ('e1000000-0000-0000-0000-000000000001', 'Test Workspace I8');

-- Seed auth user
INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES (
  'a2000000-0000-0000-0000-000000000001',
  'pgtap-i8@example.com',
  now(), now(),
  '{}', '{}',
  'authenticated', 'authenticated'
);

-- Seed membership
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (
  'b2000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001',
  'owner'
);

-- Seed user profile with current tenant
INSERT INTO public.user_profiles (id, current_tenant_id)
VALUES ('a2000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001');

SET LOCAL "request.jwt.claims" TO '{"sub":"a2000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;

-- 1. returns ok=true
SELECT is(
  (SELECT (public.list_user_tenants_v1() ->> 'ok')::boolean),
  true,
  'list_user_tenants_v1 returns ok=true'
);

-- 2. workspace_name matches tenant row
SELECT is(
  (SELECT public.list_user_tenants_v1() -> 'data' -> 'items' -> 0 ->> 'workspace_name'),
  'Test Workspace I8',
  'workspace_name sourced from public.tenants.name'
);

-- 3. workspace_name is not null
SELECT ok(
  (public.list_user_tenants_v1() -> 'data' -> 'items' -> 0 ->> 'workspace_name') IS NOT NULL,
  'workspace_name is not null'
);

SELECT finish();
ROLLBACK;