-- 10.11A6: Deal Properties Write Path tests
BEGIN;

SELECT plan(24);

-- Seed tenant one: owner
SELECT public.create_active_workspace_seed_v1(
  'b1160000-0000-0000-0000-000000000001'::uuid,
  'a1160000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

-- Seed tenant two: cross-tenant isolation
SELECT public.create_active_workspace_seed_v1(
  'b1160000-0000-0000-0000-000000000002'::uuid,
  'a1160000-0000-0000-0000-000000000002'::uuid,
  'owner'
);

-- Seed deal for tenant one
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1160000-0000-0000-0000-000000000001',
  'b1160000-0000-0000-0000-000000000001',
  1, 1, 'new', '123 Props St', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e1160000-0000-0000-0000-000000000001',
  'b1160000-0000-0000-0000-000000000001',
  'd1160000-0000-0000-0000-000000000001',
  1,
  '{"arv":300000,"ask_price":200000}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e1160000-0000-0000-0000-000000000001'
WHERE id = 'd1160000-0000-0000-0000-000000000001';

-- Seed deal_properties for tenant one with known initial values
INSERT INTO public.deal_properties (
  id, tenant_id, deal_id, row_version,
  property_type, beds, baths, sqft, condition_notes,
  deficiency_tags, repair_estimate,
  created_at, updated_at
)
VALUES (
  'f1160000-0000-0000-0000-000000000001',
  'b1160000-0000-0000-0000-000000000001',
  'd1160000-0000-0000-0000-000000000001',
  1,
  'Detached', '3+1', '2+1', '2400/1200', 'Needs roof',
  ARRAY['needs-roof','old-furnace'], 45000,
  now(), now()
);

-- Seed deal for tenant two (cross-tenant, no deal_properties row)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1160000-0000-0000-0000-000000000002',
  'b1160000-0000-0000-0000-000000000002',
  1, 1, 'new', '456 Other St', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e1160000-0000-0000-0000-000000000002',
  'b1160000-0000-0000-0000-000000000002',
  'd1160000-0000-0000-0000-000000000002',
  1,
  '{"arv":200000,"ask_price":150000}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e1160000-0000-0000-0000-000000000002'
WHERE id = 'd1160000-0000-0000-0000-000000000002';

-- Set context: owner of tenant one
SELECT set_config('request.jwt.claims',
  '{"sub":"a1160000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1160000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 1. success: update a property field (row_version: 1 -> 2)
SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '{"condition_notes":"Needs roof and furnace"}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_properties_v1: success on valid field update'
);

-- 2. row_version incremented
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT row_version FROM public.deal_properties WHERE deal_id = 'd1160000-0000-0000-0000-000000000001'),
  2::bigint,
  'update_deal_properties_v1: row_version incremented after update'
);

-- 3. field value persisted correctly
SELECT is(
  (SELECT condition_notes FROM public.deal_properties WHERE deal_id = 'd1160000-0000-0000-0000-000000000001'),
  'Needs roof and furnace',
  'update_deal_properties_v1: condition_notes persisted correctly'
);

-- 4. omitted field left unchanged
SELECT is(
  (SELECT property_type FROM public.deal_properties WHERE deal_id = 'd1160000-0000-0000-0000-000000000001'),
  'Detached',
  'update_deal_properties_v1: omitted field left unchanged'
);
SET LOCAL ROLE authenticated;

-- 5. explicit null clears field (row_version: 2 -> 3)
SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '{"condition_notes":null}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_properties_v1: explicit null accepted'
);

SET LOCAL ROLE postgres;
-- 6. explicit null clears field in DB
SELECT is(
  (SELECT condition_notes FROM public.deal_properties WHERE deal_id = 'd1160000-0000-0000-0000-000000000001'),
  null,
  'update_deal_properties_v1: explicit null clears field'
);
SET LOCAL ROLE authenticated;

-- 7. same-value submission returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '{"property_type":"Detached"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: same-value submission returns VALIDATION_ERROR'
);

-- 8. empty payload returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '{}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: empty payload returns VALIDATION_ERROR'
);

-- 9. non-object payload returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '"lol"'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: non-object payload returns VALIDATION_ERROR'
);

-- 10. unknown key returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '{"seller_name":"hacker"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: unknown key returns VALIDATION_ERROR'
);

-- 11. deficiency_tags null clears field (row_version: 3 -> 4)
SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '{"deficiency_tags":null}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_properties_v1: deficiency_tags null accepted'
);

-- 12. deficiency_tags null clears field in DB
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT deficiency_tags FROM public.deal_properties WHERE deal_id = 'd1160000-0000-0000-0000-000000000001'),
  null,
  'update_deal_properties_v1: deficiency_tags null clears field in DB'
);
SET LOCAL ROLE authenticated;

-- 13. deficiency_tags valid array accepted (row_version: 4 -> 5)
SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '{"deficiency_tags":["needs-roof","old-windows"]}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_properties_v1: deficiency_tags valid array accepted'
);

-- 14. deficiency_tags array persisted correctly in DB
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT deficiency_tags FROM public.deal_properties WHERE deal_id = 'd1160000-0000-0000-0000-000000000001'),
  ARRAY['needs-roof','old-windows'],
  'update_deal_properties_v1: deficiency_tags array persisted correctly'
);
SET LOCAL ROLE authenticated;

-- 15. deficiency_tags invalid shape returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '{"deficiency_tags":"not-an-array"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: deficiency_tags non-array returns VALIDATION_ERROR'
);

-- 16. deficiency_tags array with non-string elements returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '{"deficiency_tags":[1,2,3]}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: deficiency_tags array with numbers returns VALIDATION_ERROR'
);

-- 17. invalid year_built returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '{"year_built":"banana"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: invalid year_built returns VALIDATION_ERROR'
);

-- 18. invalid repair_estimate returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '{"repair_estimate":"nope"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: invalid repair_estimate returns VALIDATION_ERROR'
);

-- 19. invalid roof_age returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '{"roof_age":"old"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_properties_v1: invalid roof_age returns VALIDATION_ERROR'
);

-- 20. cross-tenant deal returns NOT_FOUND
SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000002',
    '{"property_type":"Semi"}'::jsonb)::json)->>'code',
  'NOT_FOUND',
  'update_deal_properties_v1: cross-tenant deal returns NOT_FOUND'
);

-- 21. missing deal_properties row returns NOT_FOUND
SELECT set_config('request.jwt.claims',
  '{"sub":"a1160000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"b1160000-0000-0000-0000-000000000002"}',
  true);

SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000002',
    '{"property_type":"Semi"}'::jsonb)::json)->>'code',
  'NOT_FOUND',
  'update_deal_properties_v1: missing deal_properties row returns NOT_FOUND'
);

-- 22. write lock rejection
SET LOCAL ROLE postgres;
UPDATE public.tenant_subscriptions
SET status = 'canceled', current_period_end = now() - interval '70 days'
WHERE tenant_id = 'b1160000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;

SELECT set_config('request.jwt.claims',
  '{"sub":"a1160000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1160000-0000-0000-0000-000000000001"}',
  true);

SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '{"property_type":"Blocked"}'::jsonb)::json)->>'code',
  'WORKSPACE_NOT_WRITABLE',
  'update_deal_properties_v1: expired workspace returns WORKSPACE_NOT_WRITABLE'
);

-- 23. row_version not incremented on write lock rejection (stays 5)
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT row_version FROM public.deal_properties WHERE deal_id = 'd1160000-0000-0000-0000-000000000001'),
  5::bigint,
  'update_deal_properties_v1: row_version not incremented on write lock rejection'
);

-- 24. shorthand text values accepted for beds/baths/sqft (row_version would be 6 if sub active)
-- just verify the validation path accepts text format -- restore sub first
UPDATE public.tenant_subscriptions
SET status = 'active', current_period_end = now() + interval '30 days'
WHERE tenant_id = 'b1160000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;

SELECT is(
  (public.update_deal_properties_v1('d1160000-0000-0000-0000-000000000001',
    '{"beds":"4+1","baths":"3+1","sqft":"3000/1500"}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_properties_v1: shorthand text values accepted for beds baths sqft'
);

SELECT finish();
ROLLBACK;