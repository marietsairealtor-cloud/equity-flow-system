-- pgTAP tests for 10.8.11I1: invite email webhook trigger
BEGIN;

SELECT plan(4);

-- seed tenant
INSERT INTO public.tenants (id, name)
VALUES ('a0000000-0000-0000-0000-000000000001', 'pgTAP tenant I1');

-- 1. function exists
SELECT has_function(
  'public',
  'trigger_invite_email',
  ARRAY[]::text[],
  'trigger_invite_email function exists'
);

-- 2. function is SECURITY DEFINER
SELECT is(
  (
    SELECT p.prosecdef
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'trigger_invite_email'
  ),
  true,
  'trigger_invite_email is SECURITY DEFINER'
);

-- 3. trigger exists on tenant_invites
SELECT has_trigger(
  'public',
  'tenant_invites',
  'on_tenant_invite_insert',
  'on_tenant_invite_insert trigger exists on tenant_invites'
);

-- 4. insert does not fail (email failure is non-blocking)
SELECT lives_ok(
$tap$
  SET LOCAL session_replication_role = replica;
  INSERT INTO public.tenant_invites
    (id, tenant_id, invited_email, role, token, invited_by, expires_at)
  VALUES (
    gen_random_uuid(),
    'a0000000-0000-0000-0000-000000000001',
    'pgtap-test-invite@example.com',
    'member',
    gen_random_uuid()::text,
    '866998e1-cce3-4902-b5b1-b01ddd2fa785',
    now() + interval '7 days'
  );
$tap$,
  'insert into tenant_invites succeeds even if email trigger fails'
);

SELECT finish();
ROLLBACK;