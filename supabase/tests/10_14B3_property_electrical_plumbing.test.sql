-- 10.14B3: Property Field Expansion -- Electrical + Plumbing Backend tests
BEGIN;

SELECT plan(12);

-- Seed tenant + owner
SELECT public.create_active_workspace_seed_v1(
  'b1143000-0000-0000-0000-000000000001'::uuid,
  'a1143000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

-- Seed deal
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1143000-0000-0000-0000-000000000001',
  'b1143000-0000-0000-0000-000000000001',
  1, 1, 'new', '123 Electrical Ave', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e1143000-0000-0000-0000-000000000001',
  'b1143000-0000-0000-0000-000000000001',
  'd1143000-0000-0000-0000-000000000001',
  1,
  '{"arv":300000,"ask_price":200000}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e1143000-0000-0000-0000-000000000001'
WHERE id = 'd1143000-0000-0000-0000-000000000001';

INSERT INTO public.deal_properties (
  id, tenant_id, deal_id, row_version,
  property_type, condition_notes,
  created_at, updated_at
)
VALUES (
  'f1143000-0000-0000-0000-000000000001',
  'b1143000-0000-0000-0000-000000000001',
  'd1143000-0000-0000-0000-000000000001',
  1,
  'Detached', 'Solid structure',
  now(), now()
);

-- Seed cross-tenant (tenant two + owner)
SELECT public.create_active_workspace_seed_v1(
  'b1143000-0000-0000-0000-000000000002'::uuid,
  'a1143000-0000-0000-0000-000000000002'::uuid,
  'owner'
);

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1143000-0000-0000-0000-000000000002',
  'b1143000-0000-0000-0000-000000000002',
  1, 1, 'new', '456 Other St', now(), now()
);

INSERT INTO public.deal_properties (
  id, tenant_id, deal_id, row_version,
  property_type, created_at, updated_at
)
VALUES (
  'f1143000-0000-0000-0000-000000000002',
  'b1143000-0000-0000-0000-000000000002',
  'd1143000-0000-0000-0000-000000000002',
  1, 'Semi-detached', now(), now()
);

-- Set context: tenant one owner
SELECT set_config('request.jwt.claims',
  '{"sub":"a1143000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1143000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 1. update_deal_properties_v1 persists electrical
SELECT is(
  (public.update_deal_properties_v1(
    'd1143000-0000-0000-0000-000000000001',
    '{"electrical":"100A panel"}'::jsonb
  )::json)->>'code',
  'OK',
  'update_deal_properties_v1: persists electrical'
);

-- 2. update_deal_properties_v1 persists plumbing
SELECT is(
  (public.update_deal_properties_v1(
    'd1143000-0000-0000-0000-000000000001',
    '{"plumbing":"copper"}'::jsonb
  )::json)->>'code',
  'OK',
  'update_deal_properties_v1: persists plumbing'
);

-- 3. get_acq_deal_v1 returns saved electrical
SELECT is(
  (public.get_acq_deal_v1('d1143000-0000-0000-0000-000000000001')::json)->'data'->'properties'->>'electrical',
  '100A panel',
  'get_acq_deal_v1: returns saved electrical'
);

-- 4. get_acq_deal_v1 returns saved plumbing
SELECT is(
  (public.get_acq_deal_v1('d1143000-0000-0000-0000-000000000001')::json)->'data'->'properties'->>'plumbing',
  'copper',
  'get_acq_deal_v1: returns saved plumbing'
);

-- 5. unknown field still rejected by update_deal_properties_v1
SELECT is(
  (public.update_deal_properties_v1(
    'd1143000-0000-0000-0000-000000000001',
    '{"unknown_field":"bad"}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: unknown field still rejected'
);

-- 6. cross-tenant update returns NOT_FOUND
SELECT is(
  (public.update_deal_properties_v1(
    'd1143000-0000-0000-0000-000000000002',
    '{"electrical":"knob-and-tube"}'::jsonb
  )::json)->>'code',
  'NOT_FOUND',
  'update_deal_properties_v1: cross-tenant deal returns NOT_FOUND'
);

-- 7. cross-tenant read returns NOT_FOUND
SELECT is(
  (public.get_acq_deal_v1('d1143000-0000-0000-0000-000000000002')::json)->>'code',
  'NOT_FOUND',
  'get_acq_deal_v1: cross-tenant deal returns NOT_FOUND'
);

-- 8. electrical column exists and is text
SELECT is(
  (SELECT pg_catalog.format_type(a.atttypid, a.atttypmod)
   FROM pg_attribute a
   JOIN pg_class c ON c.oid = a.attrelid
   JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'deal_properties' AND a.attname = 'electrical' AND NOT a.attisdropped),
  'text',
  'deal_properties.electrical is text'
);

-- 9. plumbing column exists and is text
SELECT is(
  (SELECT pg_catalog.format_type(a.atttypid, a.atttypmod)
   FROM pg_attribute a
   JOIN pg_class c ON c.oid = a.attrelid
   JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'deal_properties' AND a.attname = 'plumbing' AND NOT a.attisdropped),
  'text',
  'deal_properties.plumbing is text'
);

-- 10. existing fields still returned by get_acq_deal_v1 (regression: property_type)
SELECT is(
  (public.get_acq_deal_v1('d1143000-0000-0000-0000-000000000001')::json)->'data'->'properties'->>'property_type',
  'Detached',
  'get_acq_deal_v1: existing property_type still returned (regression check)'
);

-- Switch to non-member context (no membership seeded for this user)
SELECT set_config('request.jwt.claims',
  '{"sub":"a1143000-0000-0000-0000-000000000099","role":"authenticated","tenant_id":"b1143000-0000-0000-0000-000000000001"}',
  true);

-- 11. non-member update returns NOT_AUTHORIZED
SELECT is(
  (public.update_deal_properties_v1(
    'd1143000-0000-0000-0000-000000000001',
    '{"electrical":"knob-and-tube"}'::jsonb
  )::json)->>'code',
  'NOT_AUTHORIZED',
  'update_deal_properties_v1: non-member returns NOT_AUTHORIZED'
);

-- 12. non-member read returns NOT_AUTHORIZED
SELECT is(
  (public.get_acq_deal_v1('d1143000-0000-0000-0000-000000000001')::json)->>'code',
  'NOT_AUTHORIZED',
  'get_acq_deal_v1: non-member returns NOT_AUTHORIZED'
);

SELECT finish();
ROLLBACK;