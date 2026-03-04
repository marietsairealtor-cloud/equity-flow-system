-- 7.4 Entitlement truth — get_user_entitlements_v1()
-- Server-side source of truth for user entitlement.
-- Entitlement = active tenant membership exists.
-- GUARDRAILS §17: entitlements sourced only from this RPC.

CREATE FUNCTION public.get_user_entitlements_v1()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_tenant  uuid;
  v_user    uuid;
  v_role    public.tenant_role;
  v_member  boolean;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'No tenant or user context', 'fields', json_build_object())
    );
  END IF;

  SELECT tm.role INTO v_role
  FROM public.tenant_memberships tm
  WHERE tm.tenant_id = v_tenant
    AND tm.user_id = v_user;

  v_member := FOUND;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'tenant_id', v_tenant,
      'user_id',   v_user,
      'is_member', v_member,
      'role',      v_role,
      'entitled',  v_member
    ),
    'error', null
  );
END;
$fn$;

-- Privilege firewall: only authenticated can call
GRANT EXECUTE ON FUNCTION public.get_user_entitlements_v1() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.get_user_entitlements_v1() FROM anon;
