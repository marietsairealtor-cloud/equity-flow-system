-- 20260309000000_8_6_share_token_revocation.sql
-- 8.6: Add revoked_at to share_tokens. Update lookup_share_token_v1
-- to enforce revocation. Add revoke_share_token_v1 RPC.
-- Revocation precedence: revoked_at IS NULL AND expires_at > now().
-- Revoked tokens return NOT_FOUND (no existence leak).
-- Revocation is idempotent.

-- Step 1: Add revoked_at column
ALTER TABLE public.share_tokens
  ADD COLUMN revoked_at timestamptz NULL;

-- Step 2: Update lookup_share_token_v1 to enforce revocation
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
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object())
    );
  END IF;
  IF v_row.revoked_at IS NOT NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object())
    );
  END IF;
  IF v_row.expires_at IS NOT NULL AND v_row.expires_at < now() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'TOKEN_EXPIRED', 'data', null,
      'error', json_build_object('message', 'Share token has expired', 'fields', json_build_object())
    );
  END IF;
  RETURN json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object(
      'deal_id',      v_row.deal_id,
      'calc_version', v_row.calc_version,
      'expires_at',   v_row.expires_at
    ),
    'error', null
  );
END;
$fn$;
GRANT EXECUTE ON FUNCTION public.lookup_share_token_v1(text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.lookup_share_token_v1(text) FROM anon, PUBLIC;

-- Step 3: revoke_share_token_v1 RPC
CREATE FUNCTION public.revoke_share_token_v1(
  p_token text
)
RETURNS json
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_hash      bytea;
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
  UPDATE public.share_tokens
  SET revoked_at = now()
  WHERE token_hash = v_hash
    AND tenant_id  = v_tenant_id
    AND revoked_at IS NULL;
  RETURN json_build_object(
    'ok', true, 'code', 'OK', 'data', null, 'error', null
  );
END;
$fn$;
GRANT EXECUTE ON FUNCTION public.revoke_share_token_v1(text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.revoke_share_token_v1(text) FROM anon, PUBLIC;
