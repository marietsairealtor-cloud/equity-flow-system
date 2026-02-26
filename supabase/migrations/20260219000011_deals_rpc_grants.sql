-- 20260219000011_deals_rpc_grants.sql
-- Grant/revoke EXECUTE on deals RPCs per CONTRACTS.md S7.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No double-dollar tags.
GRANT EXECUTE ON FUNCTION public.list_deals_v1(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_deal_v1(uuid, bigint, int) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.list_deals_v1(int) FROM anon;
REVOKE EXECUTE ON FUNCTION public.create_deal_v1(uuid, bigint, int) FROM anon;
