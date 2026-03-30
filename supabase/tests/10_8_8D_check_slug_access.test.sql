-- pgTAP test: 10_8_8D_check_slug_access.test.sql
-- Paired migration: 20260330000001_10_8_8D_check_slug_access.sql
-- Verifies check_slug_access_v1(p_slug text) per Build Route 10.8.8D DoD.
-- Rules: SQL-only, no DO blocks, no PL/pgSQL, no psql meta-commands, BEGIN/ROLLBACK.

BEGIN;

SELECT plan(16);

-- 1. RPC exists with correct signature
SELECT has_function('public','check_slug_access_v1',ARRAY['text'],'10.8.8D: check_slug_access_v1(text) exists');

-- 2. RPC is SECURITY DEFINER
SELECT is(
  (SELECT p.prosecdef FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'check_slug_access_v1' AND pg_get_function_arguments(p.oid) = 'p_slug text'),
  true,
  '10.8.8D: check_slug_access_v1 is SECURITY DEFINER'
);

-- 3. anon cannot execute
SELECT ok(NOT has_function_privilege('anon','public.check_slug_access_v1(text)','EXECUTE'),'10.8.8D: anon cannot EXECUTE check_slug_access_v1');

-- 4. authenticated can execute
SELECT ok(has_function_privilege('authenticated','public.check_slug_access_v1(text)','EXECUTE'),'10.8.8D: authenticated can EXECUTE check_slug_access_v1');

-- 5. NULL slug returns VALIDATION_ERROR
SELECT is((SELECT public.check_slug_access_v1(NULL) ->> 'code'),'VALIDATION_ERROR','10.8.8D: NULL slug returns VALIDATION_ERROR');

-- 6. Empty slug returns VALIDATION_ERROR
SELECT is((SELECT public.check_slug_access_v1('') ->> 'code'),'VALIDATION_ERROR','10.8.8D: empty slug returns VALIDATION_ERROR');

-- 7. Invalid slug format returns VALIDATION_ERROR
SELECT is((SELECT public.check_slug_access_v1('INVALID SLUG!!') ->> 'code'),'VALIDATION_ERROR','10.8.8D: invalid slug format returns VALIDATION_ERROR');

-- 8. Unauthenticated call returns NOT_AUTHORIZED
SELECT is((SELECT public.check_slug_access_v1('valid-slug') ->> 'code'),'NOT_AUTHORIZED','10.8.8D: unauthenticated call returns NOT_AUTHORIZED');

-- 9. data is always an object on error path
SELECT ok((SELECT public.check_slug_access_v1('valid-slug') -> 'data') IS NOT NULL,'10.8.8D: data field is always an object never null on error path');

-- Seed: tenant, slug, users with different roles
INSERT INTO public.tenants (id) VALUES ('dd880000-0001-0001-0001-000000000001'::uuid);

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES ('dd880000-0001-0001-0001-000000000001'::uuid, 'test-slug-8d');

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role) VALUES
  (gen_random_uuid(), 'dd880000-0001-0001-0001-000000000001'::uuid, 'dd880000-0002-0002-0002-000000000001'::uuid, 'owner'),
  (gen_random_uuid(), 'dd880000-0001-0001-0001-000000000001'::uuid, 'dd880000-0002-0002-0002-000000000002'::uuid, 'admin'),
  (gen_random_uuid(), 'dd880000-0001-0001-0001-000000000001'::uuid, 'dd880000-0002-0002-0002-000000000003'::uuid, 'member');

-- Set auth context to owner user
SELECT set_config('request.jwt.claims', '{"sub":"dd880000-0002-0002-0002-000000000001","role":"authenticated"}', true);
SET LOCAL role TO authenticated;

-- 10. Slug not found returns slug_taken=false
SELECT is((SELECT public.check_slug_access_v1('slug-does-not-exist') -> 'data' ->> 'slug_taken'),'false','10.8.8D: slug not found returns slug_taken=false');

-- 11. Slug not found returns is_owner_or_admin=false
SELECT is((SELECT public.check_slug_access_v1('slug-does-not-exist') -> 'data' ->> 'is_owner_or_admin'),'false','10.8.8D: slug not found returns is_owner_or_admin=false');

-- 12. Slug found + owner: slug_taken=true
SELECT is((SELECT public.check_slug_access_v1('test-slug-8d') -> 'data' ->> 'slug_taken'),'true','10.8.8D: slug found + owner returns slug_taken=true');

-- 13. Slug found + owner: is_owner_or_admin=true
SELECT is((SELECT public.check_slug_access_v1('test-slug-8d') -> 'data' ->> 'is_owner_or_admin'),'true','10.8.8D: slug found + owner returns is_owner_or_admin=true');

-- 14. Slug found + owner: tenant_id not null
SELECT ok((SELECT (public.check_slug_access_v1('test-slug-8d') -> 'data' ->> 'tenant_id')::uuid IS NOT NULL),'10.8.8D: slug found + owner returns tenant_id');

-- Switch to member user (not owner/admin)
SELECT set_config('request.jwt.claims', '{"sub":"dd880000-0002-0002-0002-000000000003","role":"authenticated"}', true);

-- 15. Slug found + member: is_owner_or_admin=false
SELECT is((SELECT public.check_slug_access_v1('test-slug-8d') -> 'data' ->> 'is_owner_or_admin'),'false','10.8.8D: slug found + member returns is_owner_or_admin=false');

-- 16. Slug found + member: no tenant_id leak
SELECT is((SELECT public.check_slug_access_v1('test-slug-8d') -> 'data' ->> 'tenant_id'),null,'10.8.8D: slug found + member -- no tenant_id leak');

SELECT finish();

ROLLBACK;