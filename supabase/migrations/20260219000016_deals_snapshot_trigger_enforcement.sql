-- 20260219000016_deals_snapshot_trigger_enforcement.sql
-- 6.6: Replace NOT NULL column constraint on assumptions_snapshot_id with deferrable trigger.
-- NOT NULL cannot be deferred; circular FK requires NULL during INSERT then set after deal_inputs.
-- CONSTRAINT TRIGGER with DEFERRABLE INITIALLY DEFERRED enforces invariant at commit time.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No double-dollar tags.

-- Drop NOT NULL constraint (enforcement moves to deferrable constraint trigger)
ALTER TABLE public.deals
  ALTER COLUMN assumptions_snapshot_id DROP NOT NULL;

-- Trigger function: block commit if assumptions_snapshot_id is NULL
CREATE OR REPLACE FUNCTION public.check_deal_snapshot_not_null()
RETURNS trigger
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $fn$
BEGIN
  IF NEW.assumptions_snapshot_id IS NULL THEN
    RAISE EXCEPTION 'deal_snapshot_not_null: assumptions_snapshot_id must not be NULL on deal %', NEW.id;
  END IF;
  RETURN NEW;
END;
$fn$;

-- CONSTRAINT TRIGGER: deferrable, fires at commit — allows circular FK seeding within transaction
CREATE CONSTRAINT TRIGGER deals_snapshot_not_null
  AFTER INSERT OR UPDATE ON public.deals
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION public.check_deal_snapshot_not_null();
