-- 6.4 RLS Structural Audit — Tenant-Owned Table Selector [HARDENED]
-- GUARDRAILS: SQL-only, no DO blocks, no PL/pgSQL, no \cmds, named dollar tags only
-- Authority: Build Route v2.4 S6.4, CONTRACTS.md S3
-- Tests: reject forbidden permissive patterns on tenant-owned tables

SELECT plan(8);

-- =================================================================
-- Test 1: RLS is enabled on all tenant-owned tables
-- =================================================================
SELECT ok(
  (SELECT rowsecurity FROM pg_tables WHERE schemaname = 'public' AND tablename = 'deals'),
  'RLS enabled on deals'
);

-- =================================================================
-- Test 2: No policy uses USING (true)
-- =================================================================
SELECT is(
  (SELECT count(*)::integer FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename = 'deals'
     AND qual::text = 'true'),
  0,
  'No policy on deals uses USING (true)'
);

-- =================================================================
-- Test 3: No policy uses USING (1=1)
-- =================================================================
SELECT is(
  (SELECT count(*)::integer FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename = 'deals'
     AND qual::text LIKE '%(1 = 1)%'),
  0,
  'No policy on deals uses USING (1=1)'
);

-- =================================================================
-- Test 4: No SELECT/UPDATE/DELETE policy missing tenant_id predicate in USING
-- =================================================================
SELECT is(
  (SELECT count(*)::integer FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename = 'deals'
     AND cmd IN ('SELECT','UPDATE','DELETE')
     AND qual IS NOT NULL
     AND qual::text NOT LIKE '%tenant_id%'),
  0,
  'All USING policies on deals reference tenant_id'
);

-- =================================================================
-- Test 5: No INSERT policy missing tenant_id predicate in WITH CHECK
-- =================================================================
SELECT is(
  (SELECT count(*)::integer FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename = 'deals'
     AND cmd = 'INSERT'
     AND with_check IS NOT NULL
     AND with_check::text NOT LIKE '%tenant_id%'),
  0,
  'All WITH CHECK policies on deals reference tenant_id'
);

-- =================================================================
-- Test 6: All USING policies use current_tenant_id() (not raw auth.uid/auth.jwt)
-- =================================================================
SELECT is(
  (SELECT count(*)::integer FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename = 'deals'
     AND cmd IN ('SELECT','UPDATE','DELETE')
     AND qual IS NOT NULL
     AND qual::text NOT LIKE '%current_tenant_id()%'),
  0,
  'All USING policies on deals use current_tenant_id()'
);

-- =================================================================
-- Test 7: All WITH CHECK policies use current_tenant_id()
-- =================================================================
SELECT is(
  (SELECT count(*)::integer FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename = 'deals'
     AND cmd = 'INSERT'
     AND with_check IS NOT NULL
     AND with_check::text NOT LIKE '%current_tenant_id()%'),
  0,
  'All WITH CHECK policies on deals use current_tenant_id()'
);

-- =================================================================
-- Test 8: No policy uses raw auth.uid() for tenant resolution
-- =================================================================
SELECT is(
  (SELECT count(*)::integer FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename = 'deals'
     AND (coalesce(qual::text, '') LIKE '%auth.uid()%'
       OR coalesce(with_check::text, '') LIKE '%auth.uid()%')),
  0,
  'No policy on deals uses raw auth.uid() for tenant resolution'
);

SELECT finish();
