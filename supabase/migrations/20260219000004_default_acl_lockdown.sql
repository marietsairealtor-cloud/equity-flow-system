-- Revoke default privileges for anon and authenticated on schema public
-- Per CONTRACTS.md §13: new objects in public must be private-by-default
-- Scoped to postgres role only — supabase_% roles excluded per GOVERNANCE_CHANGE_PR024.md
-- Forward-only plain SQL. No DO blocks, no dynamic SQL.

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON FUNCTIONS FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;