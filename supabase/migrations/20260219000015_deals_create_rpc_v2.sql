-- 20260219000015_deals_create_rpc_v2.sql
-- 6.6: Replace create_deal_v1 to handle circular FK.
-- Single transaction: INSERT deal (null snapshot) → INSERT deal_inputs → UPDATE deal snapshot.
-- DEFERRABLE FK allows null snapshot_id until transaction commits.
-- SECURITY DEFINER + tenant binding per CONTRACTS.md S3, S7, S8, S12.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No double-dollar tags.

DROP FUNCTION IF EXISTS public.create_deal_v1(uuid, bigint, int);

CREATE FUNCTION public.create_deal_v1(
  p_id              uuid,
  p_calc_version    int     DEFAULT 1,
  p_assumptions     jsonb   DEFAULT '{}'::jsonb
)
RETURNS json
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant      uuid;
  v_snapshot_id uuid;
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

  -- Generate snapshot id
  v_snapshot_id := gen_random_uuid();

  -- Step 1: Insert deal with snapshot id up-front (FK is DEFERRABLE; deal_inputs row may be inserted later in txn)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES (p_id, v_tenant, 1, p_calc_version, v_snapshot_id);
-- Step 2: Insert deal_inputs snapshot (tenant-match trigger fires here)
  INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
  VALUES (v_snapshot_id, v_tenant, p_id, p_calc_version, 1, p_assumptions);

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'id',                    p_id,
      'tenant_id',             v_tenant,
      'assumptions_snapshot_id', v_snapshot_id
    ),
    'error', null
  );
EXCEPTION WHEN unique_violation THEN
  RETURN json_build_object(
    'ok',    false,
    'code',  'CONFLICT',
    'data',  null,
    'error', json_build_object('message', 'Deal already exists', 'fields', json_build_object())
  );
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.create_deal_v1(uuid, int, jsonb) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.create_deal_v1(uuid, int, jsonb) FROM anon;
