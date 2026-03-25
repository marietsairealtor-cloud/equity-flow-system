-- 10.8.7E: Pending Invite Resolution RPC
-- Creates accept_pending_invites_v1() RPC.
-- Resolves all valid pending invites for the authenticated user by exact email match.
-- No frontend parameters. Email derived from auth.users via auth.uid().
-- Processes oldest-first. Partial acceptance allowed. Silent per-invite failure.
CREATE OR REPLACE FUNCTION public.accept_pending_invites_v1()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user_id             uuid;
  v_user_email          text;
  v_invite              record;
  v_accepted_count      integer := 0;
  v_accepted_tenant_ids uuid[] := '{}';
  v_default_tenant_id   uuid;
  v_current_tenant_id   uuid;
BEGIN
  -- Require authenticated context
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN pg_catalog.json_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', NULL,
      'error', pg_catalog.json_build_object(
        'message', 'Not authorized',
        'fields', pg_catalog.json_build_object()
      )
    );
  END IF;
  -- Read authenticated email from auth.users
  SELECT u.email
  INTO v_user_email
  FROM auth.users AS u
  WHERE u.id = v_user_id;
  IF v_user_email IS NULL THEN
    RETURN pg_catalog.json_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', NULL,
      'error', pg_catalog.json_build_object(
        'message', 'User email not found',
        'fields', pg_catalog.json_build_object()
      )
    );
  END IF;
  -- Read current tenant context before processing
  SELECT up.current_tenant_id
  INTO v_current_tenant_id
  FROM public.user_profiles AS up
  WHERE up.id = v_user_id;
  -- Process valid pending invites oldest-first
  FOR v_invite IN
    SELECT ti.id, ti.tenant_id, ti.role
    FROM public.tenant_invites AS ti
    WHERE ti.invited_email = v_user_email
      AND ti.accepted_at IS NULL
      AND ti.expires_at > pg_catalog.now()
    ORDER BY ti.created_at ASC
  LOOP
    BEGIN
      -- Create membership if missing; duplicate/race = already satisfied
      INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
      VALUES (extensions.gen_random_uuid(), v_invite.tenant_id, v_user_id, v_invite.role)
      ON CONFLICT (tenant_id, user_id) DO NOTHING;
      -- Mark invite accepted/satisfied
      UPDATE public.tenant_invites
      SET accepted_at = pg_catalog.now(),
          row_version = row_version + 1
      WHERE id = v_invite.id;
      v_accepted_count := v_accepted_count + 1;
      v_accepted_tenant_ids := pg_catalog.array_append(v_accepted_tenant_ids, v_invite.tenant_id);
      IF v_default_tenant_id IS NULL THEN
        v_default_tenant_id := v_invite.tenant_id;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        -- Silent per-invite failure
        NULL;
    END;
  END LOOP;
  -- Set current tenant only if currently NULL
  IF v_current_tenant_id IS NULL AND v_default_tenant_id IS NOT NULL THEN
    INSERT INTO public.user_profiles (id, current_tenant_id)
    VALUES (v_user_id, v_default_tenant_id)
    ON CONFLICT (id) DO UPDATE
      SET current_tenant_id = EXCLUDED.current_tenant_id
      WHERE public.user_profiles.current_tenant_id IS NULL;
  END IF;
  RETURN pg_catalog.json_build_object(
    'ok', true,
    'code', 'OK',
    'data', pg_catalog.json_build_object(
      'accepted_count', v_accepted_count,
      'accepted_tenant_ids', v_accepted_tenant_ids,
      'default_tenant_id', COALESCE(v_current_tenant_id, v_default_tenant_id)
    ),
    'error', NULL
  );
END;
$fn$;
REVOKE ALL ON FUNCTION public.accept_pending_invites_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_pending_invites_v1() TO authenticated;