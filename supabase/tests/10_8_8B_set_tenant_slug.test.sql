-- pgTAP test: 10_8_8B_set_tenant_slug.test.sql
-- Paired migration: 20260327000004_10_8_8B_set_tenant_slug.sql
-- Verifies set_tenant_slug_v1(p_slug text) per Build Route 10.8.8B DoD.
-- Rules: SQL-only, no DO blocks, no PL/pgSQL, no psql meta-commands, BEGIN/ROLLBACK.

BEGIN;

SELECT plan(8);

-- 1. RPC exists with correct signature
SELECT has_function('public','set_tenant_slug_v1',ARRAY['text'],'10.8.8B: set_tenant_slug_v1(text) exists');

-- 2. RPC is SECURITY DEFINER
SELECT is(
  (SELECT p.prosecdef FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'set_tenant_slug_v1' AND pg_get_function_arguments(p.oid) = 'p_slug text'),
  true,
  '10.8.8B: set_tenant_slug_v1 is SECURITY DEFINER'
);

-- 3. anon cannot execute
SELECT ok(NOT has_function_privilege('anon','public.set_tenant_slug_v1(text)','EXECUTE'),'10.8.8B: anon cannot EXECUTE set_tenant_slug_v1');

-- 4. authenticated can execute
SELECT ok(has_function_privilege('authenticated','public.set_tenant_slug_v1(text)','EXECUTE'),'10.8.8B: authenticated can EXECUTE set_tenant_slug_v1');

-- 5. UNIQUE(tenant_id) constraint exists on tenant_slugs
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND t.relname = 'tenant_slugs'
      AND c.conname = 'tenant_slugs_tenant_id_unique'
      AND c.contype = 'u'
  ),
  '10.8.8B: tenant_slugs has UNIQUE(tenant_id) constraint'
);

-- 6. Unauthenticated call returns NOT_AUTHORIZED
SELECT is((SELECT public.set_tenant_slug_v1('valid-slug') ->> 'code'),'NOT_AUTHORIZED','10.8.8B: unauthenticated call returns NOT_AUTHORIZED');

-- 7. data is always an object on error path
SELECT ok((SELECT public.set_tenant_slug_v1('valid-slug') -> 'data') IS NOT NULL,'10.8.8B: data field is always an object never null on error path');

-- 8. ok is false on unauthenticated call
SELECT is((SELECT public.set_tenant_slug_v1('valid-slug') ->> 'ok'),'false','10.8.8B: ok=false on unauthenticated call');

SELECT finish();

ROLLBACK;