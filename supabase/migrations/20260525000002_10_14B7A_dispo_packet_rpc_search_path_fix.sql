-- 10.14B7A: Corrective Migration -- Dispo Packet RPC Search Path Fix
-- 10.14B7 original migration used SET search_path TO 'public' (quoted, with TO keyword)
-- on lookup_share_token_public_v1. This non-standard syntax causes silent failure during
-- supabase db reset -- migration is recorded as applied but function does not land in pg_proc.
-- This forward corrective recreates both 10.14B7 RPCs with project-standard syntax:
--   SET search_path = public
-- Original 10.14B7 migration is not modified. Function bodies are unchanged.

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
    'dispo_market_value_estimate', 'dispo_below_market_override'
  ];
  v_key          text;
  v_num          numeric;
  v_date         date;
  v_url          text;
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

  IF p_fields ? 'dispo_closing_date' AND p_fields->>'dispo_closing_date' IS NOT NULL AND trim(p_fields->>'dispo_closing_date') <> '' THEN
    BEGIN
      v_date := (p_fields->>'dispo_closing_date')::date;
    EXCEPTION WHEN OTHERS THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
        'error', json_build_object('message', 'dispo_closing_date must be a valid date (YYYY-MM-DD)', 'fields', json_build_object()));
    END;
  END IF;

  IF p_fields ? 'dispo_media_url' AND p_fields->>'dispo_media_url' IS NOT NULL AND trim(p_fields->>'dispo_media_url') <> '' THEN
    v_url := trim(p_fields->>'dispo_media_url');
    IF NOT (v_url ~* '^https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(:[0-9]+)?(/.*)?$') THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
        'error', json_build_object('message', 'dispo_media_url must be a valid https:// URL or empty', 'fields', json_build_object()));
    END IF;
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

REVOKE EXECUTE ON FUNCTION public.update_dispo_packet_v1(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_dispo_packet_v1(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.lookup_share_token_public_v1(p_token text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_hash       bytea;
  v_row        record;
  v_result     json;
  v_sub_status text;
  v_period_end timestamptz;
BEGIN
  IF p_token IS NULL OR length(p_token) < 68 OR left(p_token, 4) <> 'shr_'
     OR substring(p_token FROM 5) !~ '^[0-9a-f]{64}$'
  THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', null, 'success', false, 'failure_category', 'format_invalid')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found', 'fields', json_build_object()));
  END IF;

  v_hash := extensions.digest(p_token, 'sha256');

  SELECT st.deal_id, st.tenant_id, st.expires_at, st.revoked_at,
         d.dispo_asking_price, d.dispo_intersection, d.dispo_closing_date,
         d.dispo_description, d.dispo_comparables, d.dispo_media_url,
         d.dispo_market_value_estimate, d.dispo_below_market_override,
         COALESCE(
           d.dispo_below_market_override,
           CASE WHEN d.dispo_market_value_estimate IS NOT NULL AND d.dispo_asking_price IS NOT NULL
                THEN d.dispo_market_value_estimate - d.dispo_asking_price
                ELSE NULL END
         ) AS dispo_below_market_value
  INTO v_row
  FROM public.share_tokens st
  JOIN public.deals d ON d.id = st.deal_id AND d.tenant_id = st.tenant_id
  WHERE st.token_hash = v_hash;

  IF NOT FOUND THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'not_found')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found', 'fields', json_build_object()));
  END IF;

  IF v_row.revoked_at IS NOT NULL THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'revoked')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found', 'fields', json_build_object()));
  END IF;

  IF v_row.expires_at <= now() THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'expired')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found', 'fields', json_build_object()));
  END IF;

  SELECT ts.status, ts.current_period_end INTO v_sub_status, v_period_end
  FROM public.tenant_subscriptions ts WHERE ts.tenant_id = v_row.tenant_id;
  IF NOT FOUND OR v_sub_status = 'canceled' OR v_period_end <= now() THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'workspace_expired')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found', 'fields', json_build_object()));
  END IF;

  v_result := json_build_object('ok', true, 'code', 'OK',
    'data', json_build_object(
      'expires_at',                  v_row.expires_at,
      'dispo_asking_price',          v_row.dispo_asking_price,
      'dispo_intersection',          v_row.dispo_intersection,
      'dispo_closing_date',          v_row.dispo_closing_date,
      'dispo_description',           v_row.dispo_description,
      'dispo_comparables',           v_row.dispo_comparables,
      'dispo_media_url',             v_row.dispo_media_url,
      'dispo_market_value_estimate', v_row.dispo_market_value_estimate,
      'dispo_below_market_override', v_row.dispo_below_market_override,
      'dispo_below_market_value',    v_row.dispo_below_market_value
    ),
    'error', null);

  BEGIN
    PERFORM public.foundation_log_activity_v1('share_token_lookup',
      json_build_object('token_hash', encode(v_hash, 'hex'), 'success', true, 'failure_category', null)::jsonb, null);
  EXCEPTION WHEN OTHERS THEN NULL; END;

  RETURN v_result;
END;
$fn$;

REVOKE ALL ON FUNCTION public.lookup_share_token_public_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lookup_share_token_public_v1(text) TO anon;
GRANT EXECUTE ON FUNCTION public.lookup_share_token_public_v1(text) TO authenticated;