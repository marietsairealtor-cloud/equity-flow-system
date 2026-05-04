-- 10.12C1: Intake Backend -- Manual Deal Creation + Draft Promotion
-- Links intake_submissions to draft_deals; tracks promotion on draft_deals.
-- RPCs: create_deal_from_intake_v1(p_fields jsonb), promote_draft_deal_v1(p_draft_id, p_fields).
-- Authenticated + member+ + workspace write lock; jsonb envelopes (intake RPC pattern).
-- check_workspace_write_allowed_v1() RETURNS boolean (10.8.11N) — boolean guard, not JSON.

-- ============================================================
-- ALTER: draft_deals.promoted_deal_id
-- Forward-only deterministic DDL (no DO blocks).
-- ============================================================
ALTER TABLE public.draft_deals
  ADD COLUMN IF NOT EXISTS promoted_deal_id uuid;

ALTER TABLE public.draft_deals
  ADD CONSTRAINT draft_deals_promoted_deal_id_fkey
  FOREIGN KEY (promoted_deal_id) REFERENCES public.deals (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS draft_deals_tenant_promoted_idx
  ON public.draft_deals (tenant_id)
  WHERE promoted_deal_id IS NOT NULL;

-- ============================================================
-- ALTER: intake_submissions.draft_deals_id
-- ============================================================
ALTER TABLE public.intake_submissions
  ADD COLUMN IF NOT EXISTS draft_deals_id uuid;

ALTER TABLE public.intake_submissions
  ADD CONSTRAINT intake_submissions_draft_deals_id_fkey
  FOREIGN KEY (draft_deals_id) REFERENCES public.draft_deals (id) ON DELETE SET NULL;

-- At most one intake row per draft when linked (submit_form_v1 creates 1:1).
CREATE UNIQUE INDEX IF NOT EXISTS intake_submissions_draft_deals_id_uidx
  ON public.intake_submissions (draft_deals_id)
  WHERE draft_deals_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS intake_submissions_draft_deals_id_idx
  ON public.intake_submissions (draft_deals_id)
  WHERE draft_deals_id IS NOT NULL;

-- ============================================================
-- RPC: submit_form_v1 (DROP + recreate -- persist draft_deals_id on intake row)
-- ============================================================
DROP FUNCTION IF EXISTS public.submit_form_v1(text, text, jsonb);

CREATE FUNCTION public.submit_form_v1(
  p_slug      text,
  p_form_type text,
  p_payload   jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id   uuid;
  v_draft_id    uuid;
  v_intake_id    uuid;
  v_buyer_id    uuid;
  v_address      text;
  v_valid_types  text[] := ARRAY['buyer', 'seller', 'birddog'];
  v_spam_token   text;
  v_sub_status   text;
  v_period_end   timestamptz;
BEGIN
  IF p_form_type IS NULL OR NOT (p_form_type = ANY(v_valid_types)) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid form type',
        'fields', jsonb_build_object('form_type', 'Must be buyer, seller, or birddog')));
  END IF;

  IF p_slug IS NULL OR p_slug !~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not found', 'fields', '{}'::jsonb));
  END IF;

  IF p_payload IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Payload required',
        'fields', jsonb_build_object('payload', 'Required')));
  END IF;

  v_spam_token := p_payload->>'spam_token';
  IF v_spam_token IS NULL OR length(trim(v_spam_token)) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Spam protection token required',
        'fields', jsonb_build_object('spam_token', 'Required')));
  END IF;

  SELECT ts.tenant_id INTO v_tenant_id
  FROM public.tenant_slugs ts
  WHERE ts.slug = p_slug;

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not found', 'fields', '{}'::jsonb));
  END IF;

  SELECT ts.status, ts.current_period_end
  INTO v_sub_status, v_period_end
  FROM public.tenant_subscriptions ts
  WHERE ts.tenant_id = v_tenant_id
  ORDER BY ts.created_at DESC
  LIMIT 1;

  IF v_sub_status IS NULL OR v_sub_status = 'canceled' OR v_period_end <= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is not accepting submissions.',
        'fields', '{}'::jsonb));
  END IF;

  IF p_form_type = 'seller' THEN
    v_address := NULLIF(trim(p_payload->>'address'), '');
  END IF;

  INSERT INTO public.draft_deals (
    tenant_id, slug, form_type, payload,
    asking_price, repair_estimate, address
  ) VALUES (
    v_tenant_id, p_slug, p_form_type, p_payload,
    NULL, NULL, v_address
  )
  RETURNING id INTO v_draft_id;

  INSERT INTO public.intake_submissions (tenant_id, form_type, payload, source, draft_deals_id)
  VALUES (v_tenant_id, p_form_type, p_payload, 'web', v_draft_id)
  RETURNING id INTO v_intake_id;

  IF p_form_type = 'buyer' THEN
    v_buyer_id := public.upsert_buyer_from_intake_v1(v_tenant_id, p_payload);
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object(
      'draft_id',  v_draft_id,
      'intake_id', v_intake_id,
      'buyer_id',  v_buyer_id
    ),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.submit_form_v1(text, text, jsonb) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.submit_form_v1(text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_form_v1(text, text, jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.submit_form_v1(text, text, jsonb) TO authenticated;

-- ============================================================
-- DROP interface + helpers (re-run safe within same migration apply-once)
-- ============================================================
DROP FUNCTION IF EXISTS public._intake_merge_assumptions_compute_mao(jsonb);
DROP FUNCTION IF EXISTS public.promote_draft_deal_v1(uuid, jsonb);
DROP FUNCTION IF EXISTS public.create_deal_from_intake_v1(jsonb);
DROP FUNCTION IF EXISTS public._intake_apply_mao_to_assumptions_v1(jsonb);
DROP FUNCTION IF EXISTS public._intake_validate_deal_property_jsonb_v1(jsonb);
DROP FUNCTION IF EXISTS public._intake_validate_pricing_assumptions_v1(jsonb);

-- ============================================================
-- Internal: validate pricing keys — NULL = OK; else error message (no silent swallow)
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
    v_raw := trim(p_assumptions->>'arv');
    IF v_raw !~ '^\d+(\.\d+)?$' THEN
      RETURN 'arv must be a valid non-negative number';
    END IF;
    v_num := v_raw::numeric;
    IF v_num < 0 THEN
      RETURN 'arv must be non-negative';
    END IF;
  END IF;

  IF p_assumptions ? 'ask_price' AND p_assumptions->>'ask_price' IS NOT NULL AND trim(p_assumptions->>'ask_price') <> '' THEN
    v_raw := trim(p_assumptions->>'ask_price');
    IF v_raw !~ '^\d+(\.\d+)?$' THEN
      RETURN 'ask_price must be a valid number';
    END IF;
  END IF;

  IF p_assumptions ? 'repair_estimate' AND p_assumptions->>'repair_estimate' IS NOT NULL AND trim(p_assumptions->>'repair_estimate') <> '' THEN
    v_raw := trim(p_assumptions->>'repair_estimate');
    IF v_raw !~ '^\d+(\.\d+)?$' THEN
      RETURN 'repair_estimate must be a valid non-negative number';
    END IF;
    v_num := v_raw::numeric;
    IF v_num < 0 THEN
      RETURN 'repair_estimate must be non-negative';
    END IF;
  END IF;

  IF p_assumptions ? 'assignment_fee' AND p_assumptions->>'assignment_fee' IS NOT NULL AND trim(p_assumptions->>'assignment_fee') <> '' THEN
    v_raw := trim(p_assumptions->>'assignment_fee');
    IF v_raw !~ '^\d+(\.\d+)?$' THEN
      RETURN 'assignment_fee must be a valid number';
    END IF;
    v_num := v_raw::numeric;
    IF v_num < 0 THEN
      RETURN 'assignment_fee must be non-negative';
    END IF;
  END IF;

  IF p_assumptions ? 'multiplier' AND p_assumptions->>'multiplier' IS NOT NULL AND trim(p_assumptions->>'multiplier') <> '' THEN
    v_raw := trim(p_assumptions->>'multiplier');
    IF v_raw !~ '^\d+(\.\d+)?$' THEN
      RETURN 'multiplier must be a valid number';
    END IF;
    v_num := v_raw::numeric;
    IF v_num <= 0 OR v_num > 1 THEN
      RETURN 'multiplier must be between 0 and 1 exclusive';
    END IF;
  END IF;

  RETURN NULL;
END;
$v$;

ALTER FUNCTION public._intake_validate_pricing_assumptions_v1(jsonb) OWNER TO postgres;
REVOKE ALL ON FUNCTION public._intake_validate_pricing_assumptions_v1(jsonb) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- Internal: apply MAO after validation only (no broad EXCEPTION)
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
-- Internal: validate deal_properties jsonb typed fields
-- ============================================================
CREATE FUNCTION public._intake_validate_deal_property_jsonb_v1(p_property jsonb)
RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $vp$
DECLARE
  v_raw text;
BEGIN
  IF p_property IS NULL OR p_property = '{}'::jsonb THEN
    RETURN NULL;
  END IF;

  IF p_property ? 'deficiency_tags' AND jsonb_typeof(p_property->'deficiency_tags') <> 'array' THEN
    RETURN 'deficiency_tags must be a JSON array';
  END IF;

  IF p_property ? 'year_built' AND p_property->>'year_built' IS NOT NULL AND trim(p_property->>'year_built') <> '' THEN
    v_raw := trim(p_property->>'year_built');
    IF v_raw !~ '^\d+$' THEN
      RETURN 'year_built must be a valid integer';
    END IF;
    PERFORM v_raw::integer;
  END IF;

  IF p_property ? 'repair_estimate' AND p_property->>'repair_estimate' IS NOT NULL AND trim(p_property->>'repair_estimate') <> '' THEN
    v_raw := trim(p_property->>'repair_estimate');
    IF v_raw !~ '^\d+(\.\d+)?$' THEN
      RETURN 'repair_estimate (property) must be a valid number';
    END IF;
  END IF;

  IF p_property ? 'roof_age' AND p_property->>'roof_age' IS NOT NULL AND trim(p_property->>'roof_age') <> '' THEN
    IF trim(p_property->>'roof_age') !~ '^\d+$' THEN
      RETURN 'roof_age must be a valid integer';
    END IF;
    PERFORM (trim(p_property->>'roof_age'))::integer;
  END IF;

  IF p_property ? 'furnace_age' AND p_property->>'furnace_age' IS NOT NULL AND trim(p_property->>'furnace_age') <> '' THEN
    IF trim(p_property->>'furnace_age') !~ '^\d+$' THEN
      RETURN 'furnace_age must be a valid integer';
    END IF;
    PERFORM (trim(p_property->>'furnace_age'))::integer;
  END IF;

  IF p_property ? 'ac_age' AND p_property->>'ac_age' IS NOT NULL AND trim(p_property->>'ac_age') <> '' THEN
    IF trim(p_property->>'ac_age') !~ '^\d+$' THEN
      RETURN 'ac_age must be a valid integer';
    END IF;
    PERFORM (trim(p_property->>'ac_age'))::integer;
  END IF;

  RETURN NULL;
END;
$vp$;

ALTER FUNCTION public._intake_validate_deal_property_jsonb_v1(jsonb) OWNER TO postgres;
REVOKE ALL ON FUNCTION public._intake_validate_deal_property_jsonb_v1(jsonb) FROM PUBLIC, anon, authenticated;

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

  v_err := public._intake_validate_pricing_assumptions_v1(COALESCE(p_fields->'assumptions', '{}'::jsonb));
  IF v_err IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', v_err, 'fields', '{}'::jsonb)
    );
  END IF;

  v_id := gen_random_uuid();
  v_snapshot_id := gen_random_uuid();
  v_asm := public._intake_apply_mao_to_assumptions_v1(COALESCE(p_fields->'assumptions', '{}'::jsonb));

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
  v_ask_num     numeric;
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
    v_err := public._intake_validate_pricing_assumptions_v1(
      jsonb_build_object('ask_price', trim(d.payload->>'asking_price'))
    );
    IF v_err IS NOT NULL THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'draft payload asking_price: ' || v_err, 'fields', '{}'::jsonb)
      );
    END IF;
    v_ask_num := (trim(d.payload->>'asking_price'))::numeric;
    v_asm := v_asm || jsonb_build_object('ask_price', v_ask_num);
  END IF;

  v_asm := v_asm || COALESCE(v_pf->'assumptions', '{}'::jsonb);

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
