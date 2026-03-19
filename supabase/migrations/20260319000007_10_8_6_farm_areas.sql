-- 10.8.6: Farm Areas Table
-- Creates tenant_farm_areas lookup table for geographic targeting.
-- Adds farm_area_id FK to public.deals (ON DELETE SET NULL).
-- CRUD + list RPCs: create_farm_area_v1, delete_farm_area_v1, list_farm_areas_v1.
-- All RPCs role-gated to admin+ via require_min_role_v1.

CREATE TABLE public.tenant_farm_areas (
  id          UUID        NOT NULL DEFAULT gen_random_uuid(),
  tenant_id   UUID        NOT NULL,
  row_version BIGINT      NOT NULL DEFAULT 1,
  area_name   TEXT        NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT tenant_farm_areas_pkey PRIMARY KEY (id),
  CONSTRAINT tenant_farm_areas_tenant_area_unique UNIQUE (tenant_id, area_name),
  CONSTRAINT tenant_farm_areas_tenant_id_fkey FOREIGN KEY (tenant_id)
    REFERENCES public.tenants(id) ON DELETE CASCADE
);

ALTER TABLE public.tenant_farm_areas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant_farm_areas_select_own" ON public.tenant_farm_areas
  FOR SELECT TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE POLICY "tenant_farm_areas_insert_own" ON public.tenant_farm_areas
  FOR INSERT TO authenticated
  WITH CHECK (tenant_id = public.current_tenant_id());

CREATE POLICY "tenant_farm_areas_update_own" ON public.tenant_farm_areas
  FOR UPDATE TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE POLICY "tenant_farm_areas_delete_own" ON public.tenant_farm_areas
  FOR DELETE TO authenticated
  USING (tenant_id = public.current_tenant_id());

REVOKE ALL ON public.tenant_farm_areas FROM anon, authenticated;

-- Add farm_area_id FK to deals (nullable, ON DELETE SET NULL)
ALTER TABLE public.deals
  ADD COLUMN farm_area_id UUID,
  ADD CONSTRAINT deals_farm_area_id_fkey
    FOREIGN KEY (farm_area_id) REFERENCES public.tenant_farm_areas(id) ON DELETE SET NULL;

-- list_farm_areas_v1: returns all farm areas for caller tenant
CREATE FUNCTION public.list_farm_areas_v1()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant UUID;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  PERFORM public.require_min_role_v1('admin');

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'items', COALESCE(
        (
          SELECT json_agg(
            json_build_object(
              'id',          fa.id,
              'tenant_id',   fa.tenant_id,
              'area_name',   fa.area_name,
              'row_version', fa.row_version,
              'created_at',  fa.created_at
            )
            ORDER BY fa.area_name
          )
          FROM public.tenant_farm_areas fa
          WHERE fa.tenant_id = v_tenant
        ),
        '[]'::json
      )
    ),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.list_farm_areas_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_farm_areas_v1() TO authenticated;

-- create_farm_area_v1: creates a new farm area for caller tenant
CREATE FUNCTION public.create_farm_area_v1(
  p_area_name TEXT
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant UUID;
  v_id     UUID;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  PERFORM public.require_min_role_v1('admin');

  IF p_area_name IS NULL OR trim(p_area_name) = '' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'area_name is required', 'fields', json_build_object('area_name', 'required'))
    );
  END IF;

  INSERT INTO public.tenant_farm_areas (tenant_id, area_name)
  VALUES (v_tenant, trim(p_area_name))
  RETURNING id INTO v_id;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('id', v_id),
    'error', null
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', null,
      'error', json_build_object('message', 'Farm area name already exists for this tenant', 'fields', json_build_object('area_name', 'conflict'))
    );
END;
$fn$;

REVOKE ALL ON FUNCTION public.create_farm_area_v1(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_farm_area_v1(TEXT) TO authenticated;

-- delete_farm_area_v1: deletes a farm area for caller tenant
CREATE FUNCTION public.delete_farm_area_v1(
  p_id UUID
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant      UUID;
  v_rows_deleted INT;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  PERFORM public.require_min_role_v1('admin');

  DELETE FROM public.tenant_farm_areas
  WHERE id = p_id AND tenant_id = v_tenant;

  GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;

  IF v_rows_deleted = 0 THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Farm area not found', 'fields', json_build_object())
    );
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('id', p_id),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.delete_farm_area_v1(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_farm_area_v1(UUID) TO authenticated;