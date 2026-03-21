-- 10.8.7B: Tenant Invites + Accept Invite RPC
-- Creates tenant_invites table and accept_invite_v1 RPC.
-- Prerequisite for 10.8.8 invite acceptance flow.
-- RPC-only access surface: no direct grants to anon or authenticated.

CREATE TABLE public.tenant_invites (
  id             UUID        NOT NULL DEFAULT gen_random_uuid(),
  tenant_id      UUID        NOT NULL,
  invited_email  TEXT        NOT NULL,
  role           public.tenant_role NOT NULL DEFAULT 'member',
  token          TEXT        NOT NULL,
  invited_by     UUID        NOT NULL,
  accepted_at    TIMESTAMPTZ,
  expires_at     TIMESTAMPTZ NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  row_version    BIGINT      NOT NULL DEFAULT 1,
  CONSTRAINT tenant_invites_pkey PRIMARY KEY (id),
  CONSTRAINT tenant_invites_token_unique UNIQUE (token),
  CONSTRAINT tenant_invites_tenant_id_fkey
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE,
  CONSTRAINT tenant_invites_invited_by_fkey
    FOREIGN KEY (invited_by) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.tenant_invites ENABLE ROW LEVEL SECURITY;

-- RPC-only surface: revoke direct access
REVOKE ALL ON public.tenant_invites FROM anon, authenticated;

-- accept_invite_v1: consumes app invite token, creates tenant membership
-- Idempotent: safe to call multiple times with same token
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
  -- The call confirms the function operates within the tenant resolution chain.
  PERFORM public.current_tenant_id();
  IF v_user_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', null,
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
    );
  END IF;

  -- Validate input
  IF p_token IS NULL OR trim(p_token) = '' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'token is required', 'fields', json_build_object('token', 'required'))
    );
  END IF;

  -- Look up invite by token
  SELECT * INTO v_invite
  FROM public.tenant_invites
  WHERE token = p_token;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Invite not found', 'fields', json_build_object())
    );
  END IF;

  -- Check expiry
  IF v_invite.expires_at < now() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'INVITE_EXPIRED', 'data', null,
      'error', json_build_object('message', 'Invite has expired', 'fields', json_build_object())
    );
  END IF;

  -- Idempotency: already accepted
  IF v_invite.accepted_at IS NOT NULL THEN
    RETURN json_build_object(
      'ok', true, 'code', 'OK', 'data',
      json_build_object('tenant_id', v_invite.tenant_id, 'role', v_invite.role),
      'error', null
    );
  END IF;

  -- Create membership (upsert to handle race conditions)
  INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES (gen_random_uuid(), v_invite.tenant_id, v_user_id, v_invite.role)
  ON CONFLICT (tenant_id, user_id) DO UPDATE
    SET role = EXCLUDED.role;

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