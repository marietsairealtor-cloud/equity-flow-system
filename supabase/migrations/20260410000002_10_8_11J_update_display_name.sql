-- 10.8.11J: Update Display Name RPC + get_profile_settings_v1 corrective fix

-- 1. update_display_name_v1
CREATE OR REPLACE FUNCTION public.update_display_name_v1(p_display_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user_id uuid;
  v_display_name text;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not authenticated', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_display_name IS NULL OR trim(p_display_name) = '' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Display name is required', 'fields', jsonb_build_object('display_name', 'Must not be blank'))
    );
  END IF;

  v_display_name := trim(p_display_name);

  UPDATE public.user_profiles
  SET display_name = v_display_name
  WHERE id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Profile not found', 'fields', '{}'::jsonb)
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object('display_name', v_display_name),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.update_display_name_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_display_name_v1(text) TO authenticated;

-- 2. get_profile_settings_v1 corrective fix -- reads display_name from user_profiles
CREATE OR REPLACE FUNCTION public.get_profile_settings_v1()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user_id uuid;
  v_email text;
  v_display_name text;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not authenticated', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT u.email INTO v_email
  FROM auth.users u
  WHERE u.id = v_user_id;

  SELECT up.display_name INTO v_display_name
  FROM public.user_profiles up
  WHERE up.id = v_user_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'user_id', v_user_id,
      'email', v_email,
      'display_name', v_display_name
    ),
    'error', null
  );
END;
$fn$;