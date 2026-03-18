-- 10_8_1A_subscriptions_table_tests.test.sql
-- Build Route 10.8.1A: Subscriptions Table pgTAP Tests

BEGIN;
SELECT plan(12);

-- ============================================================
-- Table existence
-- ============================================================
SELECT has_table(
  'public',
  'tenant_subscriptions',
  'tenant_subscriptions table exists'
);

-- ============================================================
-- RLS enabled
-- ============================================================
SELECT is(
  (SELECT relrowsecurity FROM pg_class
   WHERE oid = 'public.tenant_subscriptions'::regclass),
  true,
  'tenant_subscriptions: RLS enabled'
);

-- ============================================================
-- anon has zero privileges
-- ============================================================
SELECT is(
  has_table_privilege('anon', 'public.tenant_subscriptions', 'SELECT'),
  false,
  'tenant_subscriptions: anon has no SELECT'
);
SELECT is(
  has_table_privilege('anon', 'public.tenant_subscriptions', 'INSERT'),
  false,
  'tenant_subscriptions: anon has no INSERT'
);

-- ============================================================
-- authenticated has zero privileges
-- ============================================================
SELECT is(
  has_table_privilege('authenticated', 'public.tenant_subscriptions', 'SELECT'),
  false,
  'tenant_subscriptions: authenticated has no SELECT'
);
SELECT is(
  has_table_privilege('authenticated', 'public.tenant_subscriptions', 'INSERT'),
  false,
  'tenant_subscriptions: authenticated has no INSERT'
);

-- ============================================================
-- tenant_id NOT NULL enforced
-- ============================================================
SELECT throws_ok(
  $tap$
    INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
    VALUES (NULL, 'active', now() + interval '30 days')
  $tap$,
  NULL, NULL,
  'tenant_subscriptions: tenant_id NOT NULL enforced'
);

-- ============================================================
-- status CHECK constraint enforced
-- ============================================================
SELECT throws_ok(
  $tap$
    INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
    VALUES (gen_random_uuid(), 'invalid_status', now() + interval '30 days')
  $tap$,
  NULL, NULL,
  'tenant_subscriptions: status CHECK constraint enforced'
);

-- ============================================================
-- unique constraint on tenant_id enforced
-- ============================================================
SELECT lives_ok(
  $tap$
    INSERT INTO public.tenants (id) VALUES ('b0810000-0000-0000-0000-000000000001'::uuid)
  $tap$,
  'seed tenant for unique constraint test'
);

SELECT lives_ok(
  $tap$
    INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
    VALUES ('b0810000-0000-0000-0000-000000000001'::uuid, 'active', now() + interval '30 days')
  $tap$,
  'first subscription insert succeeds'
);

SELECT throws_ok(
  $tap$
    INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
    VALUES ('b0810000-0000-0000-0000-000000000001'::uuid, 'active', now() + interval '30 days')
  $tap$,
  NULL, NULL,
  'tenant_subscriptions: unique constraint on tenant_id enforced'
);

-- ============================================================
-- valid status values accepted
-- ============================================================
SELECT lives_ok(
  $tap$
    INSERT INTO public.tenants (id) VALUES ('b0810000-0000-0000-0000-000000000002'::uuid);
    INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
    VALUES ('b0810000-0000-0000-0000-000000000002'::uuid, 'expiring', now() + interval '3 days');
  $tap$,
  'tenant_subscriptions: expiring status accepted'
);

SELECT * FROM finish();
ROLLBACK;
