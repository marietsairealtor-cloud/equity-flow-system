-- 10.8.11O3: Archived Workspace Restore Targeting Corrective Fix
-- Adds restore_token to public.tenants (set only when workspace is archived).
-- Updates process_workspace_retention_v1() to set restore_token on archive.
-- Drops O1 zero-parameter restore_workspace_v1().
-- Adds list_archived_workspaces_v1() -- returns archived workspaces owned by caller.
-- Adds restore_workspace_v1(p_restore_token uuid) -- resolves token internally.

-- Step 1: Add restore_token column to tenants with unique constraint
ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS restore_token uuid DEFAULT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS tenants_restore_token_unique
  ON public.tenants (restore_token)
  WHERE restore_token IS NOT NULL;

-- Step 2: Drop O1 zero-parameter restore RPC (superseded by O3)
DROP FUNCTION IF EXISTS public.restore_workspace_v1();

-- Step 3: Update process_workspace_retention_v1() to set restore_token on archive
CREATE OR REPLACE FUNCTION public.process_workspace_retention_v1()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_grace_days     integer     := 60;
  v_archive_months integer     := 6;
  v_archive_cutoff timestamptz := now() - (v_grace_days    || ' days')::interval;
  v_delete_cutoff  timestamptz := now() - (v_archive_months || ' months')::interval;
  v_recovery_count integer     := 0;
  v_lapsed_count   integer     := 0;
  v_archived_count integer     := 0;
  v_deleted_count  integer     := 0;
  v_tenant         RECORD;
BEGIN

  -- === Step A: Recovery ===
  UPDATE public.tenants t
  SET subscription_lapsed_at = NULL
  WHERE t.archived_at IS NULL
    AND t.subscription_lapsed_at IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.tenant_subscriptions ts
      WHERE ts.tenant_id = t.id
        AND ts.status IN ('active', 'expiring')
        AND ts.current_period_end > now()
    );

  GET DIAGNOSTICS v_recovery_count = ROW_COUNT;

  -- === Step B: Lapse detection ===
  FOR v_tenant IN
    SELECT t.id
    FROM public.tenants t
    WHERE t.archived_at IS NULL
      AND t.subscription_lapsed_at IS NULL
      AND EXISTS (
        SELECT 1 FROM public.tenant_memberships tm
        WHERE tm.tenant_id = t.id
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.tenant_subscriptions ts
        WHERE ts.tenant_id = t.id
      )
  LOOP
    UPDATE public.tenants
    SET subscription_lapsed_at = now()
    WHERE id = v_tenant.id;

    v_lapsed_count := v_lapsed_count + 1;
  END LOOP;

  -- === Step C: Archive ===

  -- Case 1: subscription-bearing expired workspaces
  FOR v_tenant IN
    SELECT t.id
    FROM public.tenants t
    JOIN public.tenant_subscriptions ts ON ts.tenant_id = t.id
    WHERE t.archived_at IS NULL
      AND (
        ts.status IN ('canceled', 'expired')
        OR ts.current_period_end <= now()
      )
      AND ts.current_period_end <= v_archive_cutoff
  LOOP
    UPDATE public.tenants
    SET archived_at   = now(),
        restore_token = gen_random_uuid()
    WHERE id = v_tenant.id;

    v_archived_count := v_archived_count + 1;
  END LOOP;

  -- Case 2: membership + no subscription workspaces
  FOR v_tenant IN
    SELECT t.id
    FROM public.tenants t
    WHERE t.archived_at IS NULL
      AND t.subscription_lapsed_at IS NOT NULL
      AND t.subscription_lapsed_at <= v_archive_cutoff
      AND NOT EXISTS (
        SELECT 1 FROM public.tenant_subscriptions ts
        WHERE ts.tenant_id = t.id
      )
  LOOP
    UPDATE public.tenants
    SET archived_at   = now(),
        restore_token = gen_random_uuid()
    WHERE id = v_tenant.id;

    v_archived_count := v_archived_count + 1;
  END LOOP;

  -- === Step D: Hard delete ===
  FOR v_tenant IN
    SELECT t.id
    FROM public.tenants t
    WHERE t.archived_at IS NOT NULL
      AND t.archived_at <= v_delete_cutoff
  LOOP
    DELETE FROM public.activity_log
    WHERE tenant_id = v_tenant.id;

    DELETE FROM public.tenant_memberships
    WHERE tenant_id = v_tenant.id;

    DELETE FROM public.tenants
    WHERE id = v_tenant.id;

    v_deleted_count := v_deleted_count + 1;
  END LOOP;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'recovery_count', v_recovery_count,
      'lapsed_count',   v_lapsed_count,
      'archived_count', v_archived_count,
      'deleted_count',  v_deleted_count,
      'run_at',         now()
    ),
    'error', null
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'ok',   false,
    'code', 'INTERNAL',
    'data', json_build_object(),
    'error', json_build_object(
      'message', 'Internal retention processing error',
      'fields',  json_build_object()
    )
  );
END;
$fn$;

-- Step 4: list_archived_workspaces_v1()
-- Returns archived workspaces owned by the authenticated caller.
-- Includes restore_token for use with restore_workspace_v1().

CREATE FUNCTION public.list_archived_workspaces_v1()
RETURNS json
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user uuid;
  v_items json;
BEGIN
  v_user := auth.uid();

  IF v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'Authentication required',
        'fields',  json_build_object()
      )
    );
  END IF;

  SELECT json_agg(row_to_json(r)) INTO v_items
  FROM (
    SELECT
      t.name          AS workspace_name,
      tsl.slug,
      t.archived_at,
      t.restore_token,
      tm.role,
      ts.status       AS subscription_status,
      ts.current_period_end
    FROM public.tenants t
    JOIN public.tenant_memberships tm
      ON tm.tenant_id = t.id
      AND tm.user_id  = v_user
      AND tm.role     = 'owner'
    LEFT JOIN public.tenant_slugs tsl
      ON tsl.tenant_id = t.id
    LEFT JOIN public.tenant_subscriptions ts
      ON ts.tenant_id = t.id
    WHERE t.archived_at IS NOT NULL
    ORDER BY t.archived_at DESC
  ) r;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'items', COALESCE(v_items, '[]'::json)
    ),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.list_archived_workspaces_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_archived_workspaces_v1() TO authenticated;

-- Step 5: restore_workspace_v1(p_restore_token uuid)
-- Resolves restore_token to tenant internally.
-- Verifies: token exists, workspace archived, caller is owner, subscription active.
-- On success: clears archived_at, subscription_lapsed_at, restore_token.

CREATE FUNCTION public.restore_workspace_v1(p_restore_token uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user      uuid;
  v_tenant_id uuid;
  v_role      public.tenant_role;
BEGIN
  v_user := auth.uid();

  IF v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'Authentication required',
        'fields',  json_build_object()
      )
    );
  END IF;

  IF p_restore_token IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'p_restore_token is required',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Resolve restore_token to tenant internally
  SELECT t.id INTO v_tenant_id
  FROM public.tenants t
  WHERE t.restore_token = p_restore_token
    AND t.archived_at IS NOT NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'Workspace not found or not eligible for restore',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Verify caller is owner of resolved tenant
  SELECT tm.role INTO v_role
  FROM public.tenant_memberships tm
  WHERE tm.tenant_id = v_tenant_id
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

  -- Verify subscription is active again
  IF NOT EXISTS (
    SELECT 1 FROM public.tenant_subscriptions ts
    WHERE ts.tenant_id = v_tenant_id
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

  -- Restore: clear archived_at, subscription_lapsed_at, restore_token
  UPDATE public.tenants
  SET archived_at            = NULL,
      subscription_lapsed_at = NULL,
      restore_token          = NULL
  WHERE id = v_tenant_id;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'tenant_id', v_tenant_id,
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

REVOKE ALL ON FUNCTION public.restore_workspace_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.restore_workspace_v1(uuid) TO authenticated;