-- 10.11A7: Deal Pricing Write Path tests
BEGIN;

SELECT plan(16);

-- Seed tenant one: owner
SELECT public.create_active_workspace_seed_v1(
  'b1170000-0000-0000-0000-000000000001'::uuid,
  'a1170000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

-- Seed tenant two: cross-tenant isolation
SELECT public.create_active_workspace_seed_v1(
  'b1170000-0000-0000-0000-000000000002'::uuid,
  'a1170000-0000-0000-0000-000000000002'::uuid,
  'owner'
);

-- Seed deal for tenant one
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1170000-0000-0000-0000-000000000001',
  'b1170000-0000-0000-0000-000000000001',
  1, 1, 'new', '123 Pricing St', now(), now()
);

-- Seed base deal_inputs row
INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e1170000-0000-0000-0000-000000000001',
  'b1170000-0000-0000-0000-000000000001',
  'd1170000-0000-0000-0000-000000000001',
  1,
  '{"arv":300000,"ask_price":200000,"repair_estimate":30000,"mao":180000,"multiplier":0.70,"calc_version":"mao_v1"}'::jsonb,
  now() - interval '1 hour'
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e1170000-0000-0000-0000-000000000001'
WHERE id = 'd1170000-0000-0000-0000-000000000001';

-- Seed deal for tenant two (no deal_inputs)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1170000-0000-0000-0000-000000000002',
  'b1170000-0000-0000-0000-000000000002',
  1, 1, 'new', '456 Other St', now(), now()
);

-- Set context: owner of tenant one
SELECT set_config('request.jwt.claims',
  '{"sub":"a1170000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1170000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 1. success: update arv
SELECT is(
  (public.update_deal_pricing_v1('d1170000-0000-0000-0000-000000000001',
    '{"arv":350000}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_pricing_v1: success on valid field update'
);

-- 2. new deal_inputs row was inserted (now 2 rows)
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_inputs WHERE deal_id = 'd1170000-0000-0000-0000-000000000001'),
  2,
  'update_deal_pricing_v1: new deal_inputs row inserted'
);

-- 3. latest row has updated arv
SELECT is(
  (SELECT (assumptions->>'arv')::numeric FROM public.deal_inputs
   WHERE deal_id = 'd1170000-0000-0000-0000-000000000001'
   ORDER BY created_at DESC, id DESC LIMIT 1),
  350000::numeric,
  'update_deal_pricing_v1: new row has updated arv'
);

-- 4. omitted fields carried forward from base
SELECT is(
  (SELECT (assumptions->>'ask_price')::numeric FROM public.deal_inputs
   WHERE deal_id = 'd1170000-0000-0000-0000-000000000001'
   ORDER BY created_at DESC, id DESC LIMIT 1),
  200000::numeric,
  'update_deal_pricing_v1: omitted field carried forward from base'
);

-- 5. deals.assumptions_snapshot_id updated to new row
SELECT is(
  (SELECT di.assumptions->>'arv' FROM public.deals d
   JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
   WHERE d.id = 'd1170000-0000-0000-0000-000000000001'),
  '350000',
  'update_deal_pricing_v1: snapshot pointer updated to new row'
);

-- 6. deals.row_version incremented
SELECT is(
  (SELECT row_version FROM public.deals WHERE id = 'd1170000-0000-0000-0000-000000000001'),
  2::bigint,
  'update_deal_pricing_v1: deals.row_version incremented'
);
SET LOCAL ROLE authenticated;

-- 7. explicit null clears field in new snapshot
SELECT is(
  (public.update_deal_pricing_v1('d1170000-0000-0000-0000-000000000001',
    '{"mao":null}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_pricing_v1: explicit null accepted'
);

SET LOCAL ROLE postgres;
-- 8. explicit null clears field in latest row
SELECT is(
  (SELECT assumptions->>'mao' FROM public.deal_inputs
   WHERE deal_id = 'd1170000-0000-0000-0000-000000000001'
   ORDER BY created_at DESC, id DESC LIMIT 1),
  null,
  'update_deal_pricing_v1: explicit null clears field in new snapshot'
);
SET LOCAL ROLE authenticated;

-- 9. same-value submission returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_pricing_v1('d1170000-0000-0000-0000-000000000001',
    '{"arv":350000}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_pricing_v1: same-value submission returns VALIDATION_ERROR'
);

-- 10. empty payload returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_pricing_v1('d1170000-0000-0000-0000-000000000001',
    '{}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_pricing_v1: empty payload returns VALIDATION_ERROR'
);

-- 11. non-object payload returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_pricing_v1('d1170000-0000-0000-0000-000000000001',
    '"lol"'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_pricing_v1: non-object payload returns VALIDATION_ERROR'
);

-- 12. unknown key returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_pricing_v1('d1170000-0000-0000-0000-000000000001',
    '{"seller_name":"hacker"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_pricing_v1: unknown key returns VALIDATION_ERROR'
);

-- 13. invalid numeric input returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_pricing_v1('d1170000-0000-0000-0000-000000000001',
    '{"arv":"banana"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_pricing_v1: invalid numeric returns VALIDATION_ERROR'
);

-- 14. cross-tenant deal returns NOT_FOUND
SELECT is(
  (public.update_deal_pricing_v1('d1170000-0000-0000-0000-000000000002',
    '{"arv":999999}'::jsonb)::json)->>'code',
  'NOT_FOUND',
  'update_deal_pricing_v1: cross-tenant deal returns NOT_FOUND'
);

-- 15. missing base deal_inputs row returns NOT_FOUND
SELECT set_config('request.jwt.claims',
  '{"sub":"a1170000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"b1170000-0000-0000-0000-000000000002"}',
  true);

SELECT is(
  (public.update_deal_pricing_v1('d1170000-0000-0000-0000-000000000002',
    '{"arv":999999}'::jsonb)::json)->>'code',
  'NOT_FOUND',
  'update_deal_pricing_v1: missing base deal_inputs row returns NOT_FOUND'
);

-- 16. write lock rejection
SET LOCAL ROLE postgres;
UPDATE public.tenant_subscriptions
SET status = 'canceled', current_period_end = now() - interval '70 days'
WHERE tenant_id = 'b1170000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;

SELECT set_config('request.jwt.claims',
  '{"sub":"a1170000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1170000-0000-0000-0000-000000000001"}',
  true);

SELECT is(
  (public.update_deal_pricing_v1('d1170000-0000-0000-0000-000000000001',
    '{"arv":999999}'::jsonb)::json)->>'code',
  'WORKSPACE_NOT_WRITABLE',
  'update_deal_pricing_v1: expired workspace returns WORKSPACE_NOT_WRITABLE'
);

SELECT finish();
ROLLBACK;