-- 10.13E: Offer Flow — Save Deal + Reopen Deal (backend)
-- Successful update_deal_pricing_v1 appends one deal_activity_log row (pricing_save).
-- require_min_role_v1('member') first (RPC mapping: SECURITY DEFINER, authenticated, min role member).

DROP FUNCTION IF EXISTS public.update_deal_pricing_v1(uuid, jsonb);

CREATE FUNCTION public.update_deal_pricing_v1(
  p_deal_id uuid,
  p_fields  jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant           uuid;
  v_user             uuid;
  v_allowed_keys     text[] := ARRAY['arv','ask_price','repair_estimate','assignment_fee','multiplier'];
  v_unknown_keys     text[];
  v_base_row         record;
  v_base_assumptions jsonb;
  v_new_assumptions  jsonb;
  v_arv              numeric;
  v_ask_price        numeric;
  v_repair_estimate  numeric;
  v_assignment_fee   numeric;
  v_multiplier       numeric;
  v_new_id           uuid;
  v_final_arv        numeric;
  v_final_repair     numeric;
  v_final_multiplier     numeric;
  v_final_assignment_fee numeric;
  v_raw              text;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN json_build_object(
        'ok', false,
        'code', 'NOT_AUTHORIZED',
        'data', '{}'::json,
        'error', json_build_object('message', 'Not authorized', 'fields', '{}'::json)
      );
  END;

  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No tenant or user context', 'fields', '{}'::json)
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'WORKSPACE_NOT_WRITABLE',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Workspace is not active', 'fields', '{}'::json)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_deal_id is required', 'fields', '{}'::json)
    );
  END IF;

  IF p_fields IS NULL OR jsonb_typeof(p_fields) <> 'object' OR p_fields = '{}'::jsonb THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_fields must be a non-empty JSON object', 'fields', '{}'::json)
    );
  END IF;

  IF p_fields ? 'mao' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'mao is derived server-side and cannot be set directly', 'fields', '{}'::json)
    );
  END IF;

  SELECT ARRAY(
    SELECT jsonb_object_keys(p_fields)
    EXCEPT
    SELECT unnest(v_allowed_keys)
  ) INTO v_unknown_keys;

  IF array_length(v_unknown_keys, 1) > 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Unknown fields: ' || array_to_string(v_unknown_keys, ', '), 'fields', '{}'::json)
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.deals
    WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
    );
  END IF;

  SELECT * INTO v_base_row
  FROM public.deal_inputs
  WHERE deal_id   = p_deal_id
    AND tenant_id = v_tenant
  ORDER BY created_at DESC, id DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No base pricing row found for this deal', 'fields', '{}'::json)
    );
  END IF;

  v_base_assumptions := COALESCE(v_base_row.assumptions, '{}'::jsonb);

  IF p_fields ? 'arv' AND p_fields->>'arv' IS NOT NULL AND btrim(p_fields->>'arv') <> '' THEN
    v_arv := public._parse_money_input_v1(btrim(p_fields->>'arv'));
    IF v_arv IS NULL THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'arv must be a valid number', 'fields', '{}'::json));
    END IF;
    IF v_arv < 0 THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'arv must be non-negative', 'fields', '{}'::json));
    END IF;
  END IF;

  IF p_fields ? 'ask_price' AND p_fields->>'ask_price' IS NOT NULL AND btrim(p_fields->>'ask_price') <> '' THEN
    v_ask_price := public._parse_money_input_v1(btrim(p_fields->>'ask_price'));
    IF v_ask_price IS NULL THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'ask_price must be a valid number', 'fields', '{}'::json));
    END IF;
  END IF;

  IF p_fields ? 'repair_estimate' AND p_fields->>'repair_estimate' IS NOT NULL AND btrim(p_fields->>'repair_estimate') <> '' THEN
    v_repair_estimate := public._parse_money_input_v1(btrim(p_fields->>'repair_estimate'));
    IF v_repair_estimate IS NULL THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'repair_estimate must be a valid number', 'fields', '{}'::json));
    END IF;
    IF v_repair_estimate < 0 THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'repair_estimate must be non-negative', 'fields', '{}'::json));
    END IF;
  END IF;

  IF p_fields ? 'assignment_fee' AND p_fields->>'assignment_fee' IS NOT NULL AND btrim(p_fields->>'assignment_fee') <> '' THEN
    v_assignment_fee := public._parse_money_input_v1(btrim(p_fields->>'assignment_fee'));
    IF v_assignment_fee IS NULL THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'assignment_fee must be a valid number', 'fields', '{}'::json));
    END IF;
    IF v_assignment_fee < 0 THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'assignment_fee must be non-negative', 'fields', '{}'::json));
    END IF;
  END IF;

  IF p_fields ? 'multiplier' AND p_fields->>'multiplier' IS NOT NULL AND btrim(p_fields->>'multiplier') <> '' THEN
    v_raw := btrim(regexp_replace(btrim(p_fields->>'multiplier'), '%[[:space:]]*$', ''));
    v_multiplier := public._parse_money_input_v1(v_raw);
    IF v_multiplier IS NULL THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'multiplier must be a valid number', 'fields', '{}'::json));
    END IF;
    IF v_multiplier > 1 THEN
      v_multiplier := v_multiplier / 100;
    END IF;
    IF v_multiplier <= 0 OR v_multiplier >= 1 THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'multiplier must be between 0 and 1 exclusive', 'fields', '{}'::json));
    END IF;
  END IF;

  v_new_assumptions := v_base_assumptions;

  IF p_fields ? 'arv' THEN
    IF p_fields->>'arv' IS NULL OR btrim(COALESCE(p_fields->>'arv', '')) = '' THEN
      v_new_assumptions := v_new_assumptions - 'arv';
    ELSE
      v_new_assumptions := jsonb_set(v_new_assumptions, '{arv}', to_jsonb(v_arv));
    END IF;
  END IF;

  IF p_fields ? 'ask_price' THEN
    IF p_fields->>'ask_price' IS NULL OR btrim(COALESCE(p_fields->>'ask_price', '')) = '' THEN
      v_new_assumptions := v_new_assumptions - 'ask_price';
    ELSE
      v_new_assumptions := jsonb_set(v_new_assumptions, '{ask_price}', to_jsonb(v_ask_price));
    END IF;
  END IF;

  IF p_fields ? 'repair_estimate' THEN
    IF p_fields->>'repair_estimate' IS NULL OR btrim(COALESCE(p_fields->>'repair_estimate', '')) = '' THEN
      v_new_assumptions := v_new_assumptions - 'repair_estimate';
    ELSE
      v_new_assumptions := jsonb_set(v_new_assumptions, '{repair_estimate}', to_jsonb(v_repair_estimate));
    END IF;
  END IF;

  IF p_fields ? 'assignment_fee' THEN
    IF p_fields->>'assignment_fee' IS NULL OR btrim(COALESCE(p_fields->>'assignment_fee', '')) = '' THEN
      v_new_assumptions := v_new_assumptions - 'assignment_fee';
    ELSE
      v_new_assumptions := jsonb_set(v_new_assumptions, '{assignment_fee}', to_jsonb(v_assignment_fee));
    END IF;
  END IF;

  IF p_fields ? 'multiplier' THEN
    IF p_fields->>'multiplier' IS NULL OR btrim(COALESCE(p_fields->>'multiplier', '')) = '' THEN
      v_new_assumptions := v_new_assumptions - 'multiplier';
    ELSE
      v_new_assumptions := jsonb_set(v_new_assumptions, '{multiplier}', to_jsonb(v_multiplier));
    END IF;
  END IF;

  IF v_new_assumptions = v_base_assumptions THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No actual changes provided', 'fields', '{}'::json)
    );
  END IF;

  v_final_arv            := (v_new_assumptions->>'arv')::numeric;
  v_final_repair         := (v_new_assumptions->>'repair_estimate')::numeric;
  v_final_multiplier     := (v_new_assumptions->>'multiplier')::numeric;
  v_final_assignment_fee := (v_new_assumptions->>'assignment_fee')::numeric;

  IF v_final_arv IS NOT NULL AND v_final_multiplier IS NOT NULL AND v_final_repair IS NOT NULL THEN
    v_new_assumptions := jsonb_set(v_new_assumptions, '{mao}',
      to_jsonb((v_final_arv * v_final_multiplier) - v_final_repair - COALESCE(v_final_assignment_fee, 0)));
  ELSE
    v_new_assumptions := v_new_assumptions - 'mao';
  END IF;

  INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
  VALUES (gen_random_uuid(), v_tenant, p_deal_id, v_base_row.calc_version, v_new_assumptions, clock_timestamp())
  RETURNING id INTO v_new_id;

  UPDATE public.deals
  SET assumptions_snapshot_id = v_new_id,
      updated_at              = now(),
      row_version             = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  INSERT INTO public.deal_activity_log (
    tenant_id, deal_id, activity_type, content, created_by, created_at
  ) VALUES (
    v_tenant, p_deal_id, 'pricing_save', 'Pricing saved', v_user, clock_timestamp()
  );

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'deal_inputs_id', v_new_id),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.update_deal_pricing_v1(uuid, jsonb) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.update_deal_pricing_v1(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_deal_pricing_v1(uuid, jsonb) TO authenticated;
