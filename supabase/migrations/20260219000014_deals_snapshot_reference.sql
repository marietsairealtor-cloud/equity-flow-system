-- 20260219000014_deals_snapshot_reference.sql
-- 6.6: Add assumptions_snapshot_id FK on deals (circular, deferrable).
-- Add tenant-match trigger on deal_inputs and deal_outputs.
-- Zero existing rows: NOT NULL enforced immediately.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No double-dollar tags.

-- Step 1: Add assumptions_snapshot_id as nullable first (required for circular FK)
ALTER TABLE public.deals
  ADD COLUMN assumptions_snapshot_id uuid NULL;

-- Step 2: Add deferred FK from deals to deal_inputs
ALTER TABLE public.deals
  ADD CONSTRAINT deals_assumptions_snapshot_fk
  FOREIGN KEY (assumptions_snapshot_id)
  REFERENCES public.deal_inputs(id)
  DEFERRABLE INITIALLY DEFERRED;

-- Step 3: Tenant-match guard function for deal_inputs + deal_outputs
-- Ensures deal_inputs/deal_outputs cannot reference a deal from a different tenant.
CREATE OR REPLACE FUNCTION public.check_deal_tenant_match()
RETURNS trigger
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $fn$
DECLARE
  v_deal_tenant uuid;
BEGIN
  SELECT tenant_id INTO v_deal_tenant
  FROM public.deals
  WHERE id = NEW.deal_id;

  IF v_deal_tenant IS NULL THEN
    RAISE EXCEPTION 'deal_tenant_match: parent deal % not found', NEW.deal_id;
  END IF;

  IF v_deal_tenant <> NEW.tenant_id THEN
    RAISE EXCEPTION 'deal_tenant_match: tenant mismatch on deal_id %, expected % got %',
      NEW.deal_id, v_deal_tenant, NEW.tenant_id;
  END IF;

  RETURN NEW;
END;
$fn$;

-- Step 4: Attach trigger to deal_inputs
CREATE TRIGGER deal_inputs_tenant_match
  BEFORE INSERT OR UPDATE ON public.deal_inputs
  FOR EACH ROW EXECUTE FUNCTION public.check_deal_tenant_match();

-- Step 5: Attach trigger to deal_outputs
CREATE TRIGGER deal_outputs_tenant_match
  BEFORE INSERT OR UPDATE ON public.deal_outputs
  FOR EACH ROW EXECUTE FUNCTION public.check_deal_tenant_match();

-- Step 6: Enforce NOT NULL on assumptions_snapshot_id (zero existing rows, safe immediately)
ALTER TABLE public.deals
  ALTER COLUMN assumptions_snapshot_id SET NOT NULL;
