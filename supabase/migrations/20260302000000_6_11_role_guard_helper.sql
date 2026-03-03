-- 6.11 Role Guard Helper (Internal, Non-Executable)
-- Creates require_min_role_v1 as an internal helper for use by future
-- SECURITY DEFINER RPCs only. NOT executable by anon or authenticated.

CREATE OR REPLACE FUNCTION public.require_min_role_v1(
  p_min public.tenant_role
)
RETURNS void
LANGUAGE plpgsql
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_user_id   uuid;
  v_role      public.tenant_role;
BEGIN
  v_tenant_id := public.current_tenant_id();
  v_user_id   := auth.uid();

  IF v_tenant_id IS NULL OR v_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT role INTO v_role
  FROM public.tenant_memberships
  WHERE tenant_id = v_tenant_id
    AND user_id   = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  -- Enum ordering: owner > admin > member
  IF v_role < p_min THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
END;
$fn$;

-- Privilege firewall: internal helper only.
-- Revoke from PUBLIC first, then explicit app roles.
REVOKE EXECUTE ON FUNCTION public.require_min_role_v1(public.tenant_role) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.require_min_role_v1(public.tenant_role) FROM anon;
REVOKE EXECUTE ON FUNCTION public.require_min_role_v1(public.tenant_role) FROM authenticated;