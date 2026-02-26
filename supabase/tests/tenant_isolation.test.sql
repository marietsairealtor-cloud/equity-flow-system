-- 6.3 Tenant Integrity Suite — Negative Isolation Tests (RPC surface)
-- GUARDRAILS: SQL-only, no DO blocks, no PL/pgSQL, no \cmds, named dollar tags only
-- Tests use allowlisted RPCs per CONTRACTS.md S7/S12 (no direct table access).

SELECT plan(13);

-- Seed as superuser (privileged seeding, not assertion)
DELETE FROM public.deals WHERE id IN (
  'a2000000-0000-0000-0000-000000000001'::uuid,
  'a2000000-0000-0000-0000-000000000002'::uuid,
  'b2000000-0000-0000-0000-000000000001'::uuid,
  'b2000000-0000-0000-0000-000000000002'::uuid
);
INSERT INTO public.deals (id, tenant_id, row_version, calc_version) VALUES
  ('a2000000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 1, 1),
  ('a2000000-0000-0000-0000-000000000002'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 1, 1),
  ('b2000000-0000-0000-0000-000000000001'::uuid, 'b0000000-0000-0000-0000-000000000001'::uuid, 1, 1),
  ('b2000000-0000-0000-0000-000000000002'::uuid, 'b0000000-0000-0000-0000-000000000001'::uuid, 1, 1);

-- ============================================================
-- Tenant A session
-- ============================================================
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'a0000000-0000-0000-0000-000000000001', false);

-- Diagnostic: tenant resolves
SELECT isnt(
  public.current_tenant_id(),
  NULL::uuid,
  'Diagnostic: current_tenant_id() resolves for Tenant A'
);

-- Test 1: list_deals_v1 returns only Tenant A rows
SELECT is(
  (SELECT (public.list_deals_v1(100)::json -> 'data' -> 'items')::json ->> 0 IS NOT NULL)::boolean,
  true,
  'Tenant A: list_deals_v1 returns items'
);

-- Test 2: list_deals_v1 count = 2 (own rows only)
SELECT is(
  (SELECT json_array_length(public.list_deals_v1(100)::json -> 'data' -> 'items'))::int,
  2,
  'Tenant A: list_deals_v1 returns exactly 2 deals (own only)'
);

-- Test 3: all items belong to Tenant A
SELECT is(
  (SELECT count(*)::int FROM json_array_elements(public.list_deals_v1(100)::json -> 'data' -> 'items') AS elem WHERE elem ->> 'tenant_id' != 'a0000000-0000-0000-0000-000000000001'),
  0,
  'Tenant A: all list_deals_v1 items belong to Tenant A'
);

-- Test 4: create_deal_v1 succeeds for own tenant
SELECT is(
  (public.create_deal_v1('a2000000-0000-0000-0000-000000000099'::uuid)::json ->> 'ok')::boolean,
  true,
  'Tenant A: create_deal_v1 succeeds (own tenant)'
);

-- Test 5: created deal shows tenant A binding
SELECT is(
  (public.create_deal_v1('a2000000-0000-0000-0000-000000000098'::uuid)::json -> 'data' ->> 'tenant_id'),
  'a0000000-0000-0000-0000-000000000001',
  'Tenant A: create_deal_v1 binds to Tenant A'
);

-- ============================================================
-- Tenant B session
-- ============================================================
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'b0000000-0000-0000-0000-000000000001', false);

-- Test 6: list_deals_v1 returns only Tenant B rows
SELECT is(
  (SELECT json_array_length(public.list_deals_v1(100)::json -> 'data' -> 'items'))::int,
  2,
  'Tenant B: list_deals_v1 returns exactly 2 deals (own only)'
);

-- Test 7: Tenant B cannot see Tenant A rows
SELECT is(
  (SELECT count(*)::int FROM json_array_elements(public.list_deals_v1(100)::json -> 'data' -> 'items') AS elem WHERE elem ->> 'tenant_id' = 'a0000000-0000-0000-0000-000000000001'),
  0,
  'Tenant B: list_deals_v1 returns zero Tenant A rows'
);

-- Test 8: Tenant B create binds to B
SELECT is(
  (public.create_deal_v1('b2000000-0000-0000-0000-000000000099'::uuid)::json -> 'data' ->> 'tenant_id'),
  'b0000000-0000-0000-0000-000000000001',
  'Tenant B: create_deal_v1 binds to Tenant B (not A)'
);

-- ============================================================
-- No-tenant session (NULL context)
-- ============================================================
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', '', false);

-- Test 9: no tenant = NOT_AUTHORIZED
SELECT is(
  (public.list_deals_v1()::json ->> 'code'),
  'NOT_AUTHORIZED',
  'No tenant context: list_deals_v1 returns NOT_AUTHORIZED'
);

-- Test 10: no tenant = create denied
SELECT is(
  (public.create_deal_v1('c2000000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  'NOT_AUTHORIZED',
  'No tenant context: create_deal_v1 returns NOT_AUTHORIZED'
);

-- ============================================================
-- Structural checks
-- ============================================================
RESET ROLE;

-- Test 11: No views in public schema
SELECT is(
  (SELECT count(*)::int FROM pg_views WHERE schemaname = 'public'),
  0,
  'No views in public schema — view-based cross-tenant access not possible'
);

-- Test 12: No triggers on public schema tables
SELECT is(
  (SELECT count(*)::int
     FROM pg_trigger t
     JOIN pg_class c ON c.oid = t.tgrelid
     JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND NOT t.tgisinternal),
  0,
  'No triggers on public schema tables — no background context risk'
);

SELECT finish();
