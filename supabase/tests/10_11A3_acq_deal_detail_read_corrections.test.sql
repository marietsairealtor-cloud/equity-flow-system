-- 10.11A3: Acquisition Backend -- Deal Detail Read Path Corrections tests
BEGIN;

SELECT plan(10);

-- Seed tenant one: owner
SELECT public.create_active_workspace_seed_v1(
  'b1130000-0000-0000-0000-000000000001'::uuid,
  'a1130000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

-- Seed tenant two: cross-tenant isolation
SELECT public.create_active_workspace_seed_v1(
  'b1130000-0000-0000-0000-000000000002'::uuid,
  'a1130000-0000-0000-0000-000000000002'::uuid,
  'owner'
);

-- Seed deal one for tenant one (has call_log notes)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1130000-0000-0000-0000-000000000001',
  'b1130000-0000-0000-0000-000000000001',
  1, 1, 'new', '123 Test St', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e1130000-0000-0000-0000-000000000001',
  'b1130000-0000-0000-0000-000000000001',
  'd1130000-0000-0000-0000-000000000001',
  1,
  '{"arv":300000,"ask_price":175000,"repair_estimate":40000,"assignment_fee":10000,"mao":155000,"multiplier":0.70,"calc_version":"mao_v1"}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e1130000-0000-0000-0000-000000000001'
WHERE id = 'd1130000-0000-0000-0000-000000000001';

-- Seed deal two for tenant one (no call_log notes -- for last_contacted_at null test)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1130000-0000-0000-0000-000000000003',
  'b1130000-0000-0000-0000-000000000001',
  1, 1, 'new', '789 No Contact St', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e1130000-0000-0000-0000-000000000003',
  'b1130000-0000-0000-0000-000000000001',
  'd1130000-0000-0000-0000-000000000003',
  1,
  '{"arv":200000,"ask_price":150000,"repair_estimate":20000,"assignment_fee":5000,"mao":110000,"multiplier":0.70,"calc_version":"mao_v1"}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e1130000-0000-0000-0000-000000000003'
WHERE id = 'd1130000-0000-0000-0000-000000000003';

-- Seed deal for tenant two (cross-tenant isolation)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1130000-0000-0000-0000-000000000002',
  'b1130000-0000-0000-0000-000000000002',
  1, 1, 'new', '456 Other St', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e1130000-0000-0000-0000-000000000002',
  'b1130000-0000-0000-0000-000000000002',
  'd1130000-0000-0000-0000-000000000002',
  1,
  '{"arv":200000,"ask_price":150000,"repair_estimate":20000,"assignment_fee":5000,"mao":110000,"multiplier":0.70,"calc_version":"mao_v1"}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e1130000-0000-0000-0000-000000000002'
WHERE id = 'd1130000-0000-0000-0000-000000000002';

-- Seed two call_log notes for deal one -- newest must win
INSERT INTO public.deal_notes (id, tenant_id, deal_id, note_type, content, created_by, created_at, updated_at)
VALUES
  ('f1130000-0000-0000-0000-000000000001', 'b1130000-0000-0000-0000-000000000001', 'd1130000-0000-0000-0000-000000000001', 'call_log', 'Called seller',   'a1130000-0000-0000-0000-000000000001', '2026-01-01 10:00:00+00', '2026-01-01 10:00:00+00'),
  ('f1130000-0000-0000-0000-000000000002', 'b1130000-0000-0000-0000-000000000001', 'd1130000-0000-0000-0000-000000000001', 'call_log', 'Follow up call',  'a1130000-0000-0000-0000-000000000001', '2026-01-02 10:00:00+00', '2026-01-02 10:00:00+00');

-- Set context: owner of tenant one
SELECT set_config('request.jwt.claims',
  '{"sub":"a1130000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1130000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 1. get_acq_deal_v1 returns ok
SELECT is(
  (public.get_acq_deal_v1('d1130000-0000-0000-0000-000000000001')::json)->>'ok',
  'true',
  'get_acq_deal_v1: returns ok'
);

-- 2. returns mao
SELECT is(
  (public.get_acq_deal_v1('d1130000-0000-0000-0000-000000000001')::json)->'data'->'pricing'->>'mao',
  '155000',
  'get_acq_deal_v1: returns mao from assumptions'
);

-- 3. returns multiplier
SELECT is(
  (public.get_acq_deal_v1('d1130000-0000-0000-0000-000000000001')::json)->'data'->'pricing'->>'multiplier',
  '0.70',
  'get_acq_deal_v1: returns multiplier from assumptions'
);

-- 4. last_contacted_at returns newest call_log timestamp
SELECT is(
  (public.get_acq_deal_v1('d1130000-0000-0000-0000-000000000001')::json)->'data'->>'last_contacted_at',
  '2026-01-02T10:00:00+00:00',
  'get_acq_deal_v1: last_contacted_at returns newest call_log'
);

-- 5. last_contacted_at is null for same-tenant deal with no call_log
SELECT is(
  (public.get_acq_deal_v1('d1130000-0000-0000-0000-000000000003')::json)->'data'->>'last_contacted_at',
  null,
  'get_acq_deal_v1: last_contacted_at is null when no call_log exists'
);

-- 6. p_deal_id null returns VALIDATION_ERROR
SELECT is(
  (public.get_acq_deal_v1(null)::json)->>'code',
  'VALIDATION_ERROR',
  'get_acq_deal_v1: null p_deal_id returns VALIDATION_ERROR'
);

-- 7. cross-tenant returns NOT_FOUND
SELECT is(
  (public.get_acq_deal_v1('d1130000-0000-0000-0000-000000000002')::json)->>'code',
  'NOT_FOUND',
  'get_acq_deal_v1: cross-tenant deal returns NOT_FOUND'
);

-- 8. existing fields still returned (no regression)
SELECT is(
  (public.get_acq_deal_v1('d1130000-0000-0000-0000-000000000001')::json)->'data'->>'address',
  '123 Test St',
  'get_acq_deal_v1: existing address field still returned'
);

-- 9. existing pricing fields still returned (no regression)
SELECT is(
  (public.get_acq_deal_v1('d1130000-0000-0000-0000-000000000001')::json)->'data'->'pricing'->>'arv',
  '300000',
  'get_acq_deal_v1: existing arv field still returned'
);

-- 10. health_color still returned (no regression)
SELECT ok(
  (public.get_acq_deal_v1('d1130000-0000-0000-0000-000000000001')::json)->'data'->>'health_color' IS NOT NULL,
  'get_acq_deal_v1: health_color still returned'
);

SELECT finish();
ROLLBACK;