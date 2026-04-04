-- 10_8_11D_profile_settings.test.sql

BEGIN;

SELECT plan(6);

-- Test 1: function exists
SELECT has_function(
  'public',
  'get_profile_settings_v1',
  ARRAY[]::text[],
  'get_profile_settings_v1 exists in public schema'
);

-- Test 2: authenticated role can execute
SELECT ok(
  has_function_privilege('authenticated', 'public.get_profile_settings_v1()', 'EXECUTE'),
  'authenticated can execute get_profile_settings_v1'
);

-- Test 3: anon cannot execute
SELECT ok(
  NOT has_function_privilege('anon', 'public.get_profile_settings_v1()', 'EXECUTE'),
  'anon cannot execute get_profile_settings_v1'
);

-- Test 4: authenticated context returns ok=true
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;

SELECT is(
  (SELECT (public.get_profile_settings_v1() ->> 'ok')::boolean),
  true,
  'get_profile_settings_v1 returns ok=true for authenticated user'
);

SELECT is(
  (SELECT public.get_profile_settings_v1() -> 'data' ->> 'user_id'),
  'a0000000-0000-0000-0000-000000000001',
  'get_profile_settings_v1 returns correct user_id from jwt sub'
);

-- Test 5: no auth context returns NOT_AUTHORIZED
RESET "request.jwt.claims";
SET LOCAL ROLE authenticated;

SELECT is(
  (SELECT public.get_profile_settings_v1() ->> 'code'),
  'NOT_AUTHORIZED',
  'get_profile_settings_v1 returns NOT_AUTHORIZED with no jwt claims'
);

SELECT finish();

ROLLBACK;