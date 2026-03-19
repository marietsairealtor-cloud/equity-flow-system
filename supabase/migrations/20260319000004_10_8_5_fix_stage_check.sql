-- 10.8.5 corrective: update deals_stage_check constraint to use authoritative
-- stage string per WEWEB_ARCHITECTURE s3: Closed / Dead is a single terminal state.
-- Prior constraint (10.8.4) incorrectly split into Closed and Dead separately.

ALTER TABLE public.deals
  DROP CONSTRAINT deals_stage_check;

ALTER TABLE public.deals
  ADD CONSTRAINT deals_stage_check CHECK (stage IN (
    'New',
    'Analyzing',
    'Offer Sent',
    'Under Contract (UC)',
    'Dispo',
    'Closed / Dead'
  ));