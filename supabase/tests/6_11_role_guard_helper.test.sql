-- 6.11 Role Guard Helper -- pgTAP tests
-- Gate: pgtap (merge-blocking, live)
-- Proves: authenticated cannot EXECUTE directly; function present in catalog.

BEGIN;

SELECT plan(2);

-- Test 1: Function exists in catalog with expected signature
SELECT has_function(
  'public',
  'require_min_role_v1',
  ARRAY['tenant_role'],
  'require_min_role_v1 exists in catalog with expected signature'
);

-- Test 2: authenticated does not have EXECUTE privilege on the function
SELECT ok(
  NOT has_function_privilege(
    'authenticated',
    'public.require_min_role_v1(public.tenant_role)',
    'EXECUTE'
  ),
  'authenticated cannot EXECUTE require_min_role_v1 directly'
);

SELECT finish();

ROLLBACK;
