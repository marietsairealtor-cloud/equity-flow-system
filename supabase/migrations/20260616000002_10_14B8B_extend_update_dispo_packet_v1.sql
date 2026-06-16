-- 10.14B8B -- Dispo Backend -- Expanded Share Packet Fields
-- Migration 2 of 3: Extend update_dispo_packet_v1 to support 7 new fields.
-- Guard pattern and envelope preserved byte-for-byte from B7B approved body.
-- Grants unchanged -- follow in original 20260526000002.

CREATE OR REPLACE FUNCTION public.update_dispo_packet_v1(
  p_deal_id uuid,
  p_fields  jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant       uuid;
  v_user         uuid;
  v_stage        text;
  v_allowed_keys text[] := ARRAY[
    'dispo_asking_price', 'dispo_intersection', 'dispo_closing_date',
    'dispo_description', 'dispo_comparables', 'dispo_media_url',
    'dispo_market_value_estimate', 'dispo_below_market_override',
    'dispo_headline', 'dispo_tagline', 'dispo_offer_deadline',
    'dispo_walkthrough', 'dispo_features',
    'dispo_contact_name', 'dispo_contact_phone'
  ];
  v_key          text;
  v_num          numeric;
  v_date         date;
  v_url          text;
  v_ts           timestamptz;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant or user context', 'fields', json_build_object()));
  END IF;

  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object()));
  END;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object('ok', false, 'code', 'WORKSPACE_NOT_WRITABLE', 'data', json_build_object(),
      'error', json_build_object('message', 'Workspace is not active', 'fields', json_build_object()));
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'p_deal_id is required', 'fields', json_build_object()));
  END IF;

  IF p_fields IS NULL OR jsonb_typeof(p_fields) <> 'object' OR p_fields = '{}'::jsonb THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'p_fields must be a non-empty JSON object', 'fields', json_build_object()));
  END IF;

  FOR v_key IN SELECT jsonb_object_keys(p_fields) LOOP
    IF NOT (v_key = ANY(v_allowed_keys)) THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
        'error', json_build_object('message', 'Unknown field: ' || v_key, 'fields', json_build_object()));
    END IF;
  END LOOP;

  -- Numeric field validation (existing)
  IF p_fields ? 'dispo_asking_price' AND p_fields->>'dispo_asking_price' IS NOT NULL AND trim(p_fields->>'dispo_asking_price') <> '' THEN
    BEGIN
      v_num := (p_fields->>'dispo_asking_price')::numeric;
    EXCEPTION WHEN OTHERS THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
        'error', json_build_object('message', 'dispo_asking_price must be a valid number', 'fields', json_build_object()));
    END;
  END IF;

  IF p_fields ? 'dispo_market_value_estimate' AND p_fields->>'dispo_market_value_estimate' IS NOT NULL AND trim(p_fields->>'dispo_market_value_estimate') <> '' THEN
    BEGIN
      v_num := (p_fields->>'dispo_market_value_estimate')::numeric;
    EXCEPTION WHEN OTHERS THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
        'error', json_build_object('message', 'dispo_market_value_estimate must be a valid number', 'fields', json_build_object()));
    END;
  END IF;

  IF p_fields ? 'dispo_below_market_override' AND p_fields->>'dispo_below_market_override' IS NOT NULL AND trim(p_fields->>'dispo_below_market_override') <> '' THEN
    BEGIN
      v_num := (p_fields->>'dispo_below_market_override')::numeric;
    EXCEPTION WHEN OTHERS THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
        'error', json_build_object('message', 'dispo_below_market_override must be a valid number', 'fields', json_build_object()));
    END;
  END IF;

  -- Date field validation (existing)
  IF p_fields ? 'dispo_closing_date' AND p_fields->>'dispo_closing_date' IS NOT NULL AND trim(p_fields->>'dispo_closing_date') <> '' THEN
    BEGIN
      v_date := (p_fields->>'dispo_closing_date')::date;
    EXCEPTION WHEN OTHERS THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
        'error', json_build_object('message', 'dispo_closing_date must be a valid date (YYYY-MM-DD)', 'fields', json_build_object()));
    END;
  END IF;

  -- URL validation (existing)
  IF p_fields ? 'dispo_media_url' AND p_fields->>'dispo_media_url' IS NOT NULL AND trim(p_fields->>'dispo_media_url') <> '' THEN
    v_url := trim(p_fields->>'dispo_media_url');
    IF NOT (v_url ~* '^https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(:[0-9]+)?(/.*)?$') THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
        'error', json_build_object('message', 'dispo_media_url must be a valid https:// URL or empty', 'fields', json_build_object()));
    END IF;
  END IF;

  -- B8B: offer deadline validation (timestamptz)
  IF p_fields ? 'dispo_offer_deadline' AND p_fields->>'dispo_offer_deadline' IS NOT NULL AND trim(p_fields->>'dispo_offer_deadline') <> '' THEN
    BEGIN
      v_ts := (p_fields->>'dispo_offer_deadline')::timestamptz;
    EXCEPTION WHEN OTHERS THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
        'error', json_build_object('message', 'dispo_offer_deadline must be a valid timestamp', 'fields', json_build_object()));
    END;
  END IF;

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object()));
  END IF;

  IF v_stage NOT IN ('dispo', 'under_contract') THEN
    RETURN json_build_object('ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Dispo packet fields can only be edited on dispo or under_contract deals', 'fields', json_build_object()));
  END IF;

  UPDATE public.deals SET
    -- Existing fields (unchanged)
    dispo_asking_price          = CASE WHEN p_fields ? 'dispo_asking_price'
                                       THEN CASE WHEN p_fields->>'dispo_asking_price' IS NULL OR trim(p_fields->>'dispo_asking_price') = ''
                                                 THEN NULL ELSE (p_fields->>'dispo_asking_price')::numeric END
                                       ELSE dispo_asking_price END,
    dispo_intersection          = CASE WHEN p_fields ? 'dispo_intersection'
                                       THEN NULLIF(trim(p_fields->>'dispo_intersection'), '')
                                       ELSE dispo_intersection END,
    dispo_closing_date          = CASE WHEN p_fields ? 'dispo_closing_date'
                                       THEN CASE WHEN p_fields->>'dispo_closing_date' IS NULL OR trim(p_fields->>'dispo_closing_date') = ''
                                                 THEN NULL ELSE (p_fields->>'dispo_closing_date')::date END
                                       ELSE dispo_closing_date END,
    dispo_description           = CASE WHEN p_fields ? 'dispo_description'
                                       THEN NULLIF(trim(p_fields->>'dispo_description'), '')
                                       ELSE dispo_description END,
    dispo_comparables           = CASE WHEN p_fields ? 'dispo_comparables'
                                       THEN NULLIF(trim(p_fields->>'dispo_comparables'), '')
                                       ELSE dispo_comparables END,
    dispo_media_url             = CASE WHEN p_fields ? 'dispo_media_url'
                                       THEN NULLIF(trim(p_fields->>'dispo_media_url'), '')
                                       ELSE dispo_media_url END,
    dispo_market_value_estimate = CASE WHEN p_fields ? 'dispo_market_value_estimate'
                                       THEN CASE WHEN p_fields->>'dispo_market_value_estimate' IS NULL OR trim(p_fields->>'dispo_market_value_estimate') = ''
                                                 THEN NULL ELSE (p_fields->>'dispo_market_value_estimate')::numeric END
                                       ELSE dispo_market_value_estimate END,
    dispo_below_market_override = CASE WHEN p_fields ? 'dispo_below_market_override'
                                       THEN CASE WHEN p_fields->>'dispo_below_market_override' IS NULL OR trim(p_fields->>'dispo_below_market_override') = ''
                                                 THEN NULL ELSE (p_fields->>'dispo_below_market_override')::numeric END
                                       ELSE dispo_below_market_override END,
    -- B8B: new fields
    dispo_headline              = CASE WHEN p_fields ? 'dispo_headline'
                                       THEN NULLIF(trim(p_fields->>'dispo_headline'), '')
                                       ELSE dispo_headline END,
    dispo_tagline               = CASE WHEN p_fields ? 'dispo_tagline'
                                       THEN NULLIF(trim(p_fields->>'dispo_tagline'), '')
                                       ELSE dispo_tagline END,
    dispo_offer_deadline        = CASE WHEN p_fields ? 'dispo_offer_deadline'
                                       THEN CASE WHEN p_fields->>'dispo_offer_deadline' IS NULL OR trim(p_fields->>'dispo_offer_deadline') = ''
                                                 THEN NULL ELSE (p_fields->>'dispo_offer_deadline')::timestamptz END
                                       ELSE dispo_offer_deadline END,
    dispo_walkthrough           = CASE WHEN p_fields ? 'dispo_walkthrough'
                                       THEN NULLIF(trim(p_fields->>'dispo_walkthrough'), '')
                                       ELSE dispo_walkthrough END,
    dispo_features              = CASE WHEN p_fields ? 'dispo_features'
                                       THEN NULLIF(trim(p_fields->>'dispo_features'), '')
                                       ELSE dispo_features END,
    dispo_contact_name          = CASE WHEN p_fields ? 'dispo_contact_name'
                                       THEN NULLIF(trim(p_fields->>'dispo_contact_name'), '')
                                       ELSE dispo_contact_name END,
    dispo_contact_phone         = CASE WHEN p_fields ? 'dispo_contact_phone'
                                       THEN NULLIF(trim(p_fields->>'dispo_contact_phone'), '')
                                       ELSE dispo_contact_phone END,
    updated_at                  = now(),
    row_version                 = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  INSERT INTO public.deal_activity_log (tenant_id, deal_id, activity_type, content, created_by, created_at)
  VALUES (v_tenant, p_deal_id, 'packet_update', 'Dispo packet fields updated', v_user, now());

  RETURN json_build_object('ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id),
    'error', null);
END;
$fn$;
