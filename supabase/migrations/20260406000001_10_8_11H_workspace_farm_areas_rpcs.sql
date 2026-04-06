-- 20260406000001_10_8_11H_workspace_farm_areas_rpcs.sql
-- Corrective migration: align all three farm area RPCs with current contracts
-- Fixes: role order, role level on list, jsonb envelope, data object never null,
-- output column restriction, parameter naming consistency.

DROP FUNCTION IF EXISTS public.list_farm_areas_v1();
DROP FUNCTION IF EXISTS public.create_farm_area_v1(text);
DROP FUNCTION IF EXISTS public.delete_farm_area_v1(uuid);

CREATE FUNCTION public.list_farm_areas_v1()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_items jsonb;
BEGIN
  PERFORM public.require_min_role_v1('member');

  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'farm_area_id', fa.id,
    'area_name', fa.area_name,
    'created_at', fa.created_at
  ) ORDER BY fa.area_name ASC)
  INTO v_items
  FROM public.tenant_farm_areas fa
  WHERE fa.tenant_id = v_tenant_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'items', COALESCE(v_items, '[]'::jsonb)
    ),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.list_farm_areas_v1() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.list_farm_areas_v1() FROM anon;
GRANT EXECUTE ON FUNCTION public.list_farm_areas_v1() TO authenticated;

CREATE FUNCTION public.create_farm_area_v1(
  p_area_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_new_id uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_area_name IS NULL OR btrim(p_area_name) = '' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Area name is required', 'fields', jsonb_build_object('area_name', 'Must not be blank'))
    );
  END IF;

  INSERT INTO public.tenant_farm_areas (tenant_id, area_name)
  VALUES (v_tenant_id, btrim(p_area_name))
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'farm_area_id', v_new_id,
      'area_name', btrim(p_area_name)
    ),
    'error', null
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'CONFLICT',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Farm area already exists', 'fields', jsonb_build_object('area_name', 'Already exists in this workspace'))
    );
END;
$fn$;

REVOKE ALL ON FUNCTION public.create_farm_area_v1(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_farm_area_v1(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_farm_area_v1(text) TO authenticated;

CREATE FUNCTION public.delete_farm_area_v1(
  p_farm_area_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_farm_area_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'farm_area_id is required', 'fields', jsonb_build_object('farm_area_id', 'Must not be null'))
    );
  END IF;

  DELETE FROM public.tenant_farm_areas
  WHERE id = p_farm_area_id
    AND tenant_id = v_tenant_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Farm area not found', 'fields', '{}'::jsonb)
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'farm_area_id', p_farm_area_id
    ),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.delete_farm_area_v1(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.delete_farm_area_v1(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_farm_area_v1(uuid) TO authenticated;
