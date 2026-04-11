-- 10.8.11K: Subscription Status Consistency corrective fix
-- Removes dead RPC branches for raw Stripe statuses that cannot exist in DB
-- tenant_subscriptions.status constraint: active | expiring | expired | canceled
-- Webhook normalizes Stripe raw status before writing to DB
-- RPC reads only stored DB statuses

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

  -- Resolve subscription status
  SELECT ts.status, ts.current_period_end
  INTO v_raw_status, v_period_end
  FROM public.tenant_subscriptions ts
  WHERE ts.tenant_id = v_tenant;

  IF NOT FOUND THEN
    v_sub_status         := 'none';
    v_sub_days_remaining := null;

  ELSIF v_raw_status = 'canceled' OR v_period_end <= now() THEN
    v_sub_status         := 'expired';
    v_sub_days_remaining := null;

  ELSIF v_raw_status IN ('active', 'expiring') THEN
    v_sub_days_remaining := GREATEST(0, EXTRACT(DAY FROM (v_period_end - now()))::integer);
    IF v_sub_days_remaining <= v_expiring_threshold THEN
      v_sub_status         := 'expiring';
    ELSE
      v_sub_status         := 'active';
      v_sub_days_remaining := null;
    END IF;

  ELSE
    v_sub_status         := 'none';
    v_sub_days_remaining := null;
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
      'subscription_days_remaining', v_sub_days_remaining
    ),
    'error', null
  );
END;
$fn$;