-- 10.11A8: Repair Estimate Source-of-Truth Cleanup tests
BEGIN;

SELECT plan(8);

-- Seed tenant one: owner
SELECT public.create_active_workspace_seed_v1(
  'b1180000-0000-0000-0000-000000000001'::uuid,
  'a1180000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

-- Seed deal for tenant one
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1180000-0000-0000-0000-000000000001',
  'b1180000-0000-0000-0000-000000000001',
  1, 1, 'new', '123 Cleanup St', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e1180000-0000-0000-0000-000000000001',
  'b1180000-0000-0000-0000-000000000001',
  'd1180000-0000-0000-0000-000000000001',
  1,
  '{"arv":300000,"ask_price":200000,"repair_estimate":30000}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e1180000-0000-0000-0000-000000000001'
WHERE id = 'd1180000-0000-0000-0000-000000000001';

INSERT INTO public.deal_properties (
  id, tenant_id, deal_id, row_version,
  property_type, beds, condition_notes,
  created_at, updated_at
)
VALUES (
  'f1180000-0000-0000-0000-000000000001',
  'b1180000-0000-0000-0000-000000000001',
  'd1180000-0000-0000-0000-000000000001',
  1,
  'Detached', '3+1', 'Good condition',
  now(), now()
);

-- Set context: owner of tenant one
SELECT set_config('request.jwt.claims',
  '{"sub":"a1180000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1180000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 1. repair_estimate now returns VALIDATION_ERROR from update_deal_properties_v1
SELECT is(
  (public.update_deal_properties_v1('d1180000-0000-0000-0000-000000000001',
    '{"repair_estimate":12345}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: repair_estimate rejected as unknown key'
);

-- 2. normal property update still works after cleanup
SELECT is(
  (public.update_deal_properties_v1('d1180000-0000-0000-0000-000000000001',
    '{"condition_notes":"Updated condition"}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_properties_v1: normal property update still works'
);

-- 3. empty payload still returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_properties_v1('d1180000-0000-0000-0000-000000000001',
    '{}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: empty payload still returns VALIDATION_ERROR'
);

-- 4. non-object payload still returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_properties_v1('d1180000-0000-0000-0000-000000000001',
    '"lol"'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: non-object payload still returns VALIDATION_ERROR'
);

-- 5. unknown key still returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_properties_v1('d1180000-0000-0000-0000-000000000001',
    '{"seller_name":"hacker"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: unknown key still returns VALIDATION_ERROR'
);

-- 6. same-value still returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_properties_v1('d1180000-0000-0000-0000-000000000001',
    '{"property_type":"Detached"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: same-value still returns VALIDATION_ERROR'
);

-- 7. repair_estimate still accessible via pricing write path
SELECT is(
  (public.update_deal_pricing_v1('d1180000-0000-0000-0000-000000000001',
    '{"repair_estimate":25000}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_pricing_v1: repair_estimate still accepted by pricing write path'
);

-- 8. pricing repair_estimate persisted in latest deal_inputs
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT (assumptions->>'repair_estimate')::numeric FROM public.deal_inputs
   WHERE deal_id = 'd1180000-0000-0000-0000-000000000001'
   ORDER BY created_at DESC, id DESC LIMIT 1),
  25000::numeric,
  'update_deal_pricing_v1: repair_estimate persisted in latest deal_inputs row'
);

SELECT finish();
ROLLBACK;