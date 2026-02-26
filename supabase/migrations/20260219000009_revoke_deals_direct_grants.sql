-- 20260219000009_revoke_deals_direct_grants.sql
-- Fix: CONTRACTS.md S12 — deals must not have direct GRANTs to authenticated.
-- RLS policies remain; access will be via allowlisted RPCs only.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No double-dollar tags.
REVOKE ALL PRIVILEGES ON TABLE public.deals FROM anon, authenticated;
