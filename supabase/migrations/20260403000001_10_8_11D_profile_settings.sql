-- 20260403000001_10_8_11D_profile_settings.sql

DROP FUNCTION IF EXISTS public.get_profile_settings_v1();

CREATE FUNCTION public.get_profile_settings_v1()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user_id uuid;
  v_email text;
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

  SELECT u.email
  INTO v_email
  FROM auth.users u
  WHERE u.id = v_user_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'user_id', v_user_id,
      'email', v_email,
      'display_name', null
    ),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_profile_settings_v1() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_profile_settings_v1() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_profile_settings_v1() TO authenticated;