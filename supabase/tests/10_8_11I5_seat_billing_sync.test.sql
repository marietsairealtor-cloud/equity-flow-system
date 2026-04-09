-- 10.8.11I5: Seat billing sync trigger tests
BEGIN;

SELECT plan(5);

-- Seed tenant
INSERT INTO public.tenants (id, name)
VALUES ('d0000000-0000-0000-0000-000000000001', 'pgTAP Seat Sync Tenant');

-- Seed auth user for FK
INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES (
  'a0000000-0000-0000-0000-000000000001',
  'pgtap-seat-sync@example.com',
  now(), now(),
  '{}', '{}',
  'authenticated', 'authenticated'
);

-- 1. trigger_seat_sync function exists
SELECT has_function(
  'public',
  'trigger_seat_sync',
  ARRAY[]::text[],
  'trigger_seat_sync function exists'
);

-- 2. trigger_seat_sync is SECURITY DEFINER
SELECT is(
  (
    SELECT p.prosecdef
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'trigger_seat_sync'
  ),
  true,
  'trigger_seat_sync is SECURITY DEFINER'
);

-- 3. INSERT trigger exists
SELECT has_trigger(
  'public',
  'tenant_memberships',
  'on_membership_insert_sync_seats',
  'on_membership_insert_sync_seats trigger exists'
);

-- 4. DELETE trigger exists
SELECT has_trigger(
  'public',
  'tenant_memberships',
  'on_membership_delete_sync_seats',
  'on_membership_delete_sync_seats trigger exists'
);

-- 5. INSERT and DELETE do not fail (trigger is non-blocking)
SELECT lives_ok(
$tap$
  INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES (
    'f0000000-0000-0000-0000-000000000001',
    'd0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    'member'
  );
  DELETE FROM public.tenant_memberships
  WHERE id = 'f0000000-0000-0000-0000-000000000001';
$tap$,
  'INSERT and DELETE on tenant_memberships succeed with sync trigger active'
);

SELECT finish();
ROLLBACK;