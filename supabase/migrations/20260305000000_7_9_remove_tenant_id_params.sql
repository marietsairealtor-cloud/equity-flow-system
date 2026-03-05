-- 7.9: Remove p_tenant_id caller input from RPCs.
-- Tenant ID must be derived strictly from JWT via current_tenant_id().
-- No RPC may accept tenant_id as caller input.

-- Drop old signatures
DROP FUNCTION IF EXISTS public.foundation_log_activity_v1(uuid, text, jsonb, uuid);
DROP FUNCTION IF EXISTS public.lookup_share_token_v1(uuid, text);

-- Recreate foundation_log_activity_v1 without p_tenant_id
CREATE OR REPLACE FUNCTION public.foundation_log_activity_v1(
  p_action   text,
  p_meta     jsonb    DEFAULT '{}'::jsonb,
  p_actor_id uuid     DEFAULT NULL::uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_id        uuid;
BEGIN
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;
  IF p_action IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'action is required', 'fields', json_build_object())
    );
  END IF;
  v_id := gen_random_uuid();
  INSERT INTO public.activity_log (id, tenant_id, actor_id, action, meta)
  VALUES (v_id, v_tenant_id, p_actor_id, p_action, p_meta);
  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('id', v_id),
    'error', null
  );
END;
$fn$;

-- Recreate lookup_share_token_v1 without p_tenant_id
CREATE OR REPLACE FUNCTION public.lookup_share_token_v1(
  p_token text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_row       record;
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
  SELECT st.token, st.deal_id, st.expires_at, d.calc_version
  INTO v_row
  FROM public.share_tokens st
  JOIN public.deals d ON d.id = st.deal_id AND d.tenant_id = st.tenant_id
  WHERE st.token = p_token
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
    'ok', true, 'code', 'OK',
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

-- Reapply grants
GRANT EXECUTE ON FUNCTION public.foundation_log_activity_v1(text, jsonb, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_share_token_v1(text) TO authenticated, anon;
REVOKE EXECUTE ON FUNCTION public.foundation_log_activity_v1(text, jsonb, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.lookup_share_token_v1(text) FROM PUBLIC;
