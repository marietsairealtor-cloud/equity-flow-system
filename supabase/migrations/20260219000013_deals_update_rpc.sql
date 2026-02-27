-- 20260219000013_deals_update_rpc.sql
-- 6.6: update_deal_v1 — optimistic concurrency via row_version.
-- WHERE row_version = p_expected_row_version enforces concurrency contract.
-- Returns CONFLICT if row_version mismatch (stale update blocked).
-- SECURITY DEFINER + tenant binding per CONTRACTS.md S3, S7, S8, S12.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No double-dollar tags.

CREATE OR REPLACE FUNCTION public.update_deal_v1(
  p_id                  uuid,
  p_expected_row_version bigint,
  p_calc_version        int DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant      uuid;
  v_rows_updated int;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals
  SET
    row_version  = row_version + 1,
    calc_version = COALESCE(p_calc_version, calc_version)
  WHERE id         = p_id
    AND tenant_id  = v_tenant
    AND row_version = p_expected_row_version;

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    -- Either row does not exist for this tenant, or row_version mismatch
    RETURN json_build_object(
      'ok',    false,
      'code',  'CONFLICT',
      'data',  null,
      'error', json_build_object('message', 'Row version mismatch or deal not found', 'fields', json_build_object())
    );
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('id', p_id, 'row_version', p_expected_row_version + 1),
    'error', null
  );
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.update_deal_v1(uuid, bigint, int) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.update_deal_v1(uuid, bigint, int) FROM anon;
