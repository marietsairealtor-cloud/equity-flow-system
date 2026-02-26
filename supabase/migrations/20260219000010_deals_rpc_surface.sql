-- 20260219000010_deals_rpc_surface.sql
-- 6.3: Minimal allowlisted RPC surface for deals.
-- SECURITY DEFINER + tenant binding per CONTRACTS.md S3, S7, S12.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No double-dollar tags.

-- list_deals_v1: read surface for authenticated
CREATE OR REPLACE FUNCTION public.list_deals_v1(
  p_limit int DEFAULT 25
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
  v_items json;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF p_limit IS NULL OR p_limit < 1 THEN p_limit := 25; END IF;
  IF p_limit > 100 THEN p_limit := 100; END IF;

  SELECT json_agg(row_to_json(d))
  INTO v_items
  FROM (
    SELECT id, tenant_id, row_version, calc_version
    FROM public.deals
    WHERE tenant_id = v_tenant
    ORDER BY id
    LIMIT p_limit
  ) d;

  RETURN json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object('items', COALESCE(v_items, '[]'::json), 'next_cursor', null),
    'error', null
  );
END;
$fn$;

-- create_deal_v1: write surface for authenticated
CREATE OR REPLACE FUNCTION public.create_deal_v1(
  p_id uuid,
  p_row_version bigint DEFAULT 1,
  p_calc_version int DEFAULT 1
)
RETURNS json
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  INSERT INTO public.deals (id, tenant_id, row_version, calc_version)
  VALUES (p_id, v_tenant, p_row_version, p_calc_version);

  RETURN json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object('id', p_id, 'tenant_id', v_tenant),
    'error', null
  );
EXCEPTION WHEN unique_violation THEN
  RETURN json_build_object(
    'ok', false,
    'code', 'CONFLICT',
    'data', null,
    'error', json_build_object('message', 'Deal already exists', 'fields', json_build_object())
  );
END;
$fn$;



