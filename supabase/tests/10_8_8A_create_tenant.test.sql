
-- pgTAP test: 10_8_8A_create_tenant.test.sql
-- Paired migration: 20260326000001_10_8_8A_create_tenant.sql
-- Verifies create_tenant_v1(p_idempotency_key text) per Build Route 10.8.8A DoD.
-- Rules: SQL-only, no DO blocks, no PL/pgSQL, no psql meta-commands, BEGIN/ROLLBACK.

BEGIN;

SELECT plan(8);

-- 1. RPC exists with correct signature
SELECT has_function('public','create_tenant_v1',ARRAY['text'],'10.8.8A: create_tenant_v1(text) exists');

-- 2. RPC is SECURITY DEFINER
SELECT is((SELECT p.prosecdef FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'create_tenant_v1' AND pg_get_function_arguments(p.oid) = 'p_idempotency_key text'),true,'10.8.8A: create_tenant_v1 is SECURITY DEFINER');

-- 3. anon cannot execute
SELECT ok(NOT has_function_privilege('anon','public.create_tenant_v1(text)','EXECUTE'),'10.8.8A: anon cannot EXECUTE create_tenant_v1');

-- 4. authenticated can execute
SELECT ok(has_function_privilege('authenticated','public.create_tenant_v1(text)','EXECUTE'),'10.8.8A: authenticated can EXECUTE create_tenant_v1');

-- 5. NULL key returns VALIDATION_ERROR and data is object
SELECT is((SELECT public.create_tenant_v1(NULL) ->> 'code'),'VALIDATION_ERROR','10.8.8A: NULL idempotency key returns VALIDATION_ERROR');

-- 6. Empty key returns VALIDATION_ERROR
SELECT is((SELECT public.create_tenant_v1('') ->> 'code'),'VALIDATION_ERROR','10.8.8A: empty idempotency key returns VALIDATION_ERROR');

-- 7. Unauthenticated call returns NOT_AUTHORIZED
SELECT is((SELECT public.create_tenant_v1('any-key') ->> 'code'),'NOT_AUTHORIZED','10.8.8A: unauthenticated call returns NOT_AUTHORIZED');

-- 8. data is always an object on error path
SELECT ok((SELECT public.create_tenant_v1('any-key') -> 'data') IS NOT NULL,'10.8.8A: data field is always an object never null on error path');

SELECT finish();

ROLLBACK;
