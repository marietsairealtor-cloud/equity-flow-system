-- 20260310000000_8_8_share_token_secure_generation.sql
-- 8.8: Share token secure generation contract.
-- Tokens use gen_random_bytes(32) — 256 bits entropy (>= 128 bit minimum).
-- Token format: shr_ prefix + 64 hex chars = 68 chars minimum.
-- Full token including prefix is hashed before storage.
-- Raw token returned to caller only at creation time — never persisted.

CREATE FUNCTION public.create_share_token_v1(
  p_deal_id  uuid,
  p_expires_at timestamptz DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_token     text;
  v_hash      bytea;
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
  -- Verify deal belongs to tenant
  IF NOT EXISTS (
    SELECT 1 FROM public.deals
    WHERE id = p_deal_id AND tenant_id = v_tenant_id
  ) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;
  -- Generate token: shr_ prefix + 32 random bytes as hex (256 bits entropy)
  v_token := 'shr_' || encode(extensions.gen_random_bytes(32), 'hex');
  -- Hash full token including prefix before storage
  v_hash := extensions.digest(v_token, 'sha256');
  INSERT INTO public.share_tokens (tenant_id, deal_id, token_hash, expires_at)
  VALUES (v_tenant_id, p_deal_id, v_hash, p_expires_at);
  -- Return raw token to caller — only time it is ever seen in plaintext
  RETURN json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object(
      'token',      v_token,
      'expires_at', p_expires_at
    ),
    'error', null
  );
END;
$fn$;
GRANT EXECUTE ON FUNCTION public.create_share_token_v1(uuid, timestamptz) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.create_share_token_v1(uuid, timestamptz) FROM anon, PUBLIC;
