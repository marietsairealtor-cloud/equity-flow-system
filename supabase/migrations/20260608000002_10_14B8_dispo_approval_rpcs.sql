-- 10.14B8 — Dispo Backend — Share Packet Photo Visibility
-- Migration 2 of 2: RPCs
--   (a) update_deal_media_dispo_approval_v1  — new governed mutation
--   (b) lookup_share_token_public_v1         — extend B7B body to add approved media
-- Grants follow in 20260608000003.

-- ============================================================
-- RPC: update_deal_media_dispo_approval_v1(p_media_id uuid, p_is_dispo_approved boolean)
-- Guard pattern mirrors approved B7B update_dispo_packet_v1.
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_deal_media_dispo_approval_v1(
  p_media_id          uuid,
  p_is_dispo_approved boolean
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
  v_user   uuid;
  v_media  record;
BEGIN
  -- Null input validation
  IF p_media_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'p_media_id is required', 'fields', json_build_object()));
  END IF;

  IF p_is_dispo_approved IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'p_is_dispo_approved is required', 'fields', json_build_object()));
  END IF;

  -- Tenant + user context
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant or user context', 'fields', json_build_object()));
  END IF;

  -- Role guard
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object()));
  END;

  -- Workspace write lock
  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object('ok', false, 'code', 'WORKSPACE_NOT_WRITABLE', 'data', json_build_object(),
      'error', json_build_object('message', 'Workspace is not active', 'fields', json_build_object()));
  END IF;

  -- Resolve media — must belong to a deal in this tenant
  SELECT dm.*
    INTO v_media
    FROM public.deal_media dm
    JOIN public.deals d ON d.id = dm.deal_id AND d.tenant_id = v_tenant
   WHERE dm.id = p_media_id
     AND dm.tenant_id = v_tenant;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Media not found', 'fields', json_build_object()));
  END IF;

  -- Apply approval or removal
  IF p_is_dispo_approved THEN
    UPDATE public.deal_media
       SET is_dispo_approved = true,
           dispo_approved_at = now(),
           dispo_approved_by = v_user
     WHERE id = p_media_id;
  ELSE
    UPDATE public.deal_media
       SET is_dispo_approved = false,
           dispo_approved_at = NULL,
           dispo_approved_by = NULL
     WHERE id = p_media_id;
  END IF;

  RETURN json_build_object('ok', true, 'code', 'OK',
    'data', json_build_object('media_id', p_media_id),
    'error', null);
END;
$fn$;

-- ============================================================
-- RPC: lookup_share_token_public_v1(p_token text)
-- Extends approved B7B body. Only change: add approved media
-- to the JOIN and return it under data.media.
-- All token validation, hash logic, failure envelopes, tenant
-- checks, and logging are preserved byte-for-byte from B7B.
-- ============================================================

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
  v_media      json;
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

  -- B8 extension: load approved media only — public-safe metadata
  SELECT COALESCE(
    json_agg(
      json_build_object(
        'media_id',     dm.id,
        'storage_path', dm.storage_path,
        'sort_order',   dm.sort_order,
        'updated_at',   dm.updated_at
      )
      ORDER BY dm.sort_order ASC NULLS LAST, dm.updated_at ASC
    ),
    '[]'::json
  )
  INTO v_media
  FROM public.deal_media dm
  WHERE dm.tenant_id = v_row.tenant_id
    AND dm.deal_id = v_row.deal_id
    AND dm.is_dispo_approved = true;

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
      'dispo_below_market_value',    v_row.dispo_below_market_value,
      'media',                       v_media
    ),
    'error', null);

  BEGIN
    PERFORM public.foundation_log_activity_v1('share_token_lookup',
      json_build_object('token_hash', encode(v_hash, 'hex'), 'success', true, 'failure_category', null)::jsonb, null);
  EXCEPTION WHEN OTHERS THEN NULL; END;

  RETURN v_result;
END;
$fn$;
