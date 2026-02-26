-- 6.3 Tenant Integrity Suite — Negative Isolation Tests
-- GUARDRAILS: SQL-only, no DO blocks, no PL/pgSQL, no \cmds, named dollar tags only

SELECT plan(13);

-- SEED CLEANUP (idempotency)
DELETE FROM public.deals WHERE id IN (
  'a2000000-0000-0000-0000-000000000001'::uuid,
  'a2000000-0000-0000-0000-000000000002'::uuid,
  'a2000000-0000-0000-0000-000000000003'::uuid,
  'b2000000-0000-0000-0000-000000000001'::uuid,
  'b2000000-0000-0000-0000-000000000002'::uuid
);

-- Seed 2 tenants x 2 rows each
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

-- Diagnostic: confirm claim resolves
SELECT isnt(
  public.current_tenant_id(),
  NULL::uuid,
  'Diagnostic: current_tenant_id() resolves for Tenant A'
);

-- Test 1: Tenant A sees own deals only
SELECT is(
  (SELECT count(*)::int FROM public.deals),
  2,
  'Tenant A session: total visible deals = 2 (own only)'
);

-- Test 2: Tenant A cannot read Tenant B deals
SELECT is(
  (SELECT count(*)::int FROM public.deals WHERE tenant_id = 'b0000000-0000-0000-0000-000000000001'::uuid),
  0,
  'Tenant A session: cannot read Tenant B deals'
);

-- Test 3: Tenant A cannot insert into Tenant B (WITH CHECK violation)
SELECT throws_ok(
  $tap$INSERT INTO public.deals (id, tenant_id, row_version, calc_version)
       VALUES ('b2000000-0000-0000-0000-000000000003'::uuid, 'b0000000-0000-0000-0000-000000000001'::uuid, 1, 1)$tap$,
  'new row violates row-level security policy for table "deals"',
  'Tenant A session: INSERT into Tenant B deals must fail'
);

-- Test 4: Tenant A can insert into own tenant
SELECT lives_ok(
  $tap$INSERT INTO public.deals (id, tenant_id, row_version, calc_version)
       VALUES ('a2000000-0000-0000-0000-000000000003'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 1, 1)$tap$,
  'Tenant A session: INSERT into Tenant A deals must succeed'
);

-- Test 5: Tenant A update on Tenant B affects 0 rows (RLS filters silently)
SELECT is(
  (SELECT count(*)::int FROM public.deals
     WHERE id = 'b2000000-0000-0000-0000-000000000001'::uuid),
  0,
  'Tenant A session: Tenant B deal not visible for UPDATE'
);

-- Test 6: Tenant A can update own deal
SELECT lives_ok(
  $tap$UPDATE public.deals SET row_version = row_version + 1
       WHERE id = 'a2000000-0000-0000-0000-000000000001'::uuid$tap$,
  'Tenant A session: UPDATE on Tenant A deal must succeed'
);

-- ============================================================
-- Tenant B session
-- ============================================================
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'b0000000-0000-0000-0000-000000000001', false);

-- Test 7: Tenant B sees own deals only
SELECT is(
  (SELECT count(*)::int FROM public.deals),
  2,
  'Tenant B session: total visible deals = 2 (own only)'
);

-- Test 8: Tenant B cannot read Tenant A deals
SELECT is(
  (SELECT count(*)::int FROM public.deals WHERE tenant_id = 'a0000000-0000-0000-0000-000000000001'::uuid),
  0,
  'Tenant B session: cannot read Tenant A deals'
);

-- Test 9: Tenant B delete on Tenant A affects 0 rows (RLS filters silently)
SELECT is(
  (SELECT count(*)::int FROM public.deals
     WHERE id = 'a2000000-0000-0000-0000-000000000002'::uuid),
  0,
  'Tenant B session: Tenant A deal not visible for DELETE'
);

-- Test 10: Tenant B can delete own deal
SELECT lives_ok(
  $tap$DELETE FROM public.deals WHERE id = 'b2000000-0000-0000-0000-000000000002'::uuid$tap$,
  'Tenant B session: DELETE on Tenant B deal must succeed'
);

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
