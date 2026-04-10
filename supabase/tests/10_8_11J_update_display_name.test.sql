-- 10.8.11J: update_display_name_v1 + get_profile_settings_v1 display_name read
BEGIN;

SELECT plan(9);

-- Seed auth users
INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES
  ('a3000000-0000-0000-0000-000000000001', 'pgtap-j1@example.com', now(), now(), '{}', '{}', 'authenticated', 'authenticated'),
  ('a3000000-0000-0000-0000-000000000002', 'pgtap-j2@example.com', now(), now(), '{}', '{}', 'authenticated', 'authenticated');

-- Seed user profiles
INSERT INTO public.user_profiles (id)
VALUES
  ('a3000000-0000-0000-0000-000000000001'),
  ('a3000000-0000-0000-0000-000000000002');

-- 1. function exists
SELECT has_function(
  'public',
  'update_display_name_v1',
  ARRAY['text'],
  'update_display_name_v1(text) exists'
);

-- 2. authenticated can execute
SELECT ok(
  has_function_privilege('authenticated', 'public.update_display_name_v1(text)', 'EXECUTE'),
  'authenticated can execute update_display_name_v1'
);

-- 3. anon cannot execute
SELECT ok(
  NOT has_function_privilege('anon', 'public.update_display_name_v1(text)', 'EXECUTE'),
  'anon cannot execute update_display_name_v1'
);

SET LOCAL "request.jwt.claims" TO '{"sub":"a3000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;

-- 4. success + DB state updated
SELECT is(
  (SELECT (public.update_display_name_v1('Marie Test') ->> 'ok')::boolean),
  true,
  'update_display_name_v1 returns ok=true'
);

RESET ROLE;
SELECT is(
  (SELECT display_name FROM public.user_profiles WHERE id = 'a3000000-0000-0000-0000-000000000001'),
  'Marie Test',
  'display_name updated in user_profiles'
);

-- 5. blank validation returns VALIDATION_ERROR
SET LOCAL "request.jwt.claims" TO '{"sub":"a3000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;

SELECT is(
  (SELECT public.update_display_name_v1('') ->> 'code'),
  'VALIDATION_ERROR',
  'blank display_name returns VALIDATION_ERROR'
);

-- 6. get_profile_settings_v1 returns saved display_name
SELECT is(
  (SELECT public.get_profile_settings_v1() -> 'data' ->> 'display_name'),
  'Marie Test',
  'get_profile_settings_v1 returns saved display_name'
);

-- 7. isolation -- user 2 cannot update user 1 profile
SET LOCAL "request.jwt.claims" TO '{"sub":"a3000000-0000-0000-0000-000000000002","role":"authenticated"}';
SET LOCAL ROLE authenticated;

SELECT lives_ok(
$tap$
  SELECT public.update_display_name_v1('Hacker Name');
$tap$,
  'user 2 update runs without error'
);

RESET ROLE;
SELECT is(
  (SELECT display_name FROM public.user_profiles WHERE id = 'a3000000-0000-0000-0000-000000000001'),
  'Marie Test',
  'user 1 display_name unchanged after user 2 update'
);

SELECT finish();
ROLLBACK;
