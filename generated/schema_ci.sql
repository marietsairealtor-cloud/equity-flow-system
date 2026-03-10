-- 20260310000002_8_9_fix_comment_encoding.sql
-- Corrective: re-create lookup_share_token_v1 with ASCII-safe comments.

-- Corrective: re-create lookup_share_token_v1 - expired tokens return NOT_FOUND (no existence leak)

DROP FUNCTION IF EXISTS public.lookup_share_token_v1(text);
CREATE FUNCTION public.lookup_share_token_v1(
  p_token text
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
  IF p_token IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'token is required', 'fields', json_build_object())
    );
  END IF;
  v_hash := extensions.digest(p_token, 'sha256');
  SELECT st.deal_id, st.expires_at, st.revoked_at, d.calc_version
  INTO v_row
  FROM public.share_tokens st
  JOIN public.deals d ON d.id = st.deal_id AND d.tenant_id = st.tenant_id
  WHERE st.token_hash = v_hash
    AND st.tenant_id = v_tenant_id;
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
  -- Revocation check first (overrides expiration)
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
  -- Expiration check - returns NOT_FOUND (no existence leak)
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
GRANT EXECUTE ON FUNCTION public.lookup_share_token_v1(text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.lookup_share_token_v1(text) FROM anon, PUBLIC;

