-- 10.9: MAO Calculator -- Server-Computed MAO in create_deal_v1
-- Option A: extract raw calc inputs from p_assumptions, compute MAO server-side,
-- overwrite assumptions.mao with backend-computed value before storing.
-- Signature unchanged: (p_id uuid, p_calc_version int, p_assumptions jsonb)
-- require_min_role_v1('member') is first executable statement per privileged RPC contract.
-- Null tenant context mapped to NOT_AUTHORIZED via guarded exception wrapper.

DROP FUNCTION IF EXISTS public.create_deal_v1(uuid, int, jsonb);

CREATE FUNCTION public.create_deal_v1(
  p_id           uuid,
  p_calc_version int   DEFAULT 1,
  p_assumptions  jsonb DEFAULT '{}'::jsonb
)
RETURNS json
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant         uuid;
  v_snapshot_id    uuid;
  v_arv            numeric;
  v_repair         numeric;
  v_profit         numeric;
  v_multiplier     numeric;
  v_mao            numeric;
  v_assumptions    jsonb;
  v_arv_raw        text;
  v_repair_raw     text;
  v_profit_raw     text;
  v_multiplier_raw text;
BEGIN
  -- Role enforcement first: minimum member required (first executable statement per contract).
  -- All failures from require_min_role_v1 map to NOT_AUTHORIZED:
  --   null tenant context, insufficient role, or any auth-layer exception.
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN json_build_object(
        'ok',    false,
        'code',  'NOT_AUTHORIZED',
        'data',  '{}'::jsonb,
        'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
      );
  END;

  -- Write lock enforcement: workspace must be active
  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'Workspace is read-only or expired', 'fields', json_build_object())
    );
  END IF;

  -- Resolve tenant context
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  -- Validate p_id
  IF p_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'p_id is required', 'fields', json_build_object('p_id', 'required'))
    );
  END IF;

  -- Safe extraction of raw text values before casting
  v_arv_raw        := trim(p_assumptions->>'arv');
  v_repair_raw     := trim(p_assumptions->>'repair_estimate');
  v_profit_raw     := trim(p_assumptions->>'desired_profit');
  v_multiplier_raw := trim(p_assumptions->>'multiplier');

  -- Validate arv
  IF v_arv_raw IS NULL OR v_arv_raw = '' OR v_arv_raw !~ '^\d+(\.\d+)?$' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'arv is required and must be a non-negative number', 'fields', json_build_object('arv', 'required'))
    );
  END IF;
  v_arv := v_arv_raw::numeric;
  IF v_arv < 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'arv must be non-negative', 'fields', json_build_object('arv', 'invalid'))
    );
  END IF;

  -- Validate repair_estimate
  IF v_repair_raw IS NULL OR v_repair_raw = '' OR v_repair_raw !~ '^\d+(\.\d+)?$' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'repair_estimate is required and must be a non-negative number', 'fields', json_build_object('repair_estimate', 'required'))
    );
  END IF;
  v_repair := v_repair_raw::numeric;
  IF v_repair < 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'repair_estimate must be non-negative', 'fields', json_build_object('repair_estimate', 'invalid'))
    );
  END IF;

  -- Validate desired_profit
  IF v_profit_raw IS NULL OR v_profit_raw = '' OR v_profit_raw !~ '^\d+(\.\d+)?$' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'desired_profit is required and must be a non-negative number', 'fields', json_build_object('desired_profit', 'required'))
    );
  END IF;
  v_profit := v_profit_raw::numeric;
  IF v_profit < 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'desired_profit must be non-negative', 'fields', json_build_object('desired_profit', 'invalid'))
    );
  END IF;

  -- Validate multiplier
  IF v_multiplier_raw IS NULL OR v_multiplier_raw = '' OR v_multiplier_raw !~ '^\d+(\.\d+)?$' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'multiplier is required and must be a number', 'fields', json_build_object('multiplier', 'required'))
    );
  END IF;
  v_multiplier := v_multiplier_raw::numeric;
  IF v_multiplier <= 0 OR v_multiplier > 1 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'multiplier must be between 0 and 1 exclusive', 'fields', json_build_object('multiplier', 'invalid'))
    );
  END IF;

  -- Compute MAO server-side -- overwrite any frontend-supplied mao unconditionally
  v_mao := ROUND(v_arv * v_multiplier - v_repair - v_profit);

  -- Build final assumptions blob with backend-computed mao
  v_assumptions := p_assumptions || jsonb_build_object('mao', v_mao);

  -- Generate snapshot id
  v_snapshot_id := gen_random_uuid();

  -- Step 1: Insert deal
  INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
  VALUES (p_id, v_tenant, 1, p_calc_version, v_snapshot_id);

  -- Step 2: Insert deal_inputs snapshot with backend-computed assumptions
  INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
  VALUES (v_snapshot_id, v_tenant, p_id, p_calc_version, 1, v_assumptions);

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'id',                      p_id,
      'tenant_id',               v_tenant,
      'assumptions_snapshot_id', v_snapshot_id,
      'mao',                     v_mao
    ),
    'error', null
  );

EXCEPTION WHEN unique_violation THEN
  RETURN json_build_object(
    'ok',    false,
    'code',  'CONFLICT',
    'data',  '{}'::jsonb,
    'error', json_build_object('message', 'Deal already exists', 'fields', json_build_object())
  );
WHEN OTHERS THEN
  RETURN json_build_object(
    'ok',    false,
    'code',  'INTERNAL',
    'data',  '{}'::jsonb,
    'error', json_build_object('message', SQLERRM, 'fields', json_build_object())
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.create_deal_v1(uuid, int, jsonb) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_deal_v1(uuid, int, jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_deal_v1(uuid, int, jsonb) TO authenticated;