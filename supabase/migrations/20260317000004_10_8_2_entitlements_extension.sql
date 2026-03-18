-- 20260317000004_10_8_2_entitlements_extension.sql
-- Build Route 10.8.2: Entitlements Extension (Subscription Status)
-- Extends get_user_entitlements_v1 to include subscription_status and
-- subscription_days_remaining. DROP + CREATE per CONTRACTS §2 (return shape change).

-- ============================================================
-- DROP existing function (CONTRACTS §2 -- return shape change)
-- ============================================================
DROP FUNCTION IF EXISTS public.get_user_entitlements_v1();

-- ============================================================
-- CREATE new function with extended return shape
-- ============================================================
CREATE FUNCTION public.get_user_entitlements_v1()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant              uuid;
  v_user                uuid;
  v_role                public.tenant_role;
  v_member              boolean;
  v_sub_status          text;
  v_sub_days_remaining  integer;
  v_period_end          timestamptz;
  v_expiring_threshold  integer := 5;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object(
        'message', 'No tenant or user context',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Resolve tenant membership
  SELECT tm.role INTO v_role
  FROM public.tenant_memberships tm
  WHERE tm.tenant_id = v_tenant
    AND tm.user_id   = v_user;

  v_member := FOUND;

  -- Resolve subscription status (server-side computation)
  SELECT ts.status, ts.current_period_end
  INTO v_sub_status, v_period_end
  FROM public.tenant_subscriptions ts
  WHERE ts.tenant_id = v_tenant;

  IF NOT FOUND THEN
    -- No subscription record
    v_sub_status         := 'none';
    v_sub_days_remaining := null;
  ELSIF v_sub_status = 'canceled' OR v_period_end <= now() THEN
    -- Canceled or past period end -- expired
    v_sub_status         := 'expired';
    v_sub_days_remaining := EXTRACT(DAY FROM (v_period_end - now()))::integer;
  ELSIF v_sub_status IN ('active', 'expiring') THEN
    -- Compute days remaining
    v_sub_days_remaining := GREATEST(0, EXTRACT(DAY FROM (v_period_end - now()))::integer);
    -- Expiring threshold: active AND <=5 days remain
    IF v_sub_days_remaining <= v_expiring_threshold THEN
      v_sub_status := 'expiring';
    ELSE
      v_sub_status := 'active';
    END IF;
  ELSE
    -- Fallback for any other stored status
    v_sub_status         := 'none';
    v_sub_days_remaining := null;
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'tenant_id',                v_tenant,
      'user_id',                  v_user,
      'is_member',                v_member,
      'role',                     v_role,
      'entitled',                 v_member,
      'subscription_status',      v_sub_status,
      'subscription_days_remaining', v_sub_days_remaining
    ),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.get_user_entitlements_v1() OWNER TO postgres;

-- Restore grants (DROP removed them)
REVOKE ALL ON FUNCTION public.get_user_entitlements_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_entitlements_v1() TO authenticated;
