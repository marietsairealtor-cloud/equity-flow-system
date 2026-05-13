-- 10.14B corrective: fix encoding in deals column comments (em dash replaced with plain hyphen)
-- UNPAIRED-CORRECTIVE: no schema surface change, comment text only.
COMMENT ON COLUMN public.deals.assignment_agreement_signed_at IS
  '10.14B: assignment agreement signed - required with earnest_money_received_at before handoff_to_tc_v1.';
COMMENT ON COLUMN public.deals.earnest_money_received_at IS
  '10.14B: earnest money / deposit received - required with assignment_agreement_signed_at before handoff_to_tc_v1.';