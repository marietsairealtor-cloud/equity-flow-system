-- 6.10: activity_log append-only enforcement
-- Uses named dollar tags; no bare dollar-dollar sequences

-- 1. Revoke UPDATE and DELETE on activity_log from authenticated
REVOKE UPDATE, DELETE ON TABLE public.activity_log FROM authenticated;

-- 2. Trigger function: block UPDATE and DELETE at DB level
CREATE OR REPLACE FUNCTION public.activity_log_append_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $fn$
BEGIN
  RAISE EXCEPTION 'activity_log_append_only: mutations are not permitted on activity_log';
END;
$fn$;

ALTER FUNCTION public.activity_log_append_only() OWNER TO postgres;

-- 3. Triggers: fire BEFORE UPDATE or DELETE
CREATE OR REPLACE TRIGGER activity_log_no_update
  BEFORE UPDATE ON public.activity_log
  FOR EACH ROW EXECUTE FUNCTION public.activity_log_append_only();

CREATE OR REPLACE TRIGGER activity_log_no_delete
  BEFORE DELETE ON public.activity_log
  FOR EACH ROW EXECUTE FUNCTION public.activity_log_append_only();
