-- 6.8 Seat + role model (per-seat billing-ready)
-- Adds tenant_role enum, expands tenant_memberships stub, co-locates RLS + privilege revoke.

-- 1) Create role enum
CREATE TYPE public.tenant_role AS ENUM ('owner', 'admin', 'member');

-- 2) Expand tenant_memberships stub
ALTER TABLE public.tenant_memberships
  ADD COLUMN tenant_id uuid NOT NULL REFERENCES public.tenants(id),
  ADD COLUMN user_id   uuid NOT NULL,
  ADD COLUMN role      public.tenant_role NOT NULL DEFAULT 'member',
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();

-- 3) One seat per user per tenant
ALTER TABLE public.tenant_memberships
  ADD CONSTRAINT tenant_memberships_tenant_user_unique UNIQUE (tenant_id, user_id);

-- 4) RLS is already enabled (from baseline migration 20260219000006).
--    Add tenant-isolation policies.
CREATE POLICY tenant_memberships_select_own
  ON public.tenant_memberships
  FOR SELECT TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE POLICY tenant_memberships_insert_own
  ON public.tenant_memberships
  FOR INSERT TO authenticated
  WITH CHECK (tenant_id = public.current_tenant_id());

CREATE POLICY tenant_memberships_update_own
  ON public.tenant_memberships
  FOR UPDATE TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE POLICY tenant_memberships_delete_own
  ON public.tenant_memberships
  FOR DELETE TO authenticated
  USING (tenant_id = public.current_tenant_id());

-- 5) Privilege firewall (CONTRACTS.md S12): no direct table access.
REVOKE ALL ON public.tenant_memberships FROM anon;
REVOKE ALL ON public.tenant_memberships FROM authenticated;
