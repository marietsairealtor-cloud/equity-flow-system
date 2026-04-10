-- 10.8.11I7: auth_user_exists_v1 helper function tests
BEGIN;

SELECT plan(5);

SET LOCAL session_replication_role = replica;

-- Seed auth user for existence check
INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES (
  'a1000000-0000-0000-0000-000000000001',
  'exists@example.com',
  now(), now(),
  '{}', '{}',
  'authenticated', 'authenticated'
);

-- 1. Function exists
SELECT has_function(
  'public',
  'auth_user_exists_v1',
  ARRAY['text'],
  'auth_user_exists_v1(text) exists'
);

-- 2. Function is SECURITY DEFINER
SELECT is(
  (
    SELECT p.prosecdef
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'auth_user_exists_v1'
  ),
  true,
  'auth_user_exists_v1 is SECURITY DEFINER'
);

-- 3. Returns true for existing email
SELECT is(
  public.auth_user_exists_v1('exists@example.com'),
  true,
  'returns true for existing email'
);

-- 4. Returns false for non-existing email
SELECT is(
  public.auth_user_exists_v1('doesnotexist@example.com'),
  false,
  'returns false for non-existing email'
);

-- 5. Case-insensitive match
SELECT is(
  public.auth_user_exists_v1('EXISTS@EXAMPLE.COM'),
  true,
  'case-insensitive match returns true'
);

SELECT finish();
ROLLBACK;