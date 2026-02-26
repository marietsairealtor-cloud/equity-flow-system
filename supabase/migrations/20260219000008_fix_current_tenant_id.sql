-- 20260219000008_fix_current_tenant_id.sql
-- Fix: PostgREST stores custom claims in request.jwt.claims (JSON),
-- not request.jwt.claim.<key>. Support both pgTAP (set_config direct)
-- and PostgREST (JSON extraction) paths.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL.

CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $fn$
  SELECT COALESCE(
    nullif(current_setting('request.jwt.claim.tenant_id', true), '')::uuid,
    (nullif(current_setting('request.jwt.claims', true), '')::json ->> 'tenant_id')::uuid
  )
$fn$;
