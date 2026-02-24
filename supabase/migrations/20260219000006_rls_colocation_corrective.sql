-- RLS co-location corrective migration per Build Route 5.1 pre-check
-- Applies missing co-located RLS + privilege firewall to baseline tables
-- Idempotent — safe to apply even if partially in effect
-- Forward-only plain SQL. No DO blocks, no dynamic SQL.
-- Preserves CONTRACTS.md §12 controlled exception:
--   authenticated retains SELECT, UPDATE on user_profiles (re-granted below)

-- 1) Enable RLS on all baseline tables (idempotent)
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deals ENABLE ROW LEVEL SECURITY;

-- 2) Revoke all privileges on baseline tables (idempotent)
REVOKE ALL ON TABLE public.tenants FROM anon, authenticated;
REVOKE ALL ON TABLE public.tenant_memberships FROM anon, authenticated;
REVOKE ALL ON TABLE public.user_profiles FROM anon, authenticated;
REVOKE ALL ON TABLE public.deals FROM anon, authenticated;

-- 3) Re-apply CONTRACTS.md §12 controlled exception
GRANT SELECT, UPDATE ON TABLE public.user_profiles TO authenticated;