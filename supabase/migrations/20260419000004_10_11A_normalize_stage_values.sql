-- 10.11A Corrective: Normalize stage values in health color helper and update_deal_v1
-- Prior migrations used capitalized/spaced stage strings ('New', 'Closed / Dead' etc.)
-- Migration 20260419000001 locked canonical snake_case stages.
-- This corrective updates all affected functions to match.
-- DEAL_IMMUTABLE replaced with CONFLICT (locked envelope code enum).

-- 1. Update get_deal_health_color to use canonical snake_case stage values
CREATE OR REPLACE FUNCTION public.get_deal_health_color(
  p_stage      TEXT,
  p_updated_at TIMESTAMPTZ
)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $fn$
  SELECT CASE
    WHEN p_updated_at IS NULL        THEN 'yellow'
    WHEN p_stage = 'new'            AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 3         THEN 'red'
    WHEN p_stage = 'new'            AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 3 * 0.7   THEN 'yellow'
    WHEN p_stage = 'analyzing'      AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7         THEN 'red'
    WHEN p_stage = 'analyzing'      AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7 * 0.7   THEN 'yellow'
    WHEN p_stage = 'offer_sent'     AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 5         THEN 'red'
    WHEN p_stage = 'offer_sent'     AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 5 * 0.7   THEN 'yellow'
    WHEN p_stage = 'under_contract' AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 14        THEN 'red'
    WHEN p_stage = 'under_contract' AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 14 * 0.7  THEN 'yellow'
    WHEN p_stage = 'dispo'          AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7         THEN 'red'
    WHEN p_stage = 'dispo'          AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7 * 0.7   THEN 'yellow'
    WHEN p_stage = 'tc'             AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 14        THEN 'red'
    WHEN p_stage = 'tc'             AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 14 * 0.7  THEN 'yellow'
    ELSE 'green'
  END
$fn$;

REVOKE ALL ON FUNCTION public.get_deal_health_color(TEXT, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;

-- 2. Update update_deal_v1 to use canonical stage values and valid envelope code
CREATE OR REPLACE FUNCTION public.update_deal_v1(
  p_id                   uuid,
  p_expected_row_version bigint,
  p_calc_version         integer DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant       uuid;
  v_stage        text;
  v_rows_updated int;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', json_build_object())
    );
  END IF;

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_id AND tenant_id = v_tenant;

  IF v_stage IN ('closed', 'dead') THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal is in a terminal stage and cannot be modified', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals
  SET
    row_version  = row_version + 1,
    calc_version = COALESCE(p_calc_version, calc_version)
  WHERE id = p_id
    AND tenant_id = v_tenant
    AND row_version = p_expected_row_version;

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Row version mismatch or deal not found for this tenant', 'fields', json_build_object())
    );
  END IF;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('id', p_id),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.update_deal_v1(uuid, bigint, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_deal_v1(uuid, bigint, integer) TO authenticated;