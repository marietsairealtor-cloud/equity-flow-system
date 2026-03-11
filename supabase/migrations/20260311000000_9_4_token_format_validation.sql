-- 20260311000000_9_4_token_format_validation.sql
-- 9.4: RPC Token Format Validation
-- Enforce token format before hashing in lookup_share_token_v1.
-- Validation rules (all checked before digest() is called):
--   1. Token must begin with prefix 'shr_'
--   2. Token body after prefix must be exactly 64 lowercase hex chars
--   3. Total length must be >= 68
-- Invalid format returns NOT_FOUND - identical shape to nonexistent token (no format leak).
-- Signature unchanged: lookup_share_token_v1(p_token text, p_deal_id uuid)
-- Internal logic change only - DROP+CREATE required per CONTRACTS.md S2.

DROP FUNCTION IF EXISTS public.lookup_share_token_v1(text, uuid);

CREATE FUNCTION public.lookup_share_token_v1(
  p_token   text,
  p_deal_id uuid
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_row       record;
  v_hash      bytea;
  v_result    json;
BEGIN
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;
  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'deal_id is required', 'fields', json_build_object())
    );
  END IF;
  -- 9.4: Format validation - occurs BEFORE hashing.
  -- Rule 1: prefix must be 'shr_'
  -- Rule 2: body after prefix must be exactly 64 lowercase hex chars
  -- Rule 3: total length >= 68
  -- Returns NOT_FOUND - identical shape to nonexistent token (no format leak).
  IF p_token IS NULL
     OR length(p_token) < 68
     OR left(p_token, 4) <> 'shr_'
     OR substring(p_token FROM 5) !~ '^[0-9a-f]{64}$'
  THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1(
        'share_token_lookup',
        json_build_object('token_hash', null, 'success', false, 'failure_category', 'format_invalid')::jsonb,
        null
      );
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object())
    );
  END IF;
  v_hash := extensions.digest(p_token, 'sha256');
  SELECT st.deal_id, st.expires_at, st.revoked_at, d.calc_version
  INTO v_row
  FROM public.share_tokens st
  JOIN public.deals d ON d.id = st.deal_id AND d.tenant_id = st.tenant_id
  WHERE st.token_hash = v_hash
    AND st.tenant_id  = v_tenant_id
    AND st.deal_id    = p_deal_id;
  IF NOT FOUND THEN
    v_result := json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object())
    );
    BEGIN
      PERFORM public.foundation_log_activity_v1(
        'share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'not_found')::jsonb,
        null
      );
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN v_result;
  END IF;
  -- Revocation check first (overrides expiration per 8.6)
  IF v_row.revoked_at IS NOT NULL THEN
    v_result := json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object())
    );
    BEGIN
      PERFORM public.foundation_log_activity_v1(
        'share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'revoked')::jsonb,
        null
      );
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN v_result;
  END IF;
  -- Expiration check - returns NOT_FOUND (no existence leak per 8.9)
  IF v_row.expires_at <= now() THEN
    v_result := json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object())
    );
    BEGIN
      PERFORM public.foundation_log_activity_v1(
        'share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'expired')::jsonb,
        null
      );
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN v_result;
  END IF;
  v_result := json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object(
      'deal_id',      v_row.deal_id,
      'calc_version', v_row.calc_version,
      'expires_at',   v_row.expires_at
    ),
    'error', null
  );
  BEGIN
    PERFORM public.foundation_log_activity_v1(
      'share_token_lookup',
      json_build_object('token_hash', encode(v_hash, 'hex'), 'success', true, 'failure_category', null)::jsonb,
      null
    );
  EXCEPTION WHEN OTHERS THEN NULL; END;
  RETURN v_result;
END;
$fn$;
GRANT EXECUTE ON FUNCTION public.lookup_share_token_v1(text, uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.lookup_share_token_v1(text, uuid) FROM anon, PUBLIC;