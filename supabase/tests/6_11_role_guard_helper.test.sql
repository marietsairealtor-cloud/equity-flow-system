-- 6.11 Role Guard Helper — pgTAP tests
-- Gate: pgtap (merge-blocking, live)
-- Proves: authenticated cannot EXECUTE directly; function present in catalog.

SELECT plan(2);

-- Test 1: Function exists in catalog with expected signature
SELECT has_function(
  'public',
  'require_min_role_v1',
  ARRAY['public.tenant_role'],
  'require_min_role_v1 exists in catalog with expected signature'
);

-- Test 2: authenticated cannot execute the function directly
SELECT throws_ok(
  $tap$
    SET ROLE authenticated;
    SELECT public.require_min_role_v1('member'::public.tenant_role);
  $tap$,
  '42501',
  NULL,
  'authenticated cannot EXECUTE require_min_role_v1 directly'
);

SELECT finish();