-- 10.14B4B: ACQ Backend Cleanup -- Remove Orphaned next_action Fields tests
BEGIN;

SELECT plan(16);

-- Seed tenant + owner
SELECT public.create_active_workspace_seed_v1(
  'b1144000-0000-0000-0000-000000000001'::uuid,
  'a1144000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

-- Seed deal
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1144000-0000-0000-0000-000000000001',
  'b1144000-0000-0000-0000-000000000001',
  1, 1, 'new', '123 Cleanup St', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e1144000-0000-0000-0000-000000000001',
  'b1144000-0000-0000-0000-000000000001',
  'd1144000-0000-0000-0000-000000000001',
  1,
  '{"arv":300000,"ask_price":200000}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e1144000-0000-0000-0000-000000000001'
WHERE id = 'd1144000-0000-0000-0000-000000000001';

INSERT INTO public.deal_properties (
  id, tenant_id, deal_id, row_version,
  property_type, created_at, updated_at
)
VALUES (
  'f1144000-0000-0000-0000-000000000001',
  'b1144000-0000-0000-0000-000000000001',
  'd1144000-0000-0000-0000-000000000001',
  1, 'Detached', now(), now()
);

-- Seed cross-tenant
SELECT public.create_active_workspace_seed_v1(
  'b1144000-0000-0000-0000-000000000002'::uuid,
  'a1144000-0000-0000-0000-000000000002'::uuid,
  'owner'
);

-- Set context: tenant one owner
SELECT set_config('request.jwt.claims',
  '{"sub":"a1144000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1144000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 1. update_deal_property_v1 rejects next_action
SELECT is(
  (public.update_deal_property_v1(
    'd1144000-0000-0000-0000-000000000001',
    '{"next_action":"call seller"}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_property_v1: next_action rejected'
);

-- 2. update_deal_property_v1 rejects next_action_due
SELECT is(
  (public.update_deal_property_v1(
    'd1144000-0000-0000-0000-000000000001',
    '{"next_action_due":"2026-06-01T00:00:00Z"}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_property_v1: next_action_due rejected'
);

-- 3. update_deal_property_v1 still accepts address
SELECT is(
  (public.update_deal_property_v1(
    'd1144000-0000-0000-0000-000000000001',
    '{"address":"456 Oak Ave"}'::jsonb
  )::json)->>'code',
  'OK',
  'update_deal_property_v1: address still accepted'
);

-- 4. get_acq_deal_v1: next_action key absent from data
SELECT ok(
  NOT ((public.get_acq_deal_v1('d1144000-0000-0000-0000-000000000001')::jsonb)->'data' ? 'next_action'),
  'get_acq_deal_v1: next_action key absent from data'
);

-- 5. get_acq_deal_v1: next_action_due key absent from data
SELECT ok(
  NOT ((public.get_acq_deal_v1('d1144000-0000-0000-0000-000000000001')::jsonb)->'data' ? 'next_action_due'),
  'get_acq_deal_v1: next_action_due key absent from data'
);

-- 6. get_acq_deal_v1 still returns address (regression)
SELECT is(
  (public.get_acq_deal_v1('d1144000-0000-0000-0000-000000000001')::json)->'data'->>'address',
  '456 Oak Ave',
  'get_acq_deal_v1: address still returned'
);

-- 7. get_acq_deal_v1 still returns stage (regression)
SELECT is(
  (public.get_acq_deal_v1('d1144000-0000-0000-0000-000000000001')::json)->'data'->>'stage',
  'new',
  'get_acq_deal_v1: stage still returned'
);

-- 8. list_acq_deals_v1: next_action key absent from items
SELECT ok(
  NOT (((public.list_acq_deals_v1()::jsonb)->'data'->'items'->0) ? 'next_action'),
  'list_acq_deals_v1: next_action key absent from items'
);

-- 9. list_acq_deals_v1: next_action_due key absent from items
SELECT ok(
  NOT (((public.list_acq_deals_v1()::jsonb)->'data'->'items'->0) ? 'next_action_due'),
  'list_acq_deals_v1: next_action_due key absent from items'
);

-- 10. list_acq_deals_v1 still returns address in items (regression)
SELECT is(
  (public.list_acq_deals_v1()::json)->'data'->'items'->0->>'address',
  '456 Oak Ave',
  'list_acq_deals_v1: address still returned in items'
);

-- 11. list_acq_deals_v1 still returns health_color in items (regression)
SELECT isnt(
  (public.list_acq_deals_v1()::json)->'data'->'items'->0->>'health_color',
  null,
  'list_acq_deals_v1: health_color still returned in items'
);

-- 12. list_acq_deals_v1 filter still works (regression)
SELECT is(
  (public.list_acq_deals_v1('new')::json)->>'code',
  'OK',
  'list_acq_deals_v1: filter=new still works'
);

-- 13. next_action column still exists on deals table (deprecated not dropped)
SELECT is(
  (SELECT pg_catalog.format_type(a.atttypid, a.atttypmod)
   FROM pg_attribute a
   JOIN pg_class c ON c.oid = a.attrelid
   JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'deals' AND a.attname = 'next_action' AND NOT a.attisdropped),
  'text',
  'deals.next_action column still exists (deprecated not dropped)'
);

-- 14. next_action_due column still exists on deals table (deprecated not dropped)
SELECT is(
  (SELECT pg_catalog.format_type(a.atttypid, a.atttypmod)
   FROM pg_attribute a
   JOIN pg_class c ON c.oid = a.attrelid
   JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'deals' AND a.attname = 'next_action_due' AND NOT a.attisdropped),
  'timestamp with time zone',
  'deals.next_action_due column still exists (deprecated not dropped)'
);

-- Switch to non-member context
SELECT set_config('request.jwt.claims',
  '{"sub":"a1144000-0000-0000-0000-000000000099","role":"authenticated","tenant_id":"b1144000-0000-0000-0000-000000000001"}',
  true);

-- 15. non-member returns NOT_AUTHORIZED on update_deal_property_v1
SELECT is(
  (public.update_deal_property_v1(
    'd1144000-0000-0000-0000-000000000001',
    '{"address":"hacked"}'::jsonb
  )::json)->>'code',
  'NOT_AUTHORIZED',
  'update_deal_property_v1: non-member returns NOT_AUTHORIZED'
);

-- 16. non-member returns NOT_AUTHORIZED on list_acq_deals_v1
SELECT is(
  (public.list_acq_deals_v1()::json)->>'code',
  'NOT_AUTHORIZED',
  'list_acq_deals_v1: non-member returns NOT_AUTHORIZED'
);

SELECT finish();
ROLLBACK;
