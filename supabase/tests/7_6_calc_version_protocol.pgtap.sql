-- 7.6: pgTAP test -- calc_version protocol
-- Proves: deal seeded at calc_version=1 returns identical input values
-- after calc_version context increments to 2. Field-by-field assertion.
-- SQL-only: no DO blocks, no PL/pgSQL, no bare dollar-dollar sequences.

BEGIN;

SELECT plan(6);

-- Seed tenant
INSERT INTO public.tenants (id)
VALUES ('d0000000-0000-0000-0000-000000000001'::uuid);

SET CONSTRAINTS ALL DEFERRED;

-- Seed deal at calc_version=1
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES (
  'd1000000-0000-0000-0000-000000000001'::uuid,
  'd0000000-0000-0000-0000-000000000001'::uuid,
  1, 1,
  'd2000000-0000-0000-0000-000000000001'::uuid
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
VALUES (
  'd2000000-0000-0000-0000-000000000001'::uuid,
  'd0000000-0000-0000-0000-000000000001'::uuid,
  'd1000000-0000-0000-0000-000000000001'::uuid,
  1, 1,
  '{"purchase_price": 500000, "down_payment": 100000, "rate": 0.065}'::jsonb
);

-- Simulate calc_version increment: insert calc_version=2 into calc_versions table
INSERT INTO public.calc_versions (id, label, released_at)
VALUES (2, 'v2-test', now());

-- Test 1: deal exists at calc_version=1
SELECT is(
  (SELECT calc_version FROM public.deals WHERE id = 'd1000000-0000-0000-0000-000000000001'::uuid),
  1,
  'Deal is seeded at calc_version=1'
);

-- Test 2: deal_inputs row exists for calc_version=1
SELECT is(
  (SELECT calc_version FROM public.deal_inputs WHERE deal_id = 'd1000000-0000-0000-0000-000000000001'::uuid AND calc_version = 1),
  1,
  'deal_inputs row exists at calc_version=1'
);

-- Test 3: assumptions.purchase_price unchanged after version increment
SELECT is(
  (SELECT assumptions->>'purchase_price' FROM public.deal_inputs
   WHERE deal_id = 'd1000000-0000-0000-0000-000000000001'::uuid AND calc_version = 1),
  '500000',
  'assumptions.purchase_price identical after calc_version increment'
);

-- Test 4: assumptions.down_payment unchanged
SELECT is(
  (SELECT assumptions->>'down_payment' FROM public.deal_inputs
   WHERE deal_id = 'd1000000-0000-0000-0000-000000000001'::uuid AND calc_version = 1),
  '100000',
  'assumptions.down_payment identical after calc_version increment'
);

-- Test 5: assumptions.rate unchanged
SELECT is(
  (SELECT assumptions->>'rate' FROM public.deal_inputs
   WHERE deal_id = 'd1000000-0000-0000-0000-000000000001'::uuid AND calc_version = 1),
  '0.065',
  'assumptions.rate identical after calc_version increment'
);

-- Test 6: calc_version=2 exists in registry but deal_inputs at v1 is unaffected
SELECT is(
  (SELECT COUNT(*)::integer FROM public.deal_inputs
   WHERE deal_id = 'd1000000-0000-0000-0000-000000000001'::uuid AND calc_version = 1),
  1,
  'Only one deal_inputs row at calc_version=1 -- no silent mutation from version increment'
);

SELECT finish();

ROLLBACK;
