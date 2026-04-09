-- 10.8.11I5: Seat billing sync on tenant_memberships INSERT and DELETE
-- Calls sync-seat-count Edge Function via pg_net
-- Uses same vault pattern as 10.8.11I1

CREATE OR REPLACE FUNCTION public.trigger_seat_sync()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_service_role_key text;
  v_tenant_id uuid;
BEGIN
  -- Resolve tenant_id from correct record
  IF TG_OP = 'DELETE' THEN
    v_tenant_id := OLD.tenant_id;
  ELSE
    v_tenant_id := NEW.tenant_id;
  END IF;

  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;

  PERFORM net.http_post(
    url := 'https://upnelewdvbicxvfgzojg.supabase.co/functions/v1/sync-seat-count',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body := jsonb_build_object(
      'record', jsonb_build_object('tenant_id', v_tenant_id)
    )
  );
  RETURN COALESCE(NEW, OLD);
EXCEPTION
  WHEN OTHERS THEN
    RETURN COALESCE(NEW, OLD);
END;
$fn$;

DROP TRIGGER IF EXISTS on_membership_insert_sync_seats ON public.tenant_memberships;
CREATE TRIGGER on_membership_insert_sync_seats
  AFTER INSERT ON public.tenant_memberships
  FOR EACH ROW EXECUTE FUNCTION public.trigger_seat_sync();

DROP TRIGGER IF EXISTS on_membership_delete_sync_seats ON public.tenant_memberships;
CREATE TRIGGER on_membership_delete_sync_seats
  AFTER DELETE ON public.tenant_memberships
  FOR EACH ROW EXECUTE FUNCTION public.trigger_seat_sync();