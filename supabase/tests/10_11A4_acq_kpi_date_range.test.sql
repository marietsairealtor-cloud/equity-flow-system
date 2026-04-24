-- 10.11A4: ACQ KPI Date Range Filter tests
BEGIN;

SELECT plan(12);

-- Seed tenant one: owner
SELECT public.create_active_workspace_seed_v1(
  'b1140000-0000-0000-0000-000000000001'::uuid,
  'a1140000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

-- Seed tenant two: cross-tenant isolation
SELECT public.create_active_workspace_seed_v1(
  'b1140000-0000-0000-0000-000000000002'::uuid,
  'a1140000-0000-0000-0000-000000000002'::uuid,
  'owner'
);

-- Deal 1: under_contract, created 40 days ago (outside last 30 days)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES ('d1140000-0000-0000-0000-000000000001', 'b1140000-0000-0000-0000-000000000001', 1, 1, 'under_contract', '111 Old St', now(), now() - interval '40 days');

-- Deal 1: two deal_inputs rows -- older row has assignment_fee=10000, newer row has 15000
-- avg should use 15000 (newest) not average both
INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES
  ('e1140000-0000-0000-0000-000000000001', 'b1140000-0000-0000-0000-000000000001', 'd1140000-0000-0000-0000-000000000001', 1,
    '{"arv":300000,"ask_price":200000,"assignment_fee":10000}'::jsonb, now() - interval '41 days'),
  ('e1140000-0000-0000-0000-00000000001b', 'b1140000-0000-0000-0000-000000000001', 'd1140000-0000-0000-0000-000000000001', 1,
    '{"arv":300000,"ask_price":200000,"assignment_fee":15000}'::jsonb, now() - interval '40 days');

UPDATE public.deals SET assumptions_snapshot_id = 'e1140000-0000-0000-0000-000000000001'
WHERE id = 'd1140000-0000-0000-0000-000000000001';

-- Deal 2: under_contract, created 5 days ago (inside last 7 days)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES ('d1140000-0000-0000-0000-000000000002', 'b1140000-0000-0000-0000-000000000001', 1, 1, 'under_contract', '222 New St', now(), now() - interval '5 days');

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES ('e1140000-0000-0000-0000-000000000002', 'b1140000-0000-0000-0000-000000000001', 'd1140000-0000-0000-0000-000000000002', 1,
  '{"arv":400000,"ask_price":300000,"assignment_fee":20000}'::jsonb, now() - interval '5 days');

UPDATE public.deals SET assumptions_snapshot_id = 'e1140000-0000-0000-0000-000000000002'
WHERE id = 'd1140000-0000-0000-0000-000000000002';

-- Deal 3: new stage, created 3 days ago (not counted in contracts_signed)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES ('d1140000-0000-0000-0000-000000000003', 'b1140000-0000-0000-0000-000000000001', 1, 1, 'new', '333 Lead St', now(), now() - interval '3 days');

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES ('e1140000-0000-0000-0000-000000000003', 'b1140000-0000-0000-0000-000000000001', 'd1140000-0000-0000-0000-000000000003', 1,
  '{"arv":250000,"ask_price":180000}'::jsonb, now() - interval '3 days');

UPDATE public.deals SET assumptions_snapshot_id = 'e1140000-0000-0000-0000-000000000003'
WHERE id = 'd1140000-0000-0000-0000-000000000003';

-- Seed deal for tenant two (must not appear in tenant one KPIs)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES ('d1140000-0000-0000-0000-000000000004', 'b1140000-0000-0000-0000-000000000002', 1, 1, 'under_contract', '444 Other St', now(), now());

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES ('e1140000-0000-0000-0000-000000000004', 'b1140000-0000-0000-0000-000000000002', 'd1140000-0000-0000-0000-000000000004', 1,
  '{"arv":500000,"ask_price":400000,"assignment_fee":30000}'::jsonb, now());

UPDATE public.deals SET assumptions_snapshot_id = 'e1140000-0000-0000-0000-000000000004'
WHERE id = 'd1140000-0000-0000-0000-000000000004';

-- Set context: owner of tenant one
SELECT set_config('request.jwt.claims',
  '{"sub":"a1140000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1140000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 1. all-time behavior preserved -- 2 contracts signed
SELECT is(
  (public.get_acq_kpis_v1()::json)->'data'->>'contracts_signed',
  '2',
  'get_acq_kpis_v1: all-time returns both contracts signed'
);

-- 2. last 7 days -- only deal 2 qualifies (deal 1 is 40 days old)
SELECT is(
  (public.get_acq_kpis_v1(now() - interval '7 days', now())::json)->'data'->>'contracts_signed',
  '1',
  'get_acq_kpis_v1: last 7 days returns only recent contract'
);

-- 3. last 30 days -- only deal 2 qualifies (deal 1 is 40 days old)
SELECT is(
  (public.get_acq_kpis_v1(now() - interval '30 days', now())::json)->'data'->>'contracts_signed',
  '1',
  'get_acq_kpis_v1: last 30 days excludes deal older than 30 days'
);

-- 4. one-sided lower bound from 35 days ago -- only deal 2 qualifies (deal 1 is 40 days old)
SELECT is(
  (public.get_acq_kpis_v1(now() - interval '35 days', null)::json)->'data'->>'contracts_signed',
  '1',
  'get_acq_kpis_v1: one-sided lower bound from 35 days ago returns only deal 2'
);

-- 5. one-sided upper bound up to 10 days ago -- only deal 1 qualifies
SELECT is(
  (public.get_acq_kpis_v1(null, now() - interval '10 days')::json)->'data'->>'contracts_signed',
  '1',
  'get_acq_kpis_v1: one-sided upper bound returns only older contract'
);

-- 6. invalid range returns VALIDATION_ERROR
SELECT is(
  (public.get_acq_kpis_v1(now(), now() - interval '1 day')::json)->>'code',
  'VALIDATION_ERROR',
  'get_acq_kpis_v1: p_date_to before p_date_from returns VALIDATION_ERROR'
);

-- 7. lead_to_contract_pct all-time -- 2 contracts / 3 leads = 66.7%
SELECT is(
  (public.get_acq_kpis_v1()::json)->'data'->>'lead_to_contract_pct',
  '66.7',
  'get_acq_kpis_v1: all-time lead_to_contract_pct correct'
);

-- 8. lead_to_contract_pct last 7 days -- 1 contract / 2 leads = 50.0%
SELECT is(
  (public.get_acq_kpis_v1(now() - interval '7 days', now())::json)->'data'->>'lead_to_contract_pct',
  '50.0',
  'get_acq_kpis_v1: last 7 days lead_to_contract_pct correct'
);

-- 9. avg_assignment_fee all-time uses latest deal_inputs per deal
-- deal 1 newest row = 15000, deal 2 = 20000, avg = 17500
SELECT is(
  (public.get_acq_kpis_v1()::json)->'data'->>'avg_assignment_fee',
  '17500.00',
  'get_acq_kpis_v1: avg_assignment_fee uses latest deal_inputs row per deal'
);

-- 10. avg_assignment_fee last 7 days -- only deal 2 = 20000
SELECT is(
  (public.get_acq_kpis_v1(now() - interval '7 days', now())::json)->'data'->>'avg_assignment_fee',
  '20000.00',
  'get_acq_kpis_v1: avg_assignment_fee filtered by date range'
);

-- 11. cross-tenant isolation -- tenant two deal not counted
SELECT is(
  (public.get_acq_kpis_v1()::json)->'data'->>'contracts_signed',
  '2',
  'get_acq_kpis_v1: cross-tenant deals not included in KPIs'
);

-- 12. multi-row deal_inputs: older row (10000) must not pollute avg
-- all-time avg = 17500 not 15000 (which would be if old row was averaged in)
SELECT isnt(
  (public.get_acq_kpis_v1()::json)->'data'->>'avg_assignment_fee',
  '15000.00',
  'get_acq_kpis_v1: older deal_inputs row does not pollute avg_assignment_fee'
);

SELECT finish();
ROLLBACK;