-- 10.11A5: Deal Properties Schema Normalization tests
BEGIN;

SELECT plan(12);

-- Seed tenant one: owner
SELECT public.create_active_workspace_seed_v1(
  'b1150000-0000-0000-0000-000000000001'::uuid,
  'a1150000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

-- Seed deal one: shorthand text values (new format)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1150000-0000-0000-0000-000000000001',
  'b1150000-0000-0000-0000-000000000001',
  1, 1, 'new', '123 Schema St', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e1150000-0000-0000-0000-000000000001',
  'b1150000-0000-0000-0000-000000000001',
  'd1150000-0000-0000-0000-000000000001',
  1,
  '{"arv":300000,"ask_price":200000}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e1150000-0000-0000-0000-000000000001'
WHERE id = 'd1150000-0000-0000-0000-000000000001';

-- Seed deal_properties with shorthand text values
INSERT INTO public.deal_properties (
  id, tenant_id, deal_id, row_version,
  beds, baths, sqft,
  property_type, condition_notes,
  created_at, updated_at
)
VALUES (
  'f1150000-0000-0000-0000-000000000001',
  'b1150000-0000-0000-0000-000000000001',
  'd1150000-0000-0000-0000-000000000001',
  1,
  '3+1', '2+1', '2400/1200',
  'Detached', 'Needs roof',
  now(), now()
);

-- Seed deal two: legacy scalar values (simulating pre-migration integer/numeric data cast to text)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1150000-0000-0000-0000-000000000002',
  'b1150000-0000-0000-0000-000000000001',
  1, 1, 'new', '456 Legacy St', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e1150000-0000-0000-0000-000000000002',
  'b1150000-0000-0000-0000-000000000001',
  'd1150000-0000-0000-0000-000000000002',
  1,
  '{"arv":250000,"ask_price":180000}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e1150000-0000-0000-0000-000000000002'
WHERE id = 'd1150000-0000-0000-0000-000000000002';

-- Seed deal_properties with legacy scalar values as text (simulating cast-preserved integers)
INSERT INTO public.deal_properties (
  id, tenant_id, deal_id, row_version,
  beds, baths, sqft,
  property_type, condition_notes,
  created_at, updated_at
)
VALUES (
  'f1150000-0000-0000-0000-000000000002',
  'b1150000-0000-0000-0000-000000000001',
  'd1150000-0000-0000-0000-000000000002',
  1,
  '3', '2.5', '2400',
  'Semi-detached', 'Good condition',
  now(), now()
);

-- 1. beds column is text type
SELECT is(
  (SELECT data_type FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'deal_properties' AND column_name = 'beds'),
  'text',
  'deal_properties.beds is text'
);

-- 2. baths column is text type
SELECT is(
  (SELECT data_type FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'deal_properties' AND column_name = 'baths'),
  'text',
  'deal_properties.baths is text'
);

-- 3. sqft column is text type
SELECT is(
  (SELECT data_type FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'deal_properties' AND column_name = 'sqft'),
  'text',
  'deal_properties.sqft is text'
);

-- 4. shorthand beds value stored correctly
SELECT is(
  (SELECT beds FROM public.deal_properties WHERE deal_id = 'd1150000-0000-0000-0000-000000000001'),
  '3+1',
  'deal_properties.beds stores shorthand value correctly'
);

-- 5. shorthand baths value stored correctly
SELECT is(
  (SELECT baths FROM public.deal_properties WHERE deal_id = 'd1150000-0000-0000-0000-000000000001'),
  '2+1',
  'deal_properties.baths stores shorthand value correctly'
);

-- 6. shorthand sqft value stored correctly
SELECT is(
  (SELECT sqft FROM public.deal_properties WHERE deal_id = 'd1150000-0000-0000-0000-000000000001'),
  '2400/1200',
  'deal_properties.sqft stores shorthand value correctly'
);

-- 7. legacy scalar beds preserved as text after cast
SELECT is(
  (SELECT beds FROM public.deal_properties WHERE deal_id = 'd1150000-0000-0000-0000-000000000002'),
  '3',
  'deal_properties.beds: legacy scalar value preserved as text'
);

-- 8. legacy scalar baths preserved as text after cast
SELECT is(
  (SELECT baths FROM public.deal_properties WHERE deal_id = 'd1150000-0000-0000-0000-000000000002'),
  '2.5',
  'deal_properties.baths: legacy scalar value preserved as text'
);

-- 9. legacy scalar sqft preserved as text after cast
SELECT is(
  (SELECT sqft FROM public.deal_properties WHERE deal_id = 'd1150000-0000-0000-0000-000000000002'),
  '2400',
  'deal_properties.sqft: legacy scalar value preserved as text'
);

-- Set context for RPC regression tests
SELECT set_config('request.jwt.claims',
  '{"sub":"a1150000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1150000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 10. get_acq_deal_v1 still returns properties.beds
SELECT is(
  (public.get_acq_deal_v1('d1150000-0000-0000-0000-000000000001')::json)->'data'->'properties'->>'beds',
  '3+1',
  'get_acq_deal_v1: properties.beds still returned after schema change'
);

-- 11. get_acq_deal_v1 still returns properties.baths
SELECT is(
  (public.get_acq_deal_v1('d1150000-0000-0000-0000-000000000001')::json)->'data'->'properties'->>'baths',
  '2+1',
  'get_acq_deal_v1: properties.baths still returned after schema change'
);

-- 12. get_acq_deal_v1 still returns properties.sqft
SELECT is(
  (public.get_acq_deal_v1('d1150000-0000-0000-0000-000000000001')::json)->'data'->'properties'->>'sqft',
  '2400/1200',
  'get_acq_deal_v1: properties.sqft still returned after schema change'
);

SELECT finish();
ROLLBACK;