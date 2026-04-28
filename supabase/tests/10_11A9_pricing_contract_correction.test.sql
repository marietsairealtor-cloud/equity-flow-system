-- 10.11A9: Pricing Contract Correction tests
-- assignment_fee editable, mao derived server-side
BEGIN;

SELECT plan(17);

-- Seed tenant one: owner
SELECT public.create_active_workspace_seed_v1(
  'b1190000-0000-0000-0000-000000000001'::uuid,
  'a1190000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

-- Seed tenant two: cross-tenant isolation
SELECT public.create_active_workspace_seed_v1(
  'b1190000-0000-0000-0000-000000000002'::uuid,
  'a1190000-0000-0000-0000-000000000002'::uuid,
  'owner'
);

-- Seed deal for tenant one
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1190000-0000-0000-0000-000000000001',
  'b1190000-0000-0000-0000-000000000001',
  1, 1, 'new', '123 Pricing St', now(), now()
);

-- Seed base deal_inputs row
-- arv=400000, multiplier=0.70, repair=30000, assignment_fee=15000
-- mao = (400000 * 0.70) - 30000 - 15000 = 235000
INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e1190000-0000-0000-0000-000000000001',
  'b1190000-0000-0000-0000-000000000001',
  'd1190000-0000-0000-0000-000000000001',
  1,
  '{"arv":400000,"ask_price":280000,"repair_estimate":30000,"assignment_fee":15000,"multiplier":0.70,"mao":235000}'::jsonb,
  now() - interval '1 hour'
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e1190000-0000-0000-0000-000000000001'
WHERE id = 'd1190000-0000-0000-0000-000000000001';

-- Seed deal for tenant two (no deal_inputs)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1190000-0000-0000-0000-000000000002',
  'b1190000-0000-0000-0000-000000000002',
  1, 1, 'new', '456 Other St', now(), now()
);

-- Tenant-one deal with no deal_inputs (missing base pricing row)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1190000-0000-0000-0000-000000000003',
  'b1190000-0000-0000-0000-000000000001',
  1, 1, 'new', '789 No Pricing Row St', now(), now()
);

-- Set context: owner of tenant one
SELECT set_config('request.jwt.claims',
  '{"sub":"a1190000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1190000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 1. assignment_fee accepted
SELECT is(
  (public.update_deal_pricing_v1('d1190000-0000-0000-0000-000000000001',
    '{"assignment_fee":20000}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_pricing_v1: assignment_fee accepted'
);

SET LOCAL ROLE postgres;
-- 2. assignment_fee persisted (use snapshot pointer — avoids ambiguous "latest" if created_at ties)
SELECT is(
  (SELECT (di.assumptions->>'assignment_fee')::numeric
   FROM public.deals d
   JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
   WHERE d.id = 'd1190000-0000-0000-0000-000000000001'),
  20000::numeric,
  'update_deal_pricing_v1: assignment_fee persisted correctly'
);

-- 3. mao recalculated after assignment_fee change
-- new mao = (400000 * 0.70) - 30000 - 20000 = 230000
SELECT is(
  (SELECT (di.assumptions->>'mao')::numeric
   FROM public.deals d
   JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
   WHERE d.id = 'd1190000-0000-0000-0000-000000000001'),
  230000::numeric,
  'update_deal_pricing_v1: mao recalculated after assignment_fee change'
);

-- 4. deals.assumptions_snapshot_id updated
SELECT isnt(
  (SELECT assumptions_snapshot_id FROM public.deals WHERE id = 'd1190000-0000-0000-0000-000000000001'),
  'e1190000-0000-0000-0000-000000000001'::uuid,
  'update_deal_pricing_v1: assumptions_snapshot_id updated to new row'
);
SET LOCAL ROLE authenticated;

-- 5. mao rejected if client sends it
SELECT is(
  (public.update_deal_pricing_v1('d1190000-0000-0000-0000-000000000001',
    '{"mao":999999}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_pricing_v1: mao rejected if sent by client'
);

-- 6. clearing repair_estimate removes mao
SELECT is(
  (public.update_deal_pricing_v1('d1190000-0000-0000-0000-000000000001',
    '{"repair_estimate":null}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_pricing_v1: clearing repair_estimate accepted'
);

SET LOCAL ROLE postgres;
-- 7. mao removed when repair_estimate cleared
SELECT is(
  (SELECT di.assumptions->>'mao'
   FROM public.deals d
   JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
   WHERE d.id = 'd1190000-0000-0000-0000-000000000001'),
  null,
  'update_deal_pricing_v1: mao removed when repair_estimate cleared'
);
SET LOCAL ROLE authenticated;

-- 8. repair_estimate restored and mao recalculated
-- new mao = (400000 * 0.70) - 25000 - 20000 = 235000
SELECT is(
  (public.update_deal_pricing_v1('d1190000-0000-0000-0000-000000000001',
    '{"repair_estimate":25000}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_pricing_v1: repair_estimate restored accepted'
);

SET LOCAL ROLE postgres;
-- 9. mao recalculated correctly when repair_estimate restored
SELECT is(
  (SELECT (di.assumptions->>'mao')::numeric
   FROM public.deals d
   JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
   WHERE d.id = 'd1190000-0000-0000-0000-000000000001'),
  235000::numeric,
  'update_deal_pricing_v1: mao recalculated correctly when repair_estimate restored'
);
SET LOCAL ROLE authenticated;

-- 10. same-value submission returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_pricing_v1('d1190000-0000-0000-0000-000000000001',
    '{"assignment_fee":20000}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_pricing_v1: same-value submission returns VALIDATION_ERROR'
);

-- 11. empty payload returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_pricing_v1('d1190000-0000-0000-0000-000000000001',
    '{}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_pricing_v1: empty payload returns VALIDATION_ERROR'
);

-- 12. non-object payload returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_pricing_v1('d1190000-0000-0000-0000-000000000001',
    '"lol"'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_pricing_v1: non-object payload returns VALIDATION_ERROR'
);

-- 13. unknown key returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_pricing_v1('d1190000-0000-0000-0000-000000000001',
    '{"seller_name":"hacker"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_pricing_v1: unknown key returns VALIDATION_ERROR'
);

-- 14. invalid numeric returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_pricing_v1('d1190000-0000-0000-0000-000000000001',
    '{"arv":"banana"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_pricing_v1: invalid numeric returns VALIDATION_ERROR'
);

-- 15. same-tenant deal exists but no base deal_inputs row -> NOT_FOUND
SELECT is(
  (public.update_deal_pricing_v1('d1190000-0000-0000-0000-000000000003',
    '{"arv":500000}'::jsonb)::json)->>'code',
  'NOT_FOUND',
  'update_deal_pricing_v1: missing base deal_inputs row returns NOT_FOUND'
);

-- 16. cross-tenant deal returns NOT_FOUND
SELECT is(
  (public.update_deal_pricing_v1('d1190000-0000-0000-0000-000000000002',
    '{"arv":999999}'::jsonb)::json)->>'code',
  'NOT_FOUND',
  'update_deal_pricing_v1: cross-tenant deal returns NOT_FOUND'
);

-- 17. write lock rejection
SET LOCAL ROLE postgres;
UPDATE public.tenant_subscriptions
SET status = 'canceled', current_period_end = now() - interval '70 days'
WHERE tenant_id = 'b1190000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;

SELECT is(
  (public.update_deal_pricing_v1('d1190000-0000-0000-0000-000000000001',
    '{"arv":999999}'::jsonb)::json)->>'code',
  'WORKSPACE_NOT_WRITABLE',
  'update_deal_pricing_v1: expired workspace returns WORKSPACE_NOT_WRITABLE'
);

SELECT finish();
ROLLBACK;