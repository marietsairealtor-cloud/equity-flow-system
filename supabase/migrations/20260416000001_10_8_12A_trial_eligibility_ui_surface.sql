-- 10.8.12A: Trial Eligibility UI Surface Correction
-- Extends get_profile_settings_v1() to return has_used_trial.
-- Additive return field only. No signature change. No schema changes.

DROP FUNCTION IF EXISTS public.get_profile_settings_v1();
CREATE FUNCTION public.get_profile_settings_v1()
RETURNS json
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user         uuid;
  v_email        text;
  v_display_name text;
  v_has_used_trial boolean;
BEGIN
  v_user := auth.uid();

  IF v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'Authentication required',
        'fields',  json_build_object()
      )
    );
  END IF;

  SELECT au.email INTO v_email
  FROM auth.users au
  WHERE au.id = v_user;

  SELECT up.display_name, up.has_used_trial
  INTO v_display_name, v_has_used_trial
  FROM public.user_profiles up
  WHERE up.id = v_user;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'User profile not found',
        'fields',  json_build_object()
      )
    );
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'user_id',        v_user,
      'email',          v_email,
      'display_name',   v_display_name,
      'has_used_trial', v_has_used_trial
    ),
    'error', null
  );
END;
$fn$;
REVOKE ALL ON FUNCTION public.get_profile_settings_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_profile_settings_v1() TO authenticated;
