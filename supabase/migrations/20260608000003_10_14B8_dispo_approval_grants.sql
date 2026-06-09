-- 10.14B8 — Dispo Backend — Share Packet Photo Visibility
-- Migration 3 of 3: Privilege firewall
-- Fails loudly if migration 2 did not land the functions.

-- update_deal_media_dispo_approval_v1: authenticated only
REVOKE ALL ON FUNCTION public.update_deal_media_dispo_approval_v1(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_deal_media_dispo_approval_v1(uuid, boolean) TO authenticated;

-- lookup_share_token_public_v1: re-apply grants after B8 CREATE OR REPLACE
REVOKE ALL ON FUNCTION public.lookup_share_token_public_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lookup_share_token_public_v1(text) TO anon;
GRANT EXECUTE ON FUNCTION public.lookup_share_token_public_v1(text) TO authenticated;
