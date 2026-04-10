-- 10.8.11I7: Helper function to check if email exists in auth.users
-- Returns boolean only -- no data leakage
-- Used by send-invite-email Edge Function to determine invite path

CREATE OR REPLACE FUNCTION public.auth_user_exists_v1(p_email text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE lower(u.email) = lower(p_email)
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.auth_user_exists_v1(text) FROM PUBLIC;