-- 20260219000017_revoke_core_table_grants.sql
-- 6.6: Explicit REVOKE ALL on product core tables per CONTRACTS.md S12.
-- Satisfies migration-rls-colocation gate requirement for co-located REVOKEs.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No double-dollar tags.
REVOKE ALL ON public.calc_versions FROM anon;
REVOKE ALL ON public.calc_versions FROM authenticated;
REVOKE ALL ON public.deal_inputs FROM anon;
REVOKE ALL ON public.deal_inputs FROM authenticated;
REVOKE ALL ON public.deal_outputs FROM anon;
REVOKE ALL ON public.deal_outputs FROM authenticated;
