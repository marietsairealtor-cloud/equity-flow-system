-- 6.10: pgTAP tests -- activity_log append-only
-- SQL-only: no DO blocks, no PL/pgSQL, no bare dollar-dollar sequences

BEGIN;

SELECT plan(3);

-- Seed: insert a tenant so FK constraint on activity_log.tenant_id is satisfied
INSERT INTO public.tenants (id) VALUES ('00000000-0000-0000-0000-000000000001');

-- Test 1: INSERT succeeds under valid tenant context
SELECT lives_ok(
  $tap$
    INSERT INTO public.activity_log (tenant_id, action)
    VALUES ('00000000-0000-0000-0000-000000000001', 'test.insert')
  $tap$,
  'INSERT into activity_log succeeds with valid tenant_id and action'
);

-- Test 2: UPDATE is blocked by trigger
SELECT throws_ok(
  $tap$
    UPDATE public.activity_log
    SET action = 'mutated'
    WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
  $tap$,
  'P0001',
  'activity_log_append_only: mutations are not permitted on activity_log',
  'UPDATE on activity_log raises exception'
);

-- Test 3: DELETE is blocked by trigger
SELECT throws_ok(
  $tap$
    DELETE FROM public.activity_log
    WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
  $tap$,
  'P0001',
  'activity_log_append_only: mutations are not permitted on activity_log',
  'DELETE on activity_log raises exception'
);

SELECT finish();

ROLLBACK;
