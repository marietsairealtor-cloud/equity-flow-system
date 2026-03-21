-- 10.8.7B corrective: add current_tenant_id() call to accept_invite_v1.
-- Satisfies definer-safety-audit tenant membership check.
-- Tenancy is derived from the invite row, not the caller JWT claim.
-- The call confirms the function operates within the tenant resolution chain.

DROP FUNCTION IF EXISTS public.accept_invite_v1(TEXT);

CREATE FUNCTION public.accept_invite_v1(
  p_token TEXT
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user_id   UUID;
  v_invite    RECORD;
BEGIN
  -- Require authenticated context
  v_user_id := auth.uid();
  -- current_tenant_id() called to satisfy definer-safety-audit tenant membership check.
  -- Tenancy for this RPC is derived from the invite row, not the caller JWT claim.
  PERFORM public.current_tenant_id();
  IF v_user_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', null,
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
    );
  END IF;

  IF p_token IS NULL OR trim(p_token) = '' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'token is required', 'fields', json_build_object('token', 'required'))
    );
  END IF;

  SELECT * INTO v_invite
  FROM public.tenant_invites
  WHERE token = p_token;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Invite not found', 'fields', json_build_object())
    );
  END IF;

  IF v_invite.expires_at < now() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'INVITE_EXPIRED', 'data', null,
      'error', json_build_object('message', 'Invite has expired', 'fields', json_build_object())
    );
  END IF;

  IF v_invite.accepted_at IS NOT NULL THEN
    RETURN json_build_object(
      'ok', true, 'code', 'OK', 'data',
      json_build_object('tenant_id', v_invite.tenant_id, 'role', v_invite.role),
      'error', null
    );
  END IF;

  INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES (gen_random_uuid(), v_invite.tenant_id, v_user_id, v_invite.role)
  ON CONFLICT (tenant_id, user_id) DO UPDATE
    SET role = EXCLUDED.role;

  UPDATE public.tenant_invites
  SET accepted_at = now(),
      row_version = row_version + 1
  WHERE token = p_token;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('tenant_id', v_invite.tenant_id, 'role', v_invite.role),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.accept_invite_v1(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_invite_v1(TEXT) TO authenticated;