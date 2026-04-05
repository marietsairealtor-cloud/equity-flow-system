-- 20260403000002_10_8_11E_workspace_settings_read.sql

DROP FUNCTION IF EXISTS public.get_workspace_settings_v1();

CREATE FUNCTION public.get_workspace_settings_v1()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_role public.tenant_role;
  v_slug text;
BEGIN
  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT tm.role
  INTO v_role
  FROM public.tenant_memberships tm
  WHERE tm.tenant_id = v_tenant_id
    AND tm.user_id = auth.uid();

  IF v_role IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not a member of this tenant', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT ts.slug
  INTO v_slug
  FROM public.tenant_slugs ts
  WHERE ts.tenant_id = v_tenant_id
  LIMIT 1;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'tenant_id', v_tenant_id,
      'workspace_name', null,
      'slug', v_slug,
      'role', v_role,
      'country', null,
      'currency', null,
      'measurement_unit', null
    ),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_workspace_settings_v1() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_workspace_settings_v1() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_workspace_settings_v1() TO authenticated;