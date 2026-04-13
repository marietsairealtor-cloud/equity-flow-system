-- 10.8.11O: Expired Workspace Retention + Archive Lifecycle Automation
-- Adds subscription_lapsed_at and archived_at to public.tenants.
-- Adds internal RPC process_workspace_retention_v1() called by Edge Function only.
-- No public-facing RPC. No WeWeb access.

-- Step 1: Add lifecycle anchor columns to tenants
ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS subscription_lapsed_at timestamptz DEFAULT NULL;

ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS archived_at timestamptz DEFAULT NULL;

-- Step 2: Internal retention processor
-- Called daily by retention-lifecycle Edge Function (service_role only).
-- Performs in order:
--   A. Recovery: clear lapsed state when active subscription has returned
--   B. Lapse detection: set anchor for membership + no subscription
--   C. Archive: transition eligible expired workspaces
--   D. Hard delete: explicit ordered delete after 6-month archive window

CREATE FUNCTION public.process_workspace_retention_v1()
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
  -- Clear subscription_lapsed_at for workspaces that are not yet archived
  -- and now have a valid active subscription again.
  -- This is the "renew within 60-day window" auto-restore path.
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
  -- Set subscription_lapsed_at on first detection for workspaces that have
  -- members but no subscription row. Anchor is used for day-61 archive.
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

  -- Case 1: subscription-bearing expired workspaces.
  -- Anchor = current_period_end. Archive when anchor > 60 days ago.
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
    SET archived_at = now()
    WHERE id = v_tenant.id;

    v_archived_count := v_archived_count + 1;
  END LOOP;

  -- Case 2: membership + no subscription workspaces.
  -- Anchor = subscription_lapsed_at. Archive when anchor > 60 days ago.
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
    SET archived_at = now()
    WHERE id = v_tenant.id;

    v_archived_count := v_archived_count + 1;
  END LOOP;

  -- === Step D: Hard delete ===
  -- Explicit delete order for NO ACTION FK tables first,
  -- then delete tenants row (CASCADE handles remaining children).
  FOR v_tenant IN
    SELECT t.id
    FROM public.tenants t
    WHERE t.archived_at IS NOT NULL
      AND t.archived_at <= v_delete_cutoff
  LOOP
    -- NO ACTION FK tables: must delete explicitly
    DELETE FROM public.activity_log
    WHERE tenant_id = v_tenant.id;

    DELETE FROM public.tenant_memberships
    WHERE tenant_id = v_tenant.id;

    -- Tenants row delete. CASCADE handles:
    -- deal_reminders, deal_tc, deal_tc_checklist, draft_deals,
    -- tenant_farm_areas, tenant_invites, tenant_slugs,
    -- tenant_subscriptions.
    -- user_profiles.current_tenant_id SET NULL (proven FK rule).
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

-- Restrict to service_role only
REVOKE ALL ON FUNCTION public.process_workspace_retention_v1() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.process_workspace_retention_v1() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.process_workspace_retention_v1() TO service_role;