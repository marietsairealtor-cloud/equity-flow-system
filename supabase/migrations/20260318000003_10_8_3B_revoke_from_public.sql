-- 20260318000003_10_8_3B_revoke_from_public.sql
-- Build Route 10.8.3B: Consolidating REVOKE EXECUTE FROM PUBLIC
-- Closes audit findings B2-F02, B4-F02 identified in 10.8.3A audit.
-- current_tenant_id() and foundation_log_activity_v1() were missing
-- REVOKE FROM PUBLIC in their original migrations.
-- Old signatures (create_deal_v1(uuid,bigint,int), lookup_share_token_v1(text))
-- confirmed absent from production DB -- B2-F06 and B5-F03 CLOSED.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No bare dollar tags.

REVOKE EXECUTE ON FUNCTION public.current_tenant_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.foundation_log_activity_v1(text, jsonb, uuid) FROM PUBLIC;
