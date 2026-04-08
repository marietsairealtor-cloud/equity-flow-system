-- 10.8.11I3: Pending Invites RPC Management Layer
-- list_pending_invites_v1: returns pending invites for current tenant
-- rescind_invite_v1: deletes a pending invite for current tenant

-- list_pending_invites_v1
CREATE OR REPLACE FUNCTION public.list_pending_invites_v1()
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

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'items', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'invite_id', ti.id,
            'email', ti.invited_email,
            'role', ti.role,
            'created_at', ti.created_at,
            'invited_by', (SELECT u.email FROM auth.users u WHERE u.id = ti.invited_by)
          )
        )
        FROM public.tenant_invites ti
        WHERE ti.tenant_id = v_tenant_id
          AND ti.accepted_at IS NULL
          AND ti.expires_at > now()
      ), '[]'::jsonb)
    ),
    'error', null
  );

END;
$fn$;

REVOKE ALL ON FUNCTION public.list_pending_invites_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_pending_invites_v1() TO authenticated;

-- rescind_invite_v1
CREATE OR REPLACE FUNCTION public.rescind_invite_v1(p_invite_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_invite public.tenant_invites;
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

  IF p_invite_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'invite_id is required', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT * INTO v_invite
  FROM public.tenant_invites ti
  WHERE ti.id = p_invite_id
    AND ti.tenant_id = v_tenant_id
    AND ti.accepted_at IS NULL
    AND ti.expires_at > now();

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invite not found', 'fields', '{}'::jsonb)
    );
  END IF;

  DELETE FROM public.tenant_invites
  WHERE id = p_invite_id
    AND tenant_id = v_tenant_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', '{}'::jsonb,
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.rescind_invite_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rescind_invite_v1(uuid) TO authenticated;