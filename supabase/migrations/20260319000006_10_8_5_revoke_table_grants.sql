-- 10.8.5 corrective: revoke direct table grants on deal_tc and deal_tc_checklist.
-- Migration 20260319000003 incorrectly granted SELECT/INSERT/UPDATE/DELETE to authenticated.
-- CONTRACTS.md s12 requires zero direct table grants to authenticated (except user_profiles).
-- RLS enforces row-level access via platform default ACL + current_tenant_id().
-- Pattern matches 20260219000017_revoke_core_table_grants.sql.

REVOKE ALL ON public.deal_tc FROM anon, authenticated;
REVOKE ALL ON public.deal_tc_checklist FROM anon, authenticated;