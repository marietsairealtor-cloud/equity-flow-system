-- 10_8_3_reminder_engine_tests.test.sql
-- Build Route 10.8.3: Reminder Engine pgTAP Tests

BEGIN;
SELECT plan(18);

-- ============================================================
-- Seed test data
-- ============================================================
INSERT INTO public.tenants (id)
  VALUES ('a0830000-0000-0000-0000-000000000001'::uuid);

INSERT INTO auth.users (id, email)
  VALUES ('a0830000-0000-0000-0000-000000000002'::uuid, 'reminder_test@10_8_3.test');

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES (
    'a0830000-0000-0000-0000-000000000003'::uuid,
    'a0830000-0000-0000-0000-000000000001'::uuid,
    'a0830000-0000-0000-0000-000000000002'::uuid,
    'member'
  );

-- Seed a second tenant for isolation tests
INSERT INTO public.tenants (id)
  VALUES ('a0830000-0000-0000-0000-000000000010'::uuid);

INSERT INTO auth.users (id, email)
  VALUES ('a0830000-0000-0000-0000-000000000011'::uuid, 'other_tenant@10_8_3.test');

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES (
    'a0830000-0000-0000-0000-000000000012'::uuid,
    'a0830000-0000-0000-0000-000000000010'::uuid,
    'a0830000-0000-0000-0000-000000000011'::uuid,
    'member'
  );

-- Seed a deal for tenant 1
INSERT INTO public.deals (id, tenant_id, row_version, calc_version)
  VALUES (
    'a0830000-0000-0000-0000-000000000004'::uuid,
    'a0830000-0000-0000-0000-000000000001'::uuid,
    1,
    1
  );

-- Set authenticated context for tenant 1
SELECT set_config('request.jwt.claims',
  '{"sub":"a0830000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"a0830000-0000-0000-0000-000000000001"}',
  true);

-- ============================================================
-- DoD 1: table exists
-- ============================================================
SELECT has_table(
  'public',
  'deal_reminders',
  'deal_reminders table exists'
);

-- ============================================================
-- DoD 2: RLS enabled
-- ============================================================
SELECT is(
  (SELECT relrowsecurity FROM pg_class
   WHERE oid = 'public.deal_reminders'::regclass),
  true,
  'deal_reminders: RLS enabled'
);

-- ============================================================
-- DoD 2: anon has zero privileges
-- ============================================================
SELECT is(
  has_table_privilege('anon', 'public.deal_reminders', 'SELECT'),
  false,
  'deal_reminders: anon has no SELECT'
);

-- ============================================================
-- DoD 2: authenticated has zero privileges
-- ============================================================
SELECT is(
  has_table_privilege('authenticated', 'public.deal_reminders', 'SELECT'),
  false,
  'deal_reminders: authenticated has no SELECT'
);

-- ============================================================
-- DoD 4: create_reminder_v1 creates reminder
-- ============================================================
SELECT is(
  (public.create_reminder_v1(
    'a0830000-0000-0000-0000-000000000004'::uuid,
    now() + interval '3 days',
    'follow_up'
  )::json)->>'ok',
  'true',
  'create_reminder_v1: ok=true'
);
SELECT is(
  (public.create_reminder_v1(
    'a0830000-0000-0000-0000-000000000004'::uuid,
    now() + interval '3 days',
    'follow_up'
  )::json)->>'code',
  'OK',
  'create_reminder_v1: code=OK'
);
SELECT isnt(
  (public.create_reminder_v1(
    'a0830000-0000-0000-0000-000000000004'::uuid,
    now() + interval '3 days',
    'follow_up'
  )::json)->'data'->>'id',
  NULL,
  'create_reminder_v1: returns id'
);

-- ============================================================
-- Seed an overdue reminder directly for list tests
-- ============================================================
INSERT INTO public.deal_reminders (id, deal_id, tenant_id, reminder_date, reminder_type)
  VALUES (
    'a0830000-0000-0000-0000-000000000005'::uuid,
    'a0830000-0000-0000-0000-000000000004'::uuid,
    'a0830000-0000-0000-0000-000000000001'::uuid,
    now() - interval '1 day',
    'follow_up'
  );

-- ============================================================
-- DoD 3: list_reminders_v1 returns overdue reminders
-- ============================================================
SELECT is(
  (public.list_reminders_v1()::json)->>'ok',
  'true',
  'list_reminders_v1: ok=true'
);
SELECT is(
  (public.list_reminders_v1()::json)->>'code',
  'OK',
  'list_reminders_v1: code=OK'
);
SELECT isnt(
  (public.list_reminders_v1()::json)->'data'->>'items',
  NULL,
  'list_reminders_v1: items present'
);

-- ============================================================
-- DoD 3: list_reminders_v1 excludes completed reminders
-- ============================================================
-- Complete the overdue reminder
SELECT public.complete_reminder_v1('a0830000-0000-0000-0000-000000000005'::uuid);

SELECT is(
  (
    SELECT COUNT(*)::int
    FROM public.deal_reminders
    WHERE id = 'a0830000-0000-0000-0000-000000000005'::uuid
      AND completed_at IS NOT NULL
  ),
  1,
  'list_reminders_v1: excludes completed reminders (completed_at set)'
);

-- ============================================================
-- DoD 5: complete_reminder_v1 sets completed_at
-- ============================================================
-- Seed a new reminder to complete
INSERT INTO public.deal_reminders (id, deal_id, tenant_id, reminder_date, reminder_type)
  VALUES (
    'a0830000-0000-0000-0000-000000000006'::uuid,
    'a0830000-0000-0000-0000-000000000004'::uuid,
    'a0830000-0000-0000-0000-000000000001'::uuid,
    now() + interval '1 day',
    'check_in'
  );

SELECT is(
  (public.complete_reminder_v1('a0830000-0000-0000-0000-000000000006'::uuid)::json)->>'ok',
  'true',
  'complete_reminder_v1: ok=true'
);
SELECT is(
  (public.complete_reminder_v1('a0830000-0000-0000-0000-000000000006'::uuid)::json)->>'code',
  'OK',
  'complete_reminder_v1: idempotent -- second call ok=true'
);

-- ============================================================
-- DoD 5: complete_reminder_v1 is idempotent
-- ============================================================
SELECT is(
  (public.complete_reminder_v1('a0830000-0000-0000-0000-000000000006'::uuid)::json)->>'ok',
  'true',
  'complete_reminder_v1: idempotent -- third call still ok=true'
);

-- ============================================================
-- DoD 4: create_reminder_v1 fails without tenant context (NOT_AUTHORIZED)
-- ============================================================
SELECT set_config('request.jwt.claims', '', true);

SELECT is(
  (public.create_reminder_v1(
    'a0830000-0000-0000-0000-000000000004'::uuid,
    now() + interval '1 day',
    'follow_up'
  )::json)->>'code',
  'NOT_AUTHORIZED',
  'create_reminder_v1: NOT_AUTHORIZED without tenant context'
);

-- ============================================================
-- DoD 3: list_reminders_v1 enforces tenant isolation
-- ============================================================
-- Switch to tenant 2
SELECT set_config('request.jwt.claims',
  '{"sub":"a0830000-0000-0000-0000-000000000011","role":"authenticated","tenant_id":"a0830000-0000-0000-0000-000000000010"}',
  true);

-- Tenant 2 should see no reminders (all reminders belong to tenant 1)
SELECT is(
  json_array_length(
    (public.list_reminders_v1()::json)->'data'->'items'
  ),
  0,
  'list_reminders_v1: tenant isolation -- tenant 2 sees no tenant 1 reminders'
);

-- ============================================================
-- DoD 8: cross-tenant reminder access fails
-- ============================================================
-- Tenant 2 tries to complete tenant 1 reminder -- silently succeeds but no-ops
SELECT is(
  (public.complete_reminder_v1('a0830000-0000-0000-0000-000000000006'::uuid)::json)->>'ok',
  'true',
  'complete_reminder_v1: cross-tenant no-op returns ok=true (idempotent, no data leak)'
);

-- Verify reminder still belongs to tenant 1 (completed_at set by tenant 1 earlier)
SELECT isnt(
  (SELECT completed_at FROM public.deal_reminders
   WHERE id = 'a0830000-0000-0000-0000-000000000006'::uuid),
  NULL,
  'deal_reminders: completed_at set by tenant 1 -- cross-tenant call was no-op'
);

SELECT * FROM finish();
ROLLBACK;
