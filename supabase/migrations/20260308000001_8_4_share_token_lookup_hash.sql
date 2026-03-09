-- 8.4: Update lookup_share_token_v1 to hash input before comparison.
-- Per CONTRACTS.md S2: DROP + CREATE for signature/return changes.
-- The signature is unchanged (p_token text) but the internal logic changes.

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

  -- Hash the input token before comparison
  v_hash := extensions.digest(p_token, 'sha256');

  SELECT st.deal_id, st.expires_at, d.calc_version
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
REVOKE EXECUTE ON FUNCTION public.lookup_share_token_v1(text) FROM anon;

-- Update share_token_packet view (no longer has raw token)
DROP VIEW IF EXISTS public.share_token_packet;
CREATE VIEW public.share_token_packet AS
  SELECT
    st.deal_id,
    st.expires_at,
    d.calc_version
  FROM public.share_tokens st
  JOIN public.deals d ON d.id = st.deal_id AND d.tenant_id = st.tenant_id;