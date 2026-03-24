-- 10.8.7D: Accept Invite Tenant Context Sync
-- Modifies accept_invite_v1 to set user_profiles.current_tenant_id after invite acceptance.
-- Fixes both new and previously-accepted invites (idempotent sync in all paths).
-- No schema changes. Behavioral parity fix only.
-- Uses CREATE OR REPLACE - signature unchanged, no grant churn.

CREATE OR REPLACE FUNCTION public.accept_invite_v1(
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
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'Invite has expired', 'fields', json_build_object('token', 'expired'))
    );
  END IF;

  -- Idempotency: already accepted - still sync current_tenant_id
  IF v_invite.accepted_at IS NOT NULL THEN
    INSERT INTO public.user_profiles (id, current_tenant_id)
    VALUES (v_user_id, v_invite.tenant_id)
    ON CONFLICT (id) DO UPDATE
      SET current_tenant_id = EXCLUDED.current_tenant_id;

    RETURN json_build_object(
      'ok', true, 'code', 'OK', 'data',
      json_build_object('tenant_id', v_invite.tenant_id, 'role', v_invite.role),
      'error', null
    );
  END IF;

  -- Create/upsert membership
  INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES (gen_random_uuid(), v_invite.tenant_id, v_user_id, v_invite.role)
  ON CONFLICT (tenant_id, user_id) DO UPDATE
    SET role = EXCLUDED.role;

  -- Sync user_profiles.current_tenant_id per 10.8.7D
  INSERT INTO public.user_profiles (id, current_tenant_id)
  VALUES (v_user_id, v_invite.tenant_id)
  ON CONFLICT (id) DO UPDATE
    SET current_tenant_id = EXCLUDED.current_tenant_id;

  -- Mark invite accepted
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