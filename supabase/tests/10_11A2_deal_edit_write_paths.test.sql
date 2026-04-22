-- 10.11A2: Seller / Property Edit Write Paths tests
BEGIN;

SELECT plan(27);

-- Seed tenant one: owner
SELECT public.create_active_workspace_seed_v1(
  'b1120000-0000-0000-0000-000000000001'::uuid,
  'a1120000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

-- Seed tenant two: cross-tenant isolation
SELECT public.create_active_workspace_seed_v1(
  'b1120000-0000-0000-0000-000000000002'::uuid,
  'a1120000-0000-0000-0000-000000000002'::uuid,
  'owner'
);

-- Seed deal for tenant one with known initial values
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage,
  seller_name, seller_phone, seller_email, seller_pain, seller_timeline, seller_notes,
  address, next_action, next_action_due, updated_at, created_at)
VALUES (
  'd1120000-0000-0000-0000-000000000001',
  'b1120000-0000-0000-0000-000000000001',
  1, 1, 'new',
  'Jane Doe', '555-1234', 'jane@example.com', 'Inherited property', 'Close in 30d', 'Initial note',
  '123 Main St', 'Follow up', '2026-06-01 12:00:00+00',
  now(), now()
);

-- Seed deal for tenant two
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, updated_at, created_at)
VALUES (
  'd1120000-0000-0000-0000-000000000002',
  'b1120000-0000-0000-0000-000000000002',
  1, 1, 'new', now(), now()
);

-- Set context: owner of tenant one
SELECT set_config('request.jwt.claims',
  '{"sub":"a1120000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1120000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- ============================================================
-- update_deal_seller_v1 tests
-- ============================================================

-- 1. success: update a seller field (row_version: 1 -> 2)
SELECT is(
  (public.update_deal_seller_v1('d1120000-0000-0000-0000-000000000001',
    '{"seller_name":"John Smith"}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_seller_v1: success on valid field update'
);

-- 2. row_version incremented after update
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT row_version FROM public.deals WHERE id = 'd1120000-0000-0000-0000-000000000001'),
  2::bigint,
  'update_deal_seller_v1: row_version incremented after update'
);

-- 3. field value persisted correctly
SELECT is(
  (SELECT seller_name FROM public.deals WHERE id = 'd1120000-0000-0000-0000-000000000001'),
  'John Smith',
  'update_deal_seller_v1: seller_name persisted correctly'
);

-- 4. omitted field left unchanged
SELECT is(
  (SELECT seller_phone FROM public.deals WHERE id = 'd1120000-0000-0000-0000-000000000001'),
  '555-1234',
  'update_deal_seller_v1: omitted field left unchanged'
);
SET LOCAL ROLE authenticated;

-- 5. explicit null clears a field (row_version: 2 -> 3)
SELECT is(
  (public.update_deal_seller_v1('d1120000-0000-0000-0000-000000000001',
    '{"seller_notes":null}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_seller_v1: explicit null accepted'
);

-- 6. explicit null clears field value in DB
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT seller_notes FROM public.deals WHERE id = 'd1120000-0000-0000-0000-000000000001'),
  null,
  'update_deal_seller_v1: explicit null clears field'
);
SET LOCAL ROLE authenticated;

-- 7. same-value submission returns VALIDATION_ERROR (row_version stays 3)
SELECT is(
  (public.update_deal_seller_v1('d1120000-0000-0000-0000-000000000001',
    '{"seller_phone":"555-1234"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_seller_v1: same-value submission returns VALIDATION_ERROR'
);

-- 8. empty payload returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_seller_v1('d1120000-0000-0000-0000-000000000001',
    '{}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_seller_v1: empty payload returns VALIDATION_ERROR'
);

-- 9. non-object payload returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_seller_v1('d1120000-0000-0000-0000-000000000001',
    '[]'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_seller_v1: non-object payload returns VALIDATION_ERROR'
);

-- 10. unknown key returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_seller_v1('d1120000-0000-0000-0000-000000000001',
    '{"dead_reason":"nope"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_seller_v1: unknown key returns VALIDATION_ERROR'
);

-- 11. cross-tenant deal returns NOT_FOUND
SELECT is(
  (public.update_deal_seller_v1('d1120000-0000-0000-0000-000000000002',
    '{"seller_name":"Hacker"}'::jsonb)::json)->>'code',
  'NOT_FOUND',
  'update_deal_seller_v1: cross-tenant deal returns NOT_FOUND'
);

-- 12. write lock rejection: expire subscription
SET LOCAL ROLE postgres;
UPDATE public.tenant_subscriptions
SET status = 'canceled', current_period_end = now() - interval '70 days'
WHERE tenant_id = 'b1120000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;

SELECT is(
  (public.update_deal_seller_v1('d1120000-0000-0000-0000-000000000001',
    '{"seller_name":"Blocked"}'::jsonb)::json)->>'code',
  'WORKSPACE_NOT_WRITABLE',
  'update_deal_seller_v1: expired workspace returns WORKSPACE_NOT_WRITABLE'
);

-- Restore active subscription
SET LOCAL ROLE postgres;
UPDATE public.tenant_subscriptions
SET status = 'active', current_period_end = now() + interval '30 days'
WHERE tenant_id = 'b1120000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;

-- ============================================================
-- update_deal_property_v1 tests
-- ============================================================

-- 13. success: update address (row_version: 3 -> 4)
SELECT is(
  (public.update_deal_property_v1('d1120000-0000-0000-0000-000000000001',
    '{"address":"456 Oak Ave"}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_property_v1: success on valid field update'
);

-- 14. row_version incremented after property update
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT row_version FROM public.deals WHERE id = 'd1120000-0000-0000-0000-000000000001'),
  4::bigint,
  'update_deal_property_v1: row_version incremented after update'
);

-- 15. address persisted correctly
SELECT is(
  (SELECT address FROM public.deals WHERE id = 'd1120000-0000-0000-0000-000000000001'),
  '456 Oak Ave',
  'update_deal_property_v1: address persisted correctly'
);

-- 16. omitted field left unchanged
SELECT is(
  (SELECT next_action FROM public.deals WHERE id = 'd1120000-0000-0000-0000-000000000001'),
  'Follow up',
  'update_deal_property_v1: omitted field left unchanged'
);
SET LOCAL ROLE authenticated;

-- 17. explicit null clears next_action_due (row_version: 4 -> 5)
SELECT is(
  (public.update_deal_property_v1('d1120000-0000-0000-0000-000000000001',
    '{"next_action_due":null}'::jsonb)::json)->>'ok',
  'true',
  'update_deal_property_v1: explicit null on next_action_due accepted'
);

-- 18. explicit null clears next_action_due in DB
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT next_action_due FROM public.deals WHERE id = 'd1120000-0000-0000-0000-000000000001'),
  null,
  'update_deal_property_v1: explicit null clears next_action_due'
);
SET LOCAL ROLE authenticated;

-- 19. invalid timestamp returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_property_v1('d1120000-0000-0000-0000-000000000001',
    '{"next_action_due":"banana"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_property_v1: invalid timestamp returns VALIDATION_ERROR'
);

-- 20. same-value submission returns VALIDATION_ERROR (row_version stays 5)
SELECT is(
  (public.update_deal_property_v1('d1120000-0000-0000-0000-000000000001',
    '{"address":"456 Oak Ave"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_property_v1: same-value submission returns VALIDATION_ERROR'
);

-- 21. empty payload returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_property_v1('d1120000-0000-0000-0000-000000000001',
    '{}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_property_v1: empty payload returns VALIDATION_ERROR'
);

-- 22. non-object payload returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_property_v1('d1120000-0000-0000-0000-000000000001',
    '"lol"'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_property_v1: non-object payload returns VALIDATION_ERROR'
);

-- 23. unknown key returns VALIDATION_ERROR
SELECT is(
  (public.update_deal_property_v1('d1120000-0000-0000-0000-000000000001',
    '{"dead_reason":"nope"}'::jsonb)::json)->>'code',
  'VALIDATION_ERROR',
  'update_deal_property_v1: unknown key returns VALIDATION_ERROR'
);

-- 24. cross-tenant deal returns NOT_FOUND
SELECT is(
  (public.update_deal_property_v1('d1120000-0000-0000-0000-000000000002',
    '{"address":"Hacker St"}'::jsonb)::json)->>'code',
  'NOT_FOUND',
  'update_deal_property_v1: cross-tenant deal returns NOT_FOUND'
);

-- 25. write lock rejection: expire subscription
SET LOCAL ROLE postgres;
UPDATE public.tenant_subscriptions
SET status = 'canceled', current_period_end = now() - interval '70 days'
WHERE tenant_id = 'b1120000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;

SELECT is(
  (public.update_deal_property_v1('d1120000-0000-0000-0000-000000000001',
    '{"address":"Blocked St"}'::jsonb)::json)->>'code',
  'WORKSPACE_NOT_WRITABLE',
  'update_deal_property_v1: expired workspace returns WORKSPACE_NOT_WRITABLE'
);

-- 26. row_version NOT incremented on property write lock rejection (stays 5)
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT row_version FROM public.deals WHERE id = 'd1120000-0000-0000-0000-000000000001'),
  5::bigint,
  'update_deal_property_v1: row_version not incremented on write lock rejection'
);

-- 27. row_version NOT incremented on seller write lock rejection (stays 5)
SELECT is(
  (SELECT row_version FROM public.deals WHERE id = 'd1120000-0000-0000-0000-000000000001'),
  5::bigint,
  'update_deal_seller_v1: row_version not incremented on write lock rejection'
);

SELECT finish();
ROLLBACK;