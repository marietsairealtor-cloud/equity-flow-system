-- 10.12C7: Intake Backend -- Money Input Normalizer
-- _parse_money_input_v1 + canonicalize + stricter intake validate + MAO path unchanged.
-- DROP + recreate: _intake_validate_pricing_assumptions_v1, _intake_apply_mao_to_assumptions_v1,
--   create_deal_from_intake_v1, promote_draft_deal_v1, update_deal_pricing_v1.
-- No schema DDL. submit_form_v1 unchanged (Build Route DoD).

DROP FUNCTION IF EXISTS public.update_deal_pricing_v1(uuid, jsonb);
DROP FUNCTION IF EXISTS public.promote_draft_deal_v1(uuid, jsonb);
DROP FUNCTION IF EXISTS public.create_deal_from_intake_v1(jsonb);
DROP FUNCTION IF EXISTS public._intake_apply_mao_to_assumptions_v1(jsonb);
DROP FUNCTION IF EXISTS public._intake_validate_pricing_assumptions_v1(jsonb);
DROP FUNCTION IF EXISTS public._intake_canonicalize_pricing_assumptions_v1(jsonb);
DROP FUNCTION IF EXISTS public._parse_money_input_v1(text);

-- ============================================================
-- _parse_money_input_v1
-- ============================================================
CREATE FUNCTION public._parse_money_input_v1(p_input text)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $pm$
DECLARE
  s     text;
  mul   numeric := 1;
  last1 text;
BEGIN
  IF p_input IS NULL THEN
    RETURN NULL;
  END IF;
  s := trim(p_input);
  IF s = '' THEN
    RETURN NULL;
  END IF;
  last1 := right(s, 1);
  IF last1 IN ('K','k') THEN
    mul := 1000;
    s := trim(substring(s FROM 1 FOR length(s) - 1));
  ELSIF last1 IN ('M','m') THEN
    mul := 1000000;
    s := trim(substring(s FROM 1 FOR length(s) - 1));
  END IF;
  IF s IS NULL OR s = '' THEN
    RETURN NULL;
  END IF;
  s := regexp_replace(s, '[\$,[:space:]]', '', 'g');
  IF s = '' OR s IS NULL THEN
    RETURN NULL;
  END IF;
  IF s !~ '^[0-9]+(\.[0-9]+)?$' THEN
    RETURN NULL;
  END IF;
  RETURN (s::numeric) * mul;
END;
$pm$;

ALTER FUNCTION public._parse_money_input_v1(text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public._parse_money_input_v1(text) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- Canonicalize assumptions jsonb to numeric json values (or NULL if invalid)
-- ============================================================
CREATE FUNCTION public._intake_canonicalize_pricing_assumptions_v1(p_assumptions jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $ic$
DECLARE
  v_out  jsonb := '{}'::jsonb;
  v_t    text;
  v_n    numeric;
  v_mult numeric;
BEGIN
  IF p_assumptions IS NULL OR p_assumptions = '{}'::jsonb THEN
    RETURN '{}'::jsonb;
  END IF;

  IF p_assumptions ? 'arv' THEN
    v_t := trim(p_assumptions->>'arv');
    IF v_t <> '' THEN
      v_n := public._parse_money_input_v1(v_t);
      IF v_n IS NULL THEN RETURN NULL; END IF;
      v_out := v_out || jsonb_build_object('arv', v_n);
    END IF;
  END IF;

  IF p_assumptions ? 'ask_price' THEN
    v_t := trim(p_assumptions->>'ask_price');
    IF v_t <> '' THEN
      v_n := public._parse_money_input_v1(v_t);
      IF v_n IS NULL THEN RETURN NULL; END IF;
      v_out := v_out || jsonb_build_object('ask_price', v_n);
    END IF;
  END IF;

  IF p_assumptions ? 'repair_estimate' THEN
    v_t := trim(p_assumptions->>'repair_estimate');
    IF v_t <> '' THEN
      v_n := public._parse_money_input_v1(v_t);
      IF v_n IS NULL THEN RETURN NULL; END IF;
      v_out := v_out || jsonb_build_object('repair_estimate', v_n);
    END IF;
  END IF;

  IF p_assumptions ? 'assignment_fee' THEN
    v_t := trim(p_assumptions->>'assignment_fee');
    IF v_t <> '' THEN
      v_n := public._parse_money_input_v1(v_t);
      IF v_n IS NULL THEN RETURN NULL; END IF;
      v_out := v_out || jsonb_build_object('assignment_fee', v_n);
    END IF;
  END IF;

  IF p_assumptions ? 'multiplier' THEN
    v_t := trim(regexp_replace(trim(p_assumptions->>'multiplier'), '%[[:space:]]*$', ''));
    IF v_t <> '' THEN
      v_mult := public._parse_money_input_v1(v_t);
      IF v_mult IS NULL THEN RETURN NULL; END IF;
      IF v_mult > 1 THEN
        v_mult := v_mult / 100;
      END IF;
      IF v_mult <= 0 OR v_mult >= 1 THEN RETURN NULL; END IF;
      v_out := v_out || jsonb_build_object('multiplier', v_mult);
    END IF;
  END IF;

  RETURN v_out;
END;
$ic$;

ALTER FUNCTION public._intake_canonicalize_pricing_assumptions_v1(jsonb) OWNER TO postgres;
REVOKE ALL ON FUNCTION public._intake_canonicalize_pricing_assumptions_v1(jsonb) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- _intake_validate_pricing_assumptions_v1 (parse-based)
-- ============================================================
CREATE FUNCTION public._intake_validate_pricing_assumptions_v1(p_assumptions jsonb)
RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $v$
DECLARE
  v_num numeric;
  v_raw text;
BEGIN
  IF p_assumptions IS NULL OR p_assumptions = '{}'::jsonb THEN
    RETURN NULL;
  END IF;

  IF p_assumptions ? 'arv' AND p_assumptions->>'arv' IS NOT NULL AND trim(p_assumptions->>'arv') <> '' THEN
    v_num := public._parse_money_input_v1(trim(p_assumptions->>'arv'));
    IF v_num IS NULL THEN
      RETURN 'arv must be a valid non-negative number';
    END IF;
    IF v_num < 0 THEN
      RETURN 'arv must be non-negative';
    END IF;
  END IF;

  IF p_assumptions ? 'ask_price' AND p_assumptions->>'ask_price' IS NOT NULL AND trim(p_assumptions->>'ask_price') <> '' THEN
    v_num := public._parse_money_input_v1(trim(p_assumptions->>'ask_price'));
    IF v_num IS NULL THEN
      RETURN 'ask_price must be a valid number';
    END IF;
  END IF;

  IF p_assumptions ? 'repair_estimate' AND p_assumptions->>'repair_estimate' IS NOT NULL AND trim(p_assumptions->>'repair_estimate') <> '' THEN
    v_num := public._parse_money_input_v1(trim(p_assumptions->>'repair_estimate'));
    IF v_num IS NULL THEN
      RETURN 'repair_estimate must be a valid non-negative number';
    END IF;
    IF v_num < 0 THEN
      RETURN 'repair_estimate must be non-negative';
    END IF;
  END IF;

  IF p_assumptions ? 'assignment_fee' AND p_assumptions->>'assignment_fee' IS NOT NULL AND trim(p_assumptions->>'assignment_fee') <> '' THEN
    v_num := public._parse_money_input_v1(trim(p_assumptions->>'assignment_fee'));
    IF v_num IS NULL THEN
      RETURN 'assignment_fee must be a valid number';
    END IF;
    IF v_num < 0 THEN
      RETURN 'assignment_fee must be non-negative';
    END IF;
  END IF;

  IF p_assumptions ? 'multiplier' AND p_assumptions->>'multiplier' IS NOT NULL AND trim(p_assumptions->>'multiplier') <> '' THEN
    v_raw := trim(regexp_replace(trim(p_assumptions->>'multiplier'), '%[[:space:]]*$', ''));
    v_num := public._parse_money_input_v1(v_raw);
    IF v_num IS NULL THEN
      RETURN 'multiplier must be a valid number';
    END IF;
    IF v_num > 1 THEN
      v_num := v_num / 100;
    END IF;
    IF v_num <= 0 OR v_num >= 1 THEN
      RETURN 'multiplier must be between 0 and 1 exclusive';
    END IF;
  END IF;

  RETURN NULL;
END;
$v$;

ALTER FUNCTION public._intake_validate_pricing_assumptions_v1(jsonb) OWNER TO postgres;
REVOKE ALL ON FUNCTION public._intake_validate_pricing_assumptions_v1(jsonb) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- _intake_apply_mao_to_assumptions_v1 (unchanged behavior)
-- ============================================================
CREATE FUNCTION public._intake_apply_mao_to_assumptions_v1(p_assumptions jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $m$
DECLARE
  v_a              jsonb;
  v_arv            numeric;
  v_mult           numeric;
  v_repair         numeric;
  v_assignment_fee numeric;
  v_mao            numeric;
  v_has_arv        boolean;
  v_has_mult       boolean;
  v_has_rep        boolean;
BEGIN
  v_a := COALESCE(p_assumptions, '{}'::jsonb) - 'mao';

  v_has_arv := (v_a ? 'arv') AND v_a->>'arv' IS NOT NULL AND trim(v_a->>'arv') <> '';
  v_has_mult := (v_a ? 'multiplier') AND v_a->>'multiplier' IS NOT NULL AND trim(v_a->>'multiplier') <> '';
  v_has_rep := (v_a ? 'repair_estimate') AND v_a->>'repair_estimate' IS NOT NULL AND trim(v_a->>'repair_estimate') <> '';

  IF v_has_arv AND v_has_mult AND v_has_rep THEN
    v_arv := (trim(v_a->>'arv'))::numeric;
    v_mult := (trim(v_a->>'multiplier'))::numeric;
    v_repair := (trim(v_a->>'repair_estimate'))::numeric;
    v_assignment_fee := CASE
      WHEN (v_a->>'assignment_fee') IS NOT NULL AND trim(v_a->>'assignment_fee') <> ''
      THEN (trim(v_a->>'assignment_fee'))::numeric
      ELSE 0::numeric
    END;
    v_mao := ROUND((v_arv * v_mult) - v_repair - v_assignment_fee);
    RETURN v_a || jsonb_build_object('mao', v_mao);
  END IF;

  RETURN v_a - 'mao';
END;
$m$;

ALTER FUNCTION public._intake_apply_mao_to_assumptions_v1(jsonb) OWNER TO postgres;
REVOKE ALL ON FUNCTION public._intake_apply_mao_to_assumptions_v1(jsonb) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- RPC: create_deal_from_intake_v1
-- ============================================================
CREATE FUNCTION public.create_deal_from_intake_v1(p_fields jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant         uuid;
  v_id             uuid;
  v_snapshot_id    uuid;
  v_top_keys       text[];
  v_allowed_top    text[] := ARRAY[
    'address','seller_name','seller_phone','seller_email',
    'seller_pain','seller_timeline','seller_notes','property','assumptions'
  ];
  v_prop_keys      text[] := ARRAY[
    'property_type','beds','baths','sqft','lot_size','year_built',
    'occupancy','deficiency_tags','condition_notes','repair_estimate',
    'garage_parking','basement_type','foundation_type',
    'roof_age','furnace_age','ac_age','heating_type','cooling_type'
  ];
  v_price_keys     text[] := ARRAY['arv','ask_price','repair_estimate','assignment_fee','multiplier'];
  v_unknown        text[];
  v_prop           jsonb;
  v_asm            jsonb;
  v_def_tags       text[];
  v_err            text;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'Not authorized', 'fields', '{}'::jsonb)
      );
  END;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'WORKSPACE_NOT_WRITABLE', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Workspace is not active', 'fields', '{}'::jsonb)
    );
  END IF;

  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_fields IS NULL OR jsonb_typeof(p_fields) <> 'object' THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_fields must be a JSON object', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT ARRAY(SELECT jsonb_object_keys(p_fields)) INTO v_top_keys;
  SELECT ARRAY(
    SELECT unnest(v_top_keys)
    EXCEPT
    SELECT unnest(v_allowed_top)
  ) INTO v_unknown;
  IF array_length(v_unknown, 1) > 0 THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'Unknown top-level fields: ' || array_to_string(v_unknown, ', '),
        'fields', '{}'::jsonb
      )
    );
  END IF;

  IF p_fields ? 'property' AND (jsonb_typeof(p_fields->'property') <> 'object' OR p_fields->'property' IS NULL) THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'property must be a JSON object', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_fields ? 'assumptions' THEN
    IF jsonb_typeof(p_fields->'assumptions') <> 'object' OR p_fields->'assumptions' IS NULL THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'assumptions must be a JSON object', 'fields', '{}'::jsonb)
      );
    END IF;
    IF p_fields->'assumptions' ? 'mao' THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'mao is derived server-side', 'fields', '{}'::jsonb)
      );
    END IF;
    SELECT ARRAY(
      SELECT jsonb_object_keys(p_fields->'assumptions')
      EXCEPT
      SELECT unnest(v_price_keys)
    ) INTO v_unknown;
    IF array_length(v_unknown, 1) > 0 THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object(
          'message', 'Unknown assumptions keys: ' || array_to_string(v_unknown, ', '),
          'fields', '{}'::jsonb
        )
      );
    END IF;
  END IF;

  IF p_fields ? 'property' THEN
    SELECT ARRAY(
      SELECT jsonb_object_keys(p_fields->'property')
      EXCEPT
      SELECT unnest(v_prop_keys)
    ) INTO v_unknown;
    IF array_length(v_unknown, 1) > 0 THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object(
          'message', 'Unknown property keys: ' || array_to_string(v_unknown, ', '),
          'fields', '{}'::jsonb
        )
      );
    END IF;
    v_err := public._intake_validate_deal_property_jsonb_v1(p_fields->'property');
    IF v_err IS NOT NULL THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', v_err, 'fields', '{}'::jsonb)
      );
    END IF;
  END IF;

  v_asm := public._intake_canonicalize_pricing_assumptions_v1(COALESCE(p_fields->'assumptions', '{}'::jsonb));
  IF v_asm IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid monetary value in assumptions', 'fields', '{}'::jsonb)
    );
  END IF;

  v_err := public._intake_validate_pricing_assumptions_v1(v_asm);
  IF v_err IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', v_err, 'fields', '{}'::jsonb)
    );
  END IF;

  v_id := gen_random_uuid();
  v_snapshot_id := gen_random_uuid();
  v_asm := public._intake_apply_mao_to_assumptions_v1(v_asm);

  INSERT INTO public.deals (
    id, tenant_id, row_version, calc_version,
    assumptions_snapshot_id, stage,
    address,
    seller_name, seller_phone, seller_email, seller_pain, seller_timeline, seller_notes
  ) VALUES (
    v_id, v_tenant, 1, 1,
    v_snapshot_id, 'new',
    NULLIF(trim(p_fields->>'address'), ''),
    NULLIF(trim(p_fields->>'seller_name'), ''),
    NULLIF(trim(p_fields->>'seller_phone'), ''),
    NULLIF(trim(p_fields->>'seller_email'), ''),
    NULLIF(trim(p_fields->>'seller_pain'), ''),
    NULLIF(trim(p_fields->>'seller_timeline'), ''),
    NULLIF(trim(p_fields->>'seller_notes'), '')
  );

  INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
  VALUES (v_snapshot_id, v_tenant, v_id, 1, 1, COALESCE(v_asm, '{}'::jsonb));

  IF p_fields ? 'property' AND p_fields->'property' <> '{}'::jsonb THEN
    v_prop := p_fields->'property';

    IF v_prop ? 'deficiency_tags' AND jsonb_typeof(v_prop->'deficiency_tags') = 'array' THEN
      v_def_tags := ARRAY(SELECT jsonb_array_elements_text(v_prop->'deficiency_tags'));
    END IF;

    INSERT INTO public.deal_properties (
      tenant_id, deal_id, row_version,
      property_type, beds, baths, sqft, lot_size, year_built, occupancy,
      deficiency_tags, condition_notes, repair_estimate,
      garage_parking, basement_type, foundation_type,
      roof_age, furnace_age, ac_age, heating_type, cooling_type
    ) VALUES (
      v_tenant, v_id, 1,
      NULLIF(trim(v_prop->>'property_type'), ''),
      NULLIF(trim(v_prop->>'beds'), ''),
      NULLIF(trim(v_prop->>'baths'), ''),
      NULLIF(trim(v_prop->>'sqft'), ''),
      NULLIF(trim(v_prop->>'lot_size'), ''),
      CASE WHEN v_prop->>'year_built' IS NOT NULL AND trim(v_prop->>'year_built') <> ''
        THEN (trim(v_prop->>'year_built'))::integer ELSE NULL END,
      NULLIF(trim(v_prop->>'occupancy'), ''),
      v_def_tags,
      NULLIF(trim(v_prop->>'condition_notes'), ''),
      CASE WHEN v_prop->>'repair_estimate' IS NOT NULL AND trim(v_prop->>'repair_estimate') <> ''
        THEN (trim(v_prop->>'repair_estimate'))::numeric ELSE NULL END,
      NULLIF(trim(v_prop->>'garage_parking'), ''),
      NULLIF(trim(v_prop->>'basement_type'), ''),
      NULLIF(trim(v_prop->>'foundation_type'), ''),
      CASE WHEN v_prop->>'roof_age' IS NOT NULL AND trim(v_prop->>'roof_age') <> ''
        THEN (trim(v_prop->>'roof_age'))::integer ELSE NULL END,
      CASE WHEN v_prop->>'furnace_age' IS NOT NULL AND trim(v_prop->>'furnace_age') <> ''
        THEN (trim(v_prop->>'furnace_age'))::integer ELSE NULL END,
      CASE WHEN v_prop->>'ac_age' IS NOT NULL AND trim(v_prop->>'ac_age') <> ''
        THEN (trim(v_prop->>'ac_age'))::integer ELSE NULL END,
      NULLIF(trim(v_prop->>'heating_type'), ''),
      NULLIF(trim(v_prop->>'cooling_type'), '')
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object('deal_id', v_id),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.create_deal_from_intake_v1(jsonb) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.create_deal_from_intake_v1(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_deal_from_intake_v1(jsonb) TO authenticated;

-- ============================================================
-- RPC: promote_draft_deal_v1
-- ============================================================
CREATE FUNCTION public.promote_draft_deal_v1(
  p_draft_id uuid,
  p_fields     jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant      uuid;
  d             RECORD;
  v_pf          jsonb;
  v_addr        text;
  v_sn          text;
  v_sp          text;
  v_se          text;
  v_pain        text;
  v_tl          text;
  v_notes       text;
  v_asm         jsonb;
  v_prop_m      jsonb;
  v_id          uuid;
  v_snapshot_id uuid;
  v_prop_keys   text[] := ARRAY[
    'property_type','beds','baths','sqft','lot_size','year_built',
    'occupancy','deficiency_tags','condition_notes','repair_estimate',
    'garage_parking','basement_type','foundation_type',
    'roof_age','furnace_age','ac_age','heating_type','cooling_type'
  ];
  v_allowed_top text[] := ARRAY[
    'address','seller_name','seller_phone','seller_email',
    'seller_pain','seller_timeline','seller_notes','property','assumptions'
  ];
  v_price_keys  text[] := ARRAY['arv','ask_price','repair_estimate','assignment_fee','multiplier'];
  v_unknown     text[];
  v_prop        jsonb;
  v_def_tags    text[];
  v_err         text;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'Not authorized', 'fields', '{}'::jsonb)
      );
  END;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'WORKSPACE_NOT_WRITABLE', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Workspace is not active', 'fields', '{}'::jsonb)
    );
  END IF;

  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_draft_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_draft_id is required', 'fields', '{}'::jsonb)
    );
  END IF;

  v_pf := COALESCE(p_fields, '{}'::jsonb);
  IF jsonb_typeof(v_pf) <> 'object' THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_fields must be a JSON object', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT ARRAY(
    SELECT jsonb_object_keys(v_pf)
    EXCEPT
    SELECT unnest(v_allowed_top)
  ) INTO v_unknown;
  IF array_length(v_unknown, 1) > 0 THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'Unknown top-level fields: ' || array_to_string(v_unknown, ', '),
        'fields', '{}'::jsonb
      )
    );
  END IF;

  IF v_pf ? 'property' AND (jsonb_typeof(v_pf->'property') <> 'object' OR v_pf->'property' IS NULL) THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'property must be a JSON object', 'fields', '{}'::jsonb)
    );
  END IF;

  IF v_pf ? 'assumptions' THEN
    IF jsonb_typeof(v_pf->'assumptions') <> 'object' OR v_pf->'assumptions' IS NULL THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'assumptions must be a JSON object', 'fields', '{}'::jsonb)
      );
    END IF;
    IF v_pf->'assumptions' ? 'mao' THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'mao is derived server-side', 'fields', '{}'::jsonb)
      );
    END IF;
    SELECT ARRAY(
      SELECT jsonb_object_keys(v_pf->'assumptions')
      EXCEPT
      SELECT unnest(v_price_keys)
    ) INTO v_unknown;
    IF array_length(v_unknown, 1) > 0 THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object(
          'message', 'Unknown assumptions keys: ' || array_to_string(v_unknown, ', '),
          'fields', '{}'::jsonb
        )
      );
    END IF;
  END IF;

  IF v_pf ? 'property' THEN
    SELECT ARRAY(
      SELECT jsonb_object_keys(v_pf->'property')
      EXCEPT
      SELECT unnest(v_prop_keys)
    ) INTO v_unknown;
    IF array_length(v_unknown, 1) > 0 THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object(
          'message', 'Unknown property keys: ' || array_to_string(v_unknown, ', '),
          'fields', '{}'::jsonb
        )
      );
    END IF;
  END IF;

  SELECT * INTO d
  FROM public.draft_deals
  WHERE id = p_draft_id AND tenant_id = v_tenant;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Draft not found', 'fields', '{}'::jsonb)
    );
  END IF;

  IF d.promoted_deal_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Draft already promoted', 'fields', '{}'::jsonb)
    );
  END IF;

  v_err := public._intake_validate_deal_property_jsonb_v1(COALESCE(v_pf->'property', '{}'::jsonb));
  IF v_err IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', v_err, 'fields', '{}'::jsonb)
    );
  END IF;

  v_addr := NULLIF(trim(v_pf->>'address'), '');
  v_sn   := NULLIF(trim(v_pf->>'seller_name'), '');
  v_sp   := NULLIF(trim(v_pf->>'seller_phone'), '');
  v_se   := NULLIF(trim(v_pf->>'seller_email'), '');
  v_pain := NULLIF(trim(v_pf->>'seller_pain'), '');
  v_tl   := NULLIF(trim(v_pf->>'seller_timeline'), '');
  v_notes := NULLIF(trim(v_pf->>'seller_notes'), '');

  IF d.form_type = 'seller' THEN
    v_addr := COALESCE(v_addr, NULLIF(trim(d.address), ''), NULLIF(trim(d.payload->>'address'), ''));
    v_sn := COALESCE(v_sn, NULLIF(trim(d.payload->>'name'), ''));
    v_sp := COALESCE(v_sp, NULLIF(trim(d.payload->>'phone'), ''));
    v_se := COALESCE(v_se, NULLIF(trim(d.payload->>'email'), ''));
  ELSIF d.form_type = 'birddog' THEN
    v_addr := COALESCE(v_addr, NULLIF(trim(d.address), ''), NULLIF(trim(d.payload->>'address'), ''));
    v_sn := COALESCE(v_sn, NULLIF(trim(d.payload->>'name'), ''));
    v_sp := COALESCE(v_sp, NULLIF(trim(d.payload->>'phone'), ''));
    v_se := COALESCE(v_se, NULLIF(trim(d.payload->>'email'), ''));
  ELSIF d.form_type = 'buyer' THEN
    v_sn := COALESCE(v_sn, NULLIF(trim(d.payload->>'name'), ''));
    v_sp := COALESCE(v_sp, NULLIF(trim(d.payload->>'phone'), ''));
    v_se := COALESCE(v_se, NULLIF(trim(d.payload->>'email'), ''));
  END IF;

  v_asm := '{}'::jsonb;
  IF d.asking_price IS NOT NULL THEN
    v_asm := v_asm || jsonb_build_object('ask_price', d.asking_price);
  END IF;
  IF d.repair_estimate IS NOT NULL THEN
    v_asm := v_asm || jsonb_build_object('repair_estimate', d.repair_estimate);
  END IF;
  IF d.form_type = 'birddog' AND (d.payload->>'asking_price') IS NOT NULL AND trim(d.payload->>'asking_price') <> '' THEN
    v_asm := v_asm || jsonb_build_object('ask_price', trim(d.payload->>'asking_price'));
  END IF;

  v_asm := v_asm || COALESCE(v_pf->'assumptions', '{}'::jsonb);

  v_asm := public._intake_canonicalize_pricing_assumptions_v1(v_asm);
  IF v_asm IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid monetary value in assumptions', 'fields', '{}'::jsonb)
    );
  END IF;

  v_err := public._intake_validate_pricing_assumptions_v1(v_asm);
  IF v_err IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', v_err, 'fields', '{}'::jsonb)
    );
  END IF;

  v_asm := public._intake_apply_mao_to_assumptions_v1(v_asm);

  v_prop_m := '{}'::jsonb;
  IF d.form_type = 'birddog' AND (d.payload->>'condition_notes') IS NOT NULL THEN
    v_prop_m := v_prop_m || jsonb_build_object(
      'condition_notes', NULLIF(trim(d.payload->>'condition_notes'), '')
    );
  END IF;
  IF d.form_type IN ('seller', 'birddog') AND d.repair_estimate IS NOT NULL THEN
    v_prop_m := v_prop_m || jsonb_build_object('repair_estimate', d.repair_estimate);
  END IF;

  IF v_pf ? 'property' THEN
    v_prop_m := COALESCE(v_prop_m, '{}'::jsonb) || COALESCE(v_pf->'property', '{}'::jsonb);
  END IF;

  v_err := public._intake_validate_deal_property_jsonb_v1(
    CASE WHEN v_prop_m = '{}'::jsonb OR v_prop_m IS NULL THEN '{}'::jsonb ELSE v_prop_m END
  );
  IF v_err IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', v_err, 'fields', '{}'::jsonb)
    );
  END IF;

  v_id := gen_random_uuid();
  v_snapshot_id := gen_random_uuid();

  INSERT INTO public.deals (
    id, tenant_id, row_version, calc_version,
    assumptions_snapshot_id, stage,
    address,
    seller_name, seller_phone, seller_email, seller_pain, seller_timeline, seller_notes
  ) VALUES (
    v_id, v_tenant, 1, 1,
    v_snapshot_id, 'new',
    v_addr, v_sn, v_sp, v_se, v_pain, v_tl, v_notes
  );

  INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
  VALUES (v_snapshot_id, v_tenant, v_id, 1, 1, COALESCE(v_asm, '{}'::jsonb));

  IF v_prop_m IS NOT NULL AND v_prop_m <> '{}'::jsonb THEN
    v_prop := v_prop_m;
    v_def_tags := NULL;
    IF v_prop ? 'deficiency_tags' AND jsonb_typeof(v_prop->'deficiency_tags') = 'array' THEN
      v_def_tags := ARRAY(SELECT jsonb_array_elements_text(v_prop->'deficiency_tags'));
    END IF;

    INSERT INTO public.deal_properties (
      tenant_id, deal_id, row_version,
      property_type, beds, baths, sqft, lot_size, year_built, occupancy,
      deficiency_tags, condition_notes, repair_estimate,
      garage_parking, basement_type, foundation_type,
      roof_age, furnace_age, ac_age, heating_type, cooling_type
    ) VALUES (
      v_tenant, v_id, 1,
      NULLIF(trim(v_prop->>'property_type'), ''),
      NULLIF(trim(v_prop->>'beds'), ''),
      NULLIF(trim(v_prop->>'baths'), ''),
      NULLIF(trim(v_prop->>'sqft'), ''),
      NULLIF(trim(v_prop->>'lot_size'), ''),
      CASE WHEN v_prop->>'year_built' IS NOT NULL AND trim(v_prop->>'year_built') <> ''
        THEN (trim(v_prop->>'year_built'))::integer ELSE NULL END,
      NULLIF(trim(v_prop->>'occupancy'), ''),
      v_def_tags,
      NULLIF(trim(v_prop->>'condition_notes'), ''),
      CASE WHEN v_prop->>'repair_estimate' IS NOT NULL AND trim(v_prop->>'repair_estimate') <> ''
        THEN (trim(v_prop->>'repair_estimate'))::numeric ELSE NULL END,
      NULLIF(trim(v_prop->>'garage_parking'), ''),
      NULLIF(trim(v_prop->>'basement_type'), ''),
      NULLIF(trim(v_prop->>'foundation_type'), ''),
      CASE WHEN v_prop->>'roof_age' IS NOT NULL AND trim(v_prop->>'roof_age') <> ''
        THEN (trim(v_prop->>'roof_age'))::integer ELSE NULL END,
      CASE WHEN v_prop->>'furnace_age' IS NOT NULL AND trim(v_prop->>'furnace_age') <> ''
        THEN (trim(v_prop->>'furnace_age'))::integer ELSE NULL END,
      CASE WHEN v_prop->>'ac_age' IS NOT NULL AND trim(v_prop->>'ac_age') <> ''
        THEN (trim(v_prop->>'ac_age'))::integer ELSE NULL END,
      NULLIF(trim(v_prop->>'heating_type'), ''),
      NULLIF(trim(v_prop->>'cooling_type'), '')
    );
  END IF;

  UPDATE public.draft_deals
  SET promoted_deal_id = v_id
  WHERE id = d.id AND tenant_id = v_tenant;

  UPDATE public.intake_submissions
  SET reviewed_at = now()
  WHERE draft_deals_id = d.id AND tenant_id = v_tenant;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object('deal_id', v_id),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.promote_draft_deal_v1(uuid, jsonb) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.promote_draft_deal_v1(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.promote_draft_deal_v1(uuid, jsonb) TO authenticated;

-- ============================================================
-- RPC: update_deal_pricing_v1
-- ============================================================
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