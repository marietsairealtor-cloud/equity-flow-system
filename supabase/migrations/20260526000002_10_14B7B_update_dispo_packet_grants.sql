-- 10.14B7B: Forward repair -- update_dispo_packet_v1 grants
-- Applies privilege firewall for update_dispo_packet_v1.
-- This migration will fail loudly if 20260526000001 did not land the function.

REVOKE EXECUTE ON FUNCTION public.update_dispo_packet_v1(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_dispo_packet_v1(uuid, jsonb) TO authenticated;
