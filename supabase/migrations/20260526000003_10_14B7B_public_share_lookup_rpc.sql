-- 10.14B7B: Forward repair -- lookup_share_token_public_v1 RPC
-- Recreates lookup_share_token_public_v1 as a standalone single-statement migration.
-- Grants follow in 20260526000004.

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
