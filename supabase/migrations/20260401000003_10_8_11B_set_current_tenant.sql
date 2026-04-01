DROP FUNCTION IF EXISTS public.set_current_tenant_v1(uuid);

CREATE OR REPLACE FUNCTION public.set_current_tenant_v1(p_tenant_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user_id uuid;
  v_is_member boolean;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not authorized', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_tenant_id is required', 'fields', jsonb_build_object('p_tenant_id', 'required'))
    );
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.tenant_memberships tm
    WHERE tm.tenant_id = p_tenant_id
      AND tm.user_id = v_user_id
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not a member of this workspace', 'fields', '{}'::jsonb)
    );
  END IF;

  INSERT INTO public.user_profiles (id, current_tenant_id)
  VALUES (v_user_id, p_tenant_id)
  ON CONFLICT (id) DO UPDATE
  SET current_tenant_id = EXCLUDED.current_tenant_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object('tenant_id', p_tenant_id),
    'error', NULL
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'ok', false,
    'code', 'INTERNAL',
    'data', '{}'::jsonb,
    'error', jsonb_build_object('message', SQLERRM, 'fields', '{}'::jsonb)
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.set_current_tenant_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_current_tenant_v1(uuid) TO authenticated;