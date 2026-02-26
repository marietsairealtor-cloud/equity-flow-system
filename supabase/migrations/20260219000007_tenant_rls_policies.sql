-- 20260219000007_tenant_rls_policies.sql
-- Build Route 6.3 — Tenant isolation RLS policies
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No $$.
-- Named dollar tags only where needed.

-- Helper: current tenant id from JWT claim (request.jwt.claim.tenant_id)
CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $current_tenant_id$
  SELECT nullif(current_setting('request.jwt.claim.tenant_id', true), '')::uuid
$current_tenant_id$;

-- Minimal privileges (scoped by RLS)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.deals TO authenticated;

-- Drop prior policies if they exist (idempotent on replay)
DROP POLICY IF EXISTS deals_select_own ON public.deals;
DROP POLICY IF EXISTS deals_insert_own ON public.deals;
DROP POLICY IF EXISTS deals_update_own ON public.deals;
DROP POLICY IF EXISTS deals_delete_own ON public.deals;

-- Deals: enforce tenant match
CREATE POLICY deals_select_own
  ON public.deals
  FOR SELECT
  TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE POLICY deals_insert_own
  ON public.deals
  FOR INSERT
  TO authenticated
  WITH CHECK (tenant_id = public.current_tenant_id());

CREATE POLICY deals_update_own
  ON public.deals
  FOR UPDATE
  TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE POLICY deals_delete_own
  ON public.deals
  FOR DELETE
  TO authenticated
  USING (tenant_id = public.current_tenant_id());