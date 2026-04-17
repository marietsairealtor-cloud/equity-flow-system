-- 10_8_11D_profile_settings.test.sql
-- Updated 10.8.12A: added has_used_trial field assertions
BEGIN;

SELECT plan(8);

-- ===================================================================
-- Seed user and profile for authenticated context tests
-- ===================================================================
INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES ('a0000000-0000-0000-0000-000000000001', 'profile-test@test.local', now(), now(), '{}', '{}', 'authenticated', 'authenticated')
ON CONFLICT DO NOTHING;

INSERT INTO public.user_profiles (id, has_used_trial)
VALUES ('a0000000-0000-0000-0000-000000000001', false)
ON CONFLICT (id) DO UPDATE SET has_used_trial = false;

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

-- Test 5: correct user_id returned
SELECT is(
  (SELECT public.get_profile_settings_v1() -> 'data' ->> 'user_id'),
  'a0000000-0000-0000-0000-000000000001',
  'get_profile_settings_v1 returns correct user_id from jwt sub'
);

-- Test 6: has_used_trial field is present in data
SELECT ok(
  ((SELECT public.get_profile_settings_v1() -> 'data' ->> 'has_used_trial') IS NOT NULL),
  'get_profile_settings_v1 returns has_used_trial field'
);

-- Test 7: has_used_trial = false for seeded user with no trial used
SELECT is(
  (SELECT (public.get_profile_settings_v1() -> 'data' ->> 'has_used_trial')::boolean),
  false,
  'get_profile_settings_v1 returns has_used_trial=false for user with no trial used'
);

-- Test 8: no auth context returns NOT_AUTHORIZED
RESET "request.jwt.claims";
SET LOCAL ROLE authenticated;

SELECT is(
  (SELECT public.get_profile_settings_v1() ->> 'code'),
  'NOT_AUTHORIZED',
  'get_profile_settings_v1 returns NOT_AUTHORIZED with no jwt claims'
);

SELECT finish();
ROLLBACK;