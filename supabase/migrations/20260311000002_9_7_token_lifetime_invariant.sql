-- 20260311000002_9_7_token_lifetime_invariant.sql
-- 9.7: Share Token Maximum Lifetime Invariant
-- Enforces expires_at <= now() + interval '90 days' in create_share_token_v1.
-- Violations return VALIDATION_ERROR with field-level error on expires_at.
-- Signature unchanged: create_share_token_v1(p_deal_id uuid, p_expires_at timestamptz)
-- Internal logic change only - DROP+CREATE required per CONTRACTS.md S2.

DROP FUNCTION IF EXISTS public.create_share_token_v1(uuid, timestamptz);

CREATE FUNCTION public.create_share_token_v1(
  p_deal_id    uuid,
  p_expires_at timestamptz
)
RETURNS json
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id    uuid;
  v_token        text;
  v_hash         bytea;
  v_active_count int;
  v_max_tokens   constant int := 50;
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
  IF p_expires_at IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'expires_at is required', 'fields', json_build_object())
    );
  END IF;
  IF p_expires_at <= now() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'expires_at must be in the future', 'fields', json_build_object())
    );
  END IF;
  -- 9.7: Maximum lifetime invariant - tokens cannot exceed 90 days
  IF p_expires_at > now() + interval '90 days' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object(
        'message', 'expires_at exceeds maximum allowed lifetime of 90 days',
        'fields', json_build_object('expires_at', 'Maximum token lifetime is 90 days')
      )
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
  -- 9.5: Cardinality guard - count active tokens for this deal
  SELECT count(*)::int
  INTO v_active_count
  FROM public.share_tokens
  WHERE deal_id   = p_deal_id
    AND tenant_id = v_tenant_id
    AND revoked_at IS NULL
    AND expires_at > now();
  IF v_active_count >= v_max_tokens THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', null,
      'error', json_build_object(
        'message', 'Active token limit reached for this resource',
        'fields', json_build_object()
      )
    );
  END IF;
  -- Generate token: shr_ prefix + 32 random bytes as hex (256 bits entropy)
  v_token := 'shr_' || encode(extensions.gen_random_bytes(32), 'hex');
  v_hash  := extensions.digest(v_token, 'sha256');
  INSERT INTO public.share_tokens (tenant_id, deal_id, token_hash, expires_at)
  VALUES (v_tenant_id, p_deal_id, v_hash, p_expires_at);
  -- Return raw token to caller - only time it is ever seen in plaintext
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