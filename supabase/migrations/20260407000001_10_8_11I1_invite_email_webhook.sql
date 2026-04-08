-- 10.8.11I1: pg_net trigger on tenant_invites INSERT
-- Calls send-invite-email Edge Function server-side only
-- Email failure does not block invite creation
-- Assumption: Edge Function endpoint accepts this internal webhook request
-- without requiring a secret embedded in migration SQL.

CREATE EXTENSION IF NOT EXISTS pg_net SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.trigger_invite_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  PERFORM net.http_post(
    url := 'https://upnelewdvbicxvfgzojg.supabase.co/functions/v1/send-invite-email',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'record', row_to_json(NEW)::jsonb
    )
  );

  RETURN NEW;

EXCEPTION
  WHEN OTHERS THEN
    -- Email delivery failure must not block invite creation
    RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS on_tenant_invite_insert ON public.tenant_invites;

CREATE TRIGGER on_tenant_invite_insert
AFTER INSERT ON public.tenant_invites
FOR EACH ROW
EXECUTE FUNCTION public.trigger_invite_email();