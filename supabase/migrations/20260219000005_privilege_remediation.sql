-- Remediate materialized object-level grants violating CONTRACTS.md §12
-- Stop-the-line: privilege firewall violation detected via catalog query 2026-02-22
-- Forward-only plain SQL. No DO blocks, no dynamic SQL.

-- 1) Remove existing object-level grants (materialized damage)
REVOKE ALL PRIVILEGES ON TABLE public.tenants            FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.tenant_memberships FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.deals              FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.user_profiles      FROM anon, authenticated;

-- Belt-and-suspenders: blanket cleanup for all public schema objects
REVOKE ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;

-- 2) Prevent future re-materialization
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES    FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated;

-- 3) Re-apply only the CONTRACTS.md §12 controlled exception
GRANT SELECT, UPDATE ON TABLE public.user_profiles TO authenticated;