-- 10.8.11M: Entitlement RPC Access + Retention State Extension
-- Extends get_user_entitlements_v1 with app_mode, can_manage_billing,
-- renew_route, retention_deadline, days_until_deletion
-- No schema changes. No new columns. No new RPCs.

CREATE OR REPLACE FUNCTION public.get_user_entitlements_v1()
RETURNS json
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant              uuid;
  v_user                uuid;
  v_role                public.tenant_role;
  v_member              boolean;
  v_raw_status          text;
  v_sub_status          text;
  v_sub_days_remaining  integer;
  v_period_end          timestamptz;
  v_expiring_threshold  integer := 5;
  v_grace_days          integer := 60;
  v_app_mode            text;
  v_can_manage_billing  boolean;
  v_renew_route         text;
  v_retention_deadline  timestamptz;
  v_days_until_deletion integer;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  json_build_object(),
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

  -- No membership -- return early with existing no-workspace behavior
  IF NOT v_member THEN
    RETURN json_build_object(
      'ok',   true,
      'code', 'OK',
      'data', json_build_object(
        'tenant_id',                   v_tenant,
        'user_id',                     v_user,
        'is_member',                   false,
        'role',                        null,
        'entitled',                    false,
        'subscription_status',         'none',
        'subscription_days_remaining', null,
        'app_mode',                    'normal',
        'can_manage_billing',          false,
        'renew_route',                 'none',
        'retention_deadline',          null,
        'days_until_deletion',         null
      ),
      'error', null
    );
  END IF;

  -- Member confirmed -- resolve subscription
  SELECT ts.status, ts.current_period_end
  INTO v_raw_status, v_period_end
  FROM public.tenant_subscriptions ts
  WHERE ts.tenant_id = v_tenant;

  IF NOT FOUND THEN
    -- Membership exists but no subscription record
    v_sub_status          := 'none';
    v_sub_days_remaining  := null;
    v_app_mode            := 'read_only_expired';
    v_can_manage_billing  := (v_role = 'owner');
    v_renew_route         := CASE WHEN v_role = 'owner' THEN 'billing' ELSE 'none' END;
    v_retention_deadline  := null;
    v_days_until_deletion := null;

  ELSIF v_raw_status = 'canceled' OR v_period_end <= now() THEN
    -- Expired -- check grace window from current_period_end
    v_sub_status         := 'expired';
    v_sub_days_remaining := null;
    v_retention_deadline := v_period_end + (v_grace_days || ' days')::interval;

    IF now() <= v_retention_deadline THEN
      -- Within 60-day grace window
      v_app_mode           := 'read_only_expired';
      v_can_manage_billing := (v_role = 'owner');
      v_renew_route        := CASE WHEN v_role = 'owner' THEN 'billing' ELSE 'none' END;
      v_days_until_deletion := null;
    ELSE
      -- Beyond 60-day grace window -- archived
      v_app_mode            := 'archived_unreachable';
      v_can_manage_billing  := false;
      v_renew_route         := 'none';
      v_days_until_deletion := GREATEST(0,
        EXTRACT(DAY FROM (v_retention_deadline + interval '6 months' - now()))::integer
      );
    END IF;

  ELSIF v_raw_status IN ('active', 'expiring') THEN
    v_sub_days_remaining := GREATEST(0, EXTRACT(DAY FROM (v_period_end - now()))::integer);
    IF v_sub_days_remaining <= v_expiring_threshold THEN
      v_sub_status := 'expiring';
    ELSE
      v_sub_status         := 'active';
      v_sub_days_remaining := null;
    END IF;
    v_app_mode            := 'normal';
    v_can_manage_billing  := (v_role = 'owner');
    v_renew_route         := CASE WHEN v_role = 'owner' THEN 'billing' ELSE 'none' END;
    v_retention_deadline  := null;
    v_days_until_deletion := null;

  ELSE
    -- Fallback
    v_sub_status          := 'none';
    v_sub_days_remaining  := null;
    v_app_mode            := 'normal';
    v_can_manage_billing  := (v_role = 'owner');
    v_renew_route         := CASE WHEN v_role = 'owner' THEN 'billing' ELSE 'none' END;
    v_retention_deadline  := null;
    v_days_until_deletion := null;
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'tenant_id',                   v_tenant,
      'user_id',                     v_user,
      'is_member',                   v_member,
      'role',                        v_role,
      'entitled',                    v_member,
      'subscription_status',         v_sub_status,
      'subscription_days_remaining', v_sub_days_remaining,
      'app_mode',                    v_app_mode,
      'can_manage_billing',          v_can_manage_billing,
      'renew_route',                 v_renew_route,
      'retention_deadline',          v_retention_deadline,
      'days_until_deletion',         v_days_until_deletion
    ),
    'error', null
  );
END;
$fn$;