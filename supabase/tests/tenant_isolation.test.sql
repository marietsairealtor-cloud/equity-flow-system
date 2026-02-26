-- 6.3 Tenant Integrity Suite — Negative Isolation Tests
-- GUARDRAILS §25-28: SQL-only, no DO blocks, no PL/pgSQL, no \cmds, named dollar tags only
-- plan: 12 tests

SELECT plan(12);

-- ============================================================
-- SEED: Two tenants, two users, 2 rows each in tenant-scoped tables
-- ============================================================

-- Tenant A
INSERT INTO public.tenants (id, name)
VALUES
  ('a0000000-0000-0000-0000-000000000001'::uuid, 'Tenant A Row 1'),
  ('a0000000-0000-0000-0000-000000000002'::uuid, 'Tenant A Row 2');

-- Tenant B
INSERT INTO public.tenants (id, name)
VALUES
  ('b0000000-0000-0000-0000-000000000001'::uuid, 'Tenant B Row 1'),
  ('b0000000-0000-0000-0000-000000000002'::uuid, 'Tenant B Row 2');

-- Users for Tenant A
INSERT INTO auth.users (id, email) VALUES
  ('a1000000-0000-0000-0000-000000000001'::uuid, 'usera1@test.local'),
  ('a1000000-0000-0000-0000-000000000002'::uuid, 'usera2@test.local');

-- Users for Tenant B
INSERT INTO auth.users (id, email) VALUES
  ('b1000000-0000-0000-0000-000000000001'::uuid, 'userb1@test.local'),
  ('b1000000-0000-0000-0000-000000000002'::uuid, 'userb2@test.local');

-- Tenant memberships
INSERT INTO public.tenant_memberships (tenant_id, user_id, role) VALUES
  ('a0000000-0000-0000-0000-000000000001'::uuid, 'a1000000-0000-0000-0000-000000000001'::uuid, 'owner'),
  ('a0000000-0000-0000-0000-000000000001'::uuid, 'a1000000-0000-0000-0000-000000000002'::uuid, 'member');

INSERT INTO public.tenant_memberships (tenant_id, user_id, role) VALUES
  ('b0000000-0000-0000-0000-000000000001'::uuid, 'b1000000-0000-0000-0000-000000000001'::uuid, 'owner'),
  ('b0000000-0000-0000-0000-000000000001'::uuid, 'b1000000-0000-0000-0000-000000000002'::uuid, 'member');

-- Deals for Tenant A (2 rows)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version)
VALUES
  ('a2000000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 1, 1),
  ('a2000000-0000-0000-0000-000000000002'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 1, 1);

-- Deals for Tenant B (2 rows)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version)
VALUES
  ('b2000000-0000-0000-0000-000000000001'::uuid, 'b0000000-0000-0000-0000-000000000001'::uuid, 1, 1),
  ('b2000000-0000-0000-0000-000000000002'::uuid, 'b0000000-0000-0000-0000-000000000001'::uuid, 1, 1);

-- ============================================================
-- Set session context: Tenant A user
-- ============================================================
SET LOCAL role TO authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

-- Test 1: Tenant A can see own deals
SELECT is(
  (SELECT count(*)::int FROM public.deals WHERE tenant_id = 'a0000000-0000-0000-0000-000000000001'::uuid),
  2,
  'Tenant A session: can read own 2 deals'
);

-- Test 2: Tenant A cannot see Tenant B deals
SELECT is(
  (SELECT count(*)::int FROM public.deals WHERE tenant_id = 'b0000000-0000-0000-0000-000000000001'::uuid),
  0,
  'Tenant A session: cannot read Tenant B deals'
);

-- Test 3: Tenant A total visible deals = 2 (not 4)
SELECT is(
  (SELECT count(*)::int FROM public.deals),
  2,
  'Tenant A session: total visible deals = 2, not 4'
);

-- Test 4: Tenant A cannot see Tenant B memberships
SELECT is(
  (SELECT count(*)::int FROM public.tenant_memberships WHERE tenant_id = 'b0000000-0000-0000-0000-000000000001'::uuid),
  0,
  'Tenant A session: cannot read Tenant B memberships'
);

-- Test 5: INSERT into Tenant B deals fails
SELECT throws_ok(
  $tap$INSERT INTO public.deals (id, tenant_id, row_version, calc_version)
       VALUES ('c0000000-0000-0000-0000-000000000001'::uuid, 'b0000000-0000-0000-0000-000000000001'::uuid, 1, 1)$tap$,
  'Tenant A session: INSERT into Tenant B deals must fail'
);

-- Test 6: UPDATE Tenant B deal fails
SELECT throws_ok(
  $tap$UPDATE public.deals SET calc_version = 99
       WHERE id = 'b2000000-0000-0000-0000-000000000001'::uuid$tap$,
  'Tenant A session: UPDATE on Tenant B deal must fail'
);

-- ============================================================
-- Set session context: Tenant B user
-- ============================================================
SELECT set_config('request.jwt.claims', '{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

-- Test 7: Tenant B can see own deals
SELECT is(
  (SELECT count(*)::int FROM public.deals WHERE tenant_id = 'b0000000-0000-0000-0000-000000000001'::uuid),
  2,
  'Tenant B session: can read own 2 deals'
);

-- Test 8: Tenant B cannot see Tenant A deals
SELECT is(
  (SELECT count(*)::int FROM public.deals WHERE tenant_id = 'a0000000-0000-0000-0000-000000000001'::uuid),
  0,
  'Tenant B session: cannot read Tenant A deals'
);

-- Test 9: Tenant B total visible deals = 2
SELECT is(
  (SELECT count(*)::int FROM public.deals),
  2,
  'Tenant B session: total visible deals = 2, not 4'
);

-- ============================================================
-- View-based access: no views in public schema
-- ============================================================

-- Test 10: No views exist in public schema
SELECT is(
  (SELECT count(*)::int FROM pg_views WHERE schemaname = 'public'),
  0,
  'No views in public schema — view-based cross-tenant access not possible'
);

-- ============================================================
-- Reset role
-- ============================================================
RESET role;

-- ============================================================
-- Background context: no triggers or pg_cron jobs exist
-- ============================================================

-- Test 11: No triggers on tenant-scoped tables
SELECT is(
  (SELECT count(*)::int FROM information_schema.triggers WHERE trigger_schema = 'public'),
  0,
  'No triggers on public schema tables — no background context risk'
);

-- Test 12: No pg_cron jobs exist
SELECT is(
  (SELECT count(*)::int FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'cron'),
  0,
  'No pg_cron functions exist — no background context risk'
);

SELECT finish();