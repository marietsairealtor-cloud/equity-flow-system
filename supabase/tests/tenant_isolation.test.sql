-- 6.3 Tenant Integrity Suite — Negative Isolation Tests (RPC surface)
-- GUARDRAILS: SQL-only, no DO blocks, no PL/pgSQL, no \cmds, named dollar tags only
-- Tests use allowlisted RPCs per CONTRACTS.md S7/S12 (no direct table access).
SELECT plan(13);

BEGIN;

-- Cleanup create_deal_v1 ids so repeated runs don't CONFLICT (FK-safe)
DELETE FROM public.deal_inputs WHERE deal_id IN (
  'a2000000-0000-0000-0000-000000000f99'::uuid,
  'a2000000-0000-0000-0000-000000000f98'::uuid,
  'b2000000-0000-0000-0000-000000000f99'::uuid
);

DELETE FROM public.deals WHERE id IN (
  'a2000000-0000-0000-0000-000000000f99'::uuid,
  'a2000000-0000-0000-0000-000000000f98'::uuid,
  'b2000000-0000-0000-0000-000000000f99'::uuid
);

COMMIT;
DELETE FROM public.deal_inputs WHERE deal_id IN (
  'a2000000-0000-0000-0000-000000000f99'::uuid,
  'a2000000-0000-0000-0000-000000000f98'::uuid,
  'b2000000-0000-0000-0000-000000000f99'::uuid
);
-- ============================================================
-- Seed as superuser (privileged seeding, not assertion)
-- ============================================================
BEGIN;

-- Clean in FK-safe order (by tenant scope)
DELETE FROM public.deal_inputs
WHERE tenant_id IN (
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'b0000000-0000-0000-0000-000000000001'::uuid
);

DELETE FROM public.deals
WHERE tenant_id IN (
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'b0000000-0000-0000-0000-000000000001'::uuid
);

-- Seed deals with snapshot id up-front (FK is DEFERRABLE)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id) VALUES
  ('a2000000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 1, 1, 'a1000000-0000-0000-0000-000000000001'::uuid),
  ('a2000000-0000-0000-0000-000000000002'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 1, 1, 'a1000000-0000-0000-0000-000000000002'::uuid),
  ('b2000000-0000-0000-0000-000000000001'::uuid, 'b0000000-0000-0000-0000-000000000001'::uuid, 1, 1, 'b1000000-0000-0000-0000-000000000001'::uuid),
  ('b2000000-0000-0000-0000-000000000002'::uuid, 'b0000000-0000-0000-0000-000000000001'::uuid, 1, 1, 'b1000000-0000-0000-0000-000000000002'::uuid);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions) VALUES
  ('a1000000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 'a2000000-0000-0000-0000-000000000001'::uuid, 1, 1, '{}'::jsonb),
  ('a1000000-0000-0000-0000-000000000002'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 'a2000000-0000-0000-0000-000000000002'::uuid, 1, 1, '{}'::jsonb),
  ('b1000000-0000-0000-0000-000000000001'::uuid, 'b0000000-0000-0000-0000-000000000001'::uuid, 'b2000000-0000-0000-0000-000000000001'::uuid, 1, 1, '{}'::jsonb),
  ('b1000000-0000-0000-0000-000000000002'::uuid, 'b0000000-0000-0000-0000-000000000001'::uuid, 'b2000000-0000-0000-0000-000000000002'::uuid, 1, 1, '{}'::jsonb);

COMMIT;

-- ============================================================
-- Tenant A session
-- ============================================================
RESET ROLE;
SET ROLE authenticated;
SET request.jwt.claim.tenant_id = 'a0000000-0000-0000-0000-000000000001';

SELECT isnt(
  public.current_tenant_id(),
  NULL::uuid,
  'Diagnostic: current_tenant_id() resolves for Tenant A'
);

SELECT is(
  (SELECT (public.list_deals_v1(100)::json -> 'data' -> 'items')::json ->> 0 IS NOT NULL)::boolean,
  true,
  'Tenant A: list_deals_v1 returns items'
);

SELECT is(
  (SELECT json_array_length(public.list_deals_v1(100)::json -> 'data' -> 'items'))::int,
  2,
  'Tenant A: list_deals_v1 returns exactly 2 deals (own only)'
);

SELECT is(
  (SELECT count(*)::int
     FROM json_array_elements(public.list_deals_v1(100)::json -> 'data' -> 'items') AS elem
    WHERE elem ->> 'tenant_id' != 'a0000000-0000-0000-0000-000000000001'),
  0,
  'Tenant A: all list_deals_v1 items belong to Tenant A'
);

SELECT is(
  (public.create_deal_v1('a2000000-0000-0000-0000-000000000f99'::uuid, 1, '{}'::jsonb)::json ->> 'ok')::boolean,
  true,
  'Tenant A: create_deal_v1 succeeds (own tenant)'
);

SELECT is(
  (public.create_deal_v1('a2000000-0000-0000-0000-000000000f98'::uuid, 1, '{}'::jsonb)::json -> 'data' ->> 'tenant_id'),
  'a0000000-0000-0000-0000-000000000001',
  'Tenant A: create_deal_v1 binds to Tenant A'
);

-- ============================================================
-- Tenant B session
-- ============================================================
RESET ROLE;
SET ROLE authenticated;
SET request.jwt.claim.tenant_id = 'b0000000-0000-0000-0000-000000000001';

SELECT is(
  (SELECT json_array_length(public.list_deals_v1(100)::json -> 'data' -> 'items'))::int,
  2,
  'Tenant B: list_deals_v1 returns exactly 2 deals (own only)'
);

SELECT is(
  (SELECT count(*)::int
     FROM json_array_elements(public.list_deals_v1(100)::json -> 'data' -> 'items') AS elem
    WHERE elem ->> 'tenant_id' = 'a0000000-0000-0000-0000-000000000001'),
  0,
  'Tenant B: list_deals_v1 returns zero Tenant A rows'
);

SELECT is(
  (public.create_deal_v1('b2000000-0000-0000-0000-000000000f99'::uuid, 1, '{}'::jsonb)::json -> 'data' ->> 'tenant_id'),
  'b0000000-0000-0000-0000-000000000001',
  'Tenant B: create_deal_v1 binds to Tenant B (not A)'
);

-- ============================================================
-- No-tenant session (NULL context)
-- ============================================================
RESET ROLE;
SET ROLE authenticated;
RESET request.jwt.claim.tenant_id;

SELECT is(
  (public.list_deals_v1()::json ->> 'code'),
  'NOT_AUTHORIZED',
  'No tenant context: list_deals_v1 returns NOT_AUTHORIZED'
);

SELECT is(
  (public.create_deal_v1('c2000000-0000-0000-0000-000000000001'::uuid, 1, '{}'::jsonb)::json ->> 'code'),
  'NOT_AUTHORIZED',
  'No tenant context: create_deal_v1 returns NOT_AUTHORIZED'
);

-- ============================================================
-- Structural checks
-- ============================================================
RESET ROLE;

SELECT is(
  (SELECT count(*)::int FROM pg_views WHERE schemaname = 'public' AND viewname NOT IN ('share_token_packet')),
  0,
  'No unauthorized views in public schema (share_token_packet allowlisted)'
);

SELECT ok(
  (SELECT count(*)::int
     FROM pg_trigger t
     JOIN pg_class c ON c.oid = t.tgrelid
     JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND NOT t.tgisinternal) > 0,
  'Public schema has explicit triggers (6.6 hardening present)'
);

SELECT finish();




