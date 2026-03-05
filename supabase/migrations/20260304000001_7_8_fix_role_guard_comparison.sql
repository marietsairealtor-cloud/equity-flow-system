-- 7.8 Fix: require_min_role_v1 comparison was inverted.
-- PostgreSQL enum order: owner(0) < admin(1) < member(2)
-- More privileged = smaller enum position.
-- FAIL when v_role > p_min (caller is less privileged).

CREATE OR REPLACE FUNCTION public.require_min_role_v1(p_min public.tenant_role)
RETURNS void
LANGUAGE plpgsql
SET search_path TO 'public'
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
  -- Enum ordering: owner(0) < admin(1) < member(2)
  -- More privileged = smaller. Fail if caller is less privileged (larger).
  IF v_role > p_min THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
END;
$fn$;
