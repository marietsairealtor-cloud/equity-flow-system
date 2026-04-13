-- 10.8.11O1: Archived Workspace Restore Implementation
-- Adds restore_workspace_v1() RPC -- owner-only, requires active subscription.
-- Clears archived_at and subscription_lapsed_at on successful restore.

CREATE FUNCTION public.restore_workspace_v1()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant  uuid;
  v_user    uuid;
  v_role    public.tenant_role;
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

  -- Resolve caller role
  SELECT tm.role INTO v_role
  FROM public.tenant_memberships tm
  WHERE tm.tenant_id = v_tenant
    AND tm.user_id   = v_user;

  IF NOT FOUND OR v_role != 'owner' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'Only the workspace owner can restore an archived workspace',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Verify workspace is archived
  IF NOT EXISTS (
    SELECT 1 FROM public.tenants t
    WHERE t.id = v_tenant
      AND t.archived_at IS NOT NULL
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'CONFLICT',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'Workspace is not archived',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Verify subscription is active again
  IF NOT EXISTS (
    SELECT 1 FROM public.tenant_subscriptions ts
    WHERE ts.tenant_id = v_tenant
      AND ts.status IN ('active', 'expiring')
      AND ts.current_period_end > now()
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'CONFLICT',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'An active subscription is required to restore this workspace',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Restore: clear archived_at and subscription_lapsed_at
  UPDATE public.tenants
  SET archived_at            = NULL,
      subscription_lapsed_at = NULL
  WHERE id = v_tenant;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'tenant_id', v_tenant,
      'restored',  true
    ),
    'error', null
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'ok',   false,
    'code', 'INTERNAL',
    'data', json_build_object(),
    'error', json_build_object(
      'message', 'Internal restore error',
      'fields',  json_build_object()
    )
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.restore_workspace_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.restore_workspace_v1() TO authenticated;