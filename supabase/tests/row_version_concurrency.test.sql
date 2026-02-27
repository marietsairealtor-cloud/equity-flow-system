-- supabase/tests/row_version_concurrency.test.sql
-- 6.6: pgTAP concurrency + RPC conflict envelope tests.
-- Proves: stale row_version update blocked, RPC returns CONFLICT envelope.
-- Plain SQL only. No DO blocks. No PL/pgSQL. No psql meta-commands. No $$ tags.
BEGIN;
SELECT plan(8);

-- Seed: insert deal with NULL snapshot first (deferred FK allows within transaction)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES (
  '00000000-0000-0000-0000-000000000002'::uuid,
  '00000000-0000-0000-0000-000000000001'::uuid,
  1, 1, NULL
);

-- Insert deal_inputs snapshot (tenant-match trigger fires — tenant matches deal)
INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
VALUES (
  '00000000-0000-0000-0000-000000000010'::uuid,
  '00000000-0000-0000-0000-000000000001'::uuid,
  '00000000-0000-0000-0000-000000000002'::uuid,
  1, 1, '{}'::jsonb
);

-- Set snapshot reference on deal (completes circular FK)
UPDATE public.deals
SET assumptions_snapshot_id = '00000000-0000-0000-0000-000000000010'::uuid
WHERE id = '00000000-0000-0000-0000-000000000002'::uuid;

-- Test 1: Confirm seeded row_version is 1
SELECT is(
  (SELECT row_version FROM public.deals WHERE id = '00000000-0000-0000-0000-000000000002'::uuid),
  1::bigint,
  'deals row_version starts at 1'
);

-- Simulate first concurrent UPDATE (expected row_version = 1) — succeeds
UPDATE public.deals
SET row_version  = row_version + 1,
    calc_version = 2
WHERE id         = '00000000-0000-0000-0000-000000000002'::uuid
  AND tenant_id  = '00000000-0000-0000-0000-000000000001'::uuid
  AND row_version = 1;

-- Test 2: row_version incremented to 2 after first update
SELECT is(
  (SELECT row_version FROM public.deals WHERE id = '00000000-0000-0000-0000-000000000002'::uuid),
  2::bigint,
  'first UPDATE increments row_version to 2'
);

-- Test 3: calc_version updated by first update
SELECT is(
  (SELECT calc_version FROM public.deals WHERE id = '00000000-0000-0000-0000-000000000002'::uuid),
  2,
  'first UPDATE sets calc_version to 2'
);

-- Simulate second concurrent UPDATE using STALE expected row_version = 1
WITH stale_update AS (
  UPDATE public.deals
  SET row_version  = row_version + 1,
      calc_version = 99
  WHERE id         = '00000000-0000-0000-0000-000000000002'::uuid
    AND tenant_id  = '00000000-0000-0000-0000-000000000001'::uuid
    AND row_version = 1
  RETURNING id
)
SELECT is(
  (SELECT COUNT(*)::int FROM stale_update),
  0,
  'stale UPDATE matches 0 rows (row_version mismatch blocks it)'
);

-- Test 5: row_version must still be 2
SELECT is(
  (SELECT row_version FROM public.deals WHERE id = '00000000-0000-0000-0000-000000000002'::uuid),
  2::bigint,
  'row_version remains 2 after stale UPDATE attempt'
);

-- Test 6: calc_version must still be 2
SELECT is(
  (SELECT calc_version FROM public.deals WHERE id = '00000000-0000-0000-0000-000000000002'::uuid),
  2,
  'calc_version remains 2 — stale UPDATE never overwrote'
);

-- =============================================================
-- RPC conflict envelope tests (6.6 DoD: CONFLICT response proof)
-- Reset row_version back to 1 for RPC test
-- =============================================================
UPDATE public.deals
SET row_version = 1
WHERE id = '00000000-0000-0000-0000-000000000002'::uuid;

-- Switch to authenticated role with tenant context
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', '00000000-0000-0000-0000-000000000001', true);

-- Test 7: first RPC update succeeds (ok=true)
SELECT is(
  ((public.update_deal_v1(
    '00000000-0000-0000-0000-000000000002'::uuid, 1::bigint, 2
  ))::json ->> 'ok')::boolean,
  true,
  'update_deal_v1: first update ok=true'
);

-- Test 8: second RPC update with same stale row_version returns CONFLICT
SELECT is(
  (public.update_deal_v1(
    '00000000-0000-0000-0000-000000000002'::uuid, 1::bigint, 2
  ))::json ->> 'code',
  'CONFLICT',
  'update_deal_v1: stale update returns CONFLICT'
);

SELECT * FROM finish();
ROLLBACK;
