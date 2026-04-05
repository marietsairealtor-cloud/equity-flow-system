-- 20260405000002_10_8_11G_workspace_members_rpcs.sql

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS display_name text;

-- list_workspace_members_v1
DROP FUNCTION IF EXISTS public.list_workspace_members_v1();

CREATE FUNCTION public.list_workspace_members_v1()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_members jsonb;
BEGIN
  PERFORM public.require_min_role_v1('member');

  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'user_id', tm.user_id,
    'email', u.email,
    'display_name', up.display_name,
    'role', tm.role
  ) ORDER BY tm.created_at ASC)
  INTO v_members
  FROM public.tenant_memberships tm
  JOIN auth.users u ON u.id = tm.user_id
  LEFT JOIN public.user_profiles up ON up.id = tm.user_id
  WHERE tm.tenant_id = v_tenant_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'items', COALESCE(v_members, '[]'::jsonb)
    ),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.list_workspace_members_v1() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.list_workspace_members_v1() FROM anon;
GRANT EXECUTE ON FUNCTION public.list_workspace_members_v1() TO authenticated;

-- invite_workspace_member_v1
DROP FUNCTION IF EXISTS public.invite_workspace_member_v1(text, public.tenant_role);

CREATE FUNCTION public.invite_workspace_member_v1(
  p_email text,
  p_role public.tenant_role
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_existing_member uuid;
  v_existing_invite uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_email IS NULL OR btrim(p_email) = '' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Email is required', 'fields', jsonb_build_object('email', 'Must not be blank'))
    );
  END IF;

  IF p_role IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Role is required', 'fields', jsonb_build_object('role', 'Must not be null'))
    );
  END IF;

  SELECT tm.user_id INTO v_existing_member
  FROM public.tenant_memberships tm
  JOIN auth.users u ON u.id = tm.user_id
  WHERE tm.tenant_id = v_tenant_id
    AND lower(u.email) = lower(btrim(p_email));

  IF v_existing_member IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'CONFLICT',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'User is already a member', 'fields', jsonb_build_object('email', 'Already a member of this workspace'))
    );
  END IF;

  SELECT id INTO v_existing_invite
  FROM public.tenant_invites
  WHERE tenant_id = v_tenant_id
    AND lower(invited_email) = lower(btrim(p_email))
    AND accepted_at IS NULL
    AND expires_at > now();

  IF v_existing_invite IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'CONFLICT',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Pending invite already exists', 'fields', jsonb_build_object('email', 'Already has a pending invite'))
    );
  END IF;

  INSERT INTO public.tenant_invites (
    tenant_id, invited_email, role, token, invited_by, expires_at
  ) VALUES (
    v_tenant_id,
    lower(btrim(p_email)),
    p_role,
    gen_random_uuid()::text,
    auth.uid(),
    now() + interval '7 days'
  );

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'invited_email', lower(btrim(p_email)),
      'role', p_role
    ),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.invite_workspace_member_v1(text, public.tenant_role) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.invite_workspace_member_v1(text, public.tenant_role) FROM anon;
GRANT EXECUTE ON FUNCTION public.invite_workspace_member_v1(text, public.tenant_role) TO authenticated;

-- update_member_role_v1
DROP FUNCTION IF EXISTS public.update_member_role_v1(uuid, public.tenant_role);

CREATE FUNCTION public.update_member_role_v1(
  p_user_id uuid,
  p_role public.tenant_role
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'user_id is required', 'fields', jsonb_build_object('user_id', 'Must not be null'))
    );
  END IF;

  IF p_role IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message','Role is required', 'fields', jsonb_build_object('role', 'Must not be null'))
    );
  END IF;

  UPDATE public.tenant_memberships
  SET role = p_role
  WHERE tenant_id = v_tenant_id
    AND user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Member not found', 'fields', '{}'::jsonb)
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'user_id', p_user_id,
      'role', p_role
    ),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.update_member_role_v1(uuid, public.tenant_role) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_member_role_v1(uuid, public.tenant_role) FROM anon;
GRANT EXECUTE ON FUNCTION public.update_member_role_v1(uuid, public.tenant_role) TO authenticated;

-- remove_member_v1
DROP FUNCTION IF EXISTS public.remove_member_v1(uuid);

CREATE FUNCTION public.remove_member_v1(
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'user_id is required', 'fields', jsonb_build_object('user_id', 'Must not be null'))
    );
  END IF;

  DELETE FROM public.tenant_memberships
  WHERE tenant_id = v_tenant_id
    AND user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Member not found', 'fields', '{}'::jsonb)
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'user_id', p_user_id
    ),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.remove_member_v1(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.remove_member_v1(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.remove_member_v1(uuid) TO authenticated;