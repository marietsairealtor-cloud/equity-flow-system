-- 10.14B7B: Forward repair -- lookup_share_token_public_v1 grants
-- Applies privilege firewall for lookup_share_token_public_v1.
-- This migration will fail loudly if 20260526000003 did not land the function.

REVOKE ALL ON FUNCTION public.lookup_share_token_public_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lookup_share_token_public_v1(text) TO anon;
GRANT EXECUTE ON FUNCTION public.lookup_share_token_public_v1(text) TO authenticated;
