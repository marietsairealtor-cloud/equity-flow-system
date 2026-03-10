-- 20260310000001_8_9_share_token_expiration_invariant.sql
-- 8.9: Make expires_at NOT NULL on share_tokens.
-- All tokens must include expiration. Lookup RPC enforces expires_at > now().
-- Expired tokens return NOT_FOUND (same shape as invalid tokens — no existence leak).
-- Revocation check still occurs before expiration check.

-- Step 1: Backfill any NULL expires_at with 30 days from now (safety net)
UPDATE public.share_tokens
SET expires_at = now() + interval '30 days'
WHERE expires_at IS NULL;

-- Step 2: Make expires_at NOT NULL
ALTER TABLE public.share_tokens
  ALTER COLUMN expires_at SET NOT NULL;

-- Step 3: Update create_share_token_v1 — p_expires_at now required (no default)
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

-- Step 4: Update lookup_share_token_v1 — expired tokens return NOT_FOUND
-- (same shape as invalid tokens, no existence leak)
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
  -- Expiration check — returns NOT_FOUND (no existence leak)
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
