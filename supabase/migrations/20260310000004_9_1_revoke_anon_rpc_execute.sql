-- 20260310000004_9_1_revoke_anon_rpc_execute.sql
-- 9.1: Revoke anon/PUBLIC execute on business RPCs.
-- These RPCs require authenticated context - anon exposure is unintended.
REVOKE EXECUTE ON FUNCTION public.create_deal_v1(uuid, integer, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_user_entitlements_v1() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_deals_v1(integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_deal_v1(uuid, bigint, integer) FROM PUBLIC, anon;
