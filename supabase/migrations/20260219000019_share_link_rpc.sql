-- 20260219000019_share_link_rpc.sql
-- 6.7: lookup_share_token_v1 — tenant-scoped token lookup.
-- WHERE clause includes BOTH token = p_token AND tenant_id = p_tenant_id.
-- Returns TOKEN_EXPIRED for expired tokens (distinct from NOT_FOUND).
-- SECURITY DEFINER + tenant binding per CONTRACTS.md S3, S7, S8, S12.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No double-dollar tags.

CREATE FUNCTION public.lookup_share_token_v1(
  p_tenant_id uuid,
  p_token     text
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_row record;
BEGIN
  -- Validate caller context matches requested tenant (satisfies definer-safety-audit)
  IF p_tenant_id IS NULL OR p_token IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  null,
      'error', json_build_object('message', 'tenant_id and token are required', 'fields', json_build_object())
    );
  END IF;

  -- Enforce: caller must have context for requested tenant
  IF public.current_tenant_id() IS DISTINCT FROM p_tenant_id THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'Tenant context mismatch', 'fields', json_build_object())
    );
  END IF;

  SELECT st.token, st.deal_id, st.expires_at, d.calc_version
  INTO v_row
  FROM public.share_tokens st
  JOIN public.deals d ON d.id = st.deal_id AND d.tenant_id = st.tenant_id
  WHERE st.token = p_token
    AND st.tenant_id = p_tenant_id;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  null,
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object())
    );
  END IF;

  IF v_row.expires_at IS NOT NULL AND v_row.expires_at < now() THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'TOKEN_EXPIRED',
      'data',  null,
      'error', json_build_object('message', 'Share token has expired', 'fields', json_build_object())
    );
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'token',        v_row.token,
      'deal_id',      v_row.deal_id,
      'calc_version', v_row.calc_version,
      'expires_at',   v_row.expires_at
    ),
    'error', null
  );
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.lookup_share_token_v1(uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.lookup_share_token_v1(uuid, text) FROM anon;
