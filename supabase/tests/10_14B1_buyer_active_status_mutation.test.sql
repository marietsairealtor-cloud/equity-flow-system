-- 10.14B1: Dispo Backend -- Buyer Active Status Mutation
BEGIN;

SELECT plan(9);

SELECT public.create_active_workspace_seed_v1(
  'b14b1000-0000-4000-8000-000000000001'::uuid,
  'a14b1000-0000-4000-8000-0000000000a1'::uuid,
  'member'::public.tenant_role
);

SELECT public.create_active_workspace_seed_v1(
  'b14b1000-0000-4000-8000-000000000002'::uuid,
  'a14b1000-0000-4000-8000-0000000000b2'::uuid,
  'member'::public.tenant_role
);

INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES (
  'a14b1000-0000-4000-8000-000000000099'::uuid,
  'seed_10_14b1_nomember@test.local',
  now(), now(), '{}', '{}', 'authenticated', 'authenticated'
) ON CONFLICT DO NOTHING;

SET LOCAL ROLE postgres;

INSERT INTO public.intake_buyers (
  id, tenant_id, name, email, phone, is_active, created_at, updated_at
) VALUES
  (
    'b14b1000-0000-4000-8000-000000000101'::uuid,
    'b14b1000-0000-4000-8000-000000000001'::uuid,
    'Active Buyer', 'active@test.local', '555-0001',
    true, now(), now()
  ),
  (
    'b14b1000-0000-4000-8000-000000000102'::uuid,
    'b14b1000-0000-4000-8000-000000000001'::uuid,
    'Inactive Buyer', 'inactive@test.local', '555-0002',
    false, now(), now()
  ),
  (
    'b14b1000-0000-4000-8000-000000000103'::uuid,
    'b14b1000-0000-4000-8000-000000000002'::uuid,
    'Other Tenant Buyer', 'other@test.local', '555-0003',
    true, now(), now()
  );

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a14b1000-0000-4000-8000-0000000000a1","role":"authenticated","tenant_id":"b14b1000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

-- 1. null p_buyer_id returns VALIDATION_ERROR
SELECT is(
  (public.update_buyer_active_status_v1(NULL::uuid, true)::jsonb->>'code'),
  'VALIDATION_ERROR',
  '10.14B1: null p_buyer_id returns VALIDATION_ERROR'
);

-- 2. null p_is_active returns VALIDATION_ERROR
SELECT is(
  (public.update_buyer_active_status_v1('b14b1000-0000-4000-8000-000000000101'::uuid, NULL::boolean)::jsonb->>'code'),
  'VALIDATION_ERROR',
  '10.14B1: null p_is_active returns VALIDATION_ERROR'
);

-- 3. cross-tenant buyer returns NOT_FOUND
SELECT is(
  (public.update_buyer_active_status_v1('b14b1000-0000-4000-8000-000000000103'::uuid, false)::jsonb->>'code'),
  'NOT_FOUND',
  '10.14B1: cross-tenant buyer returns NOT_FOUND'
);

-- 4. deactivate active buyer succeeds
SELECT is(
  (public.update_buyer_active_status_v1('b14b1000-0000-4000-8000-000000000101'::uuid, false)::jsonb->>'ok'),
  'true',
  '10.14B1: active buyer can be deactivated'
);

SET LOCAL ROLE postgres;

-- 5. is_active persisted as false
SELECT is(
  (SELECT is_active FROM public.intake_buyers WHERE id = 'b14b1000-0000-4000-8000-000000000101'::uuid),
  false,
  '10.14B1: is_active persisted as false after deactivate'
);

SET LOCAL ROLE authenticated;

-- 6. activate inactive buyer succeeds
SELECT is(
  (public.update_buyer_active_status_v1('b14b1000-0000-4000-8000-000000000102'::uuid, true)::jsonb->>'ok'),
  'true',
  '10.14B1: inactive buyer can be activated'
);

SET LOCAL ROLE postgres;

-- 7. is_active persisted as true
SELECT is(
  (SELECT is_active FROM public.intake_buyers WHERE id = 'b14b1000-0000-4000-8000-000000000102'::uuid),
  true,
  '10.14B1: is_active persisted as true after activate'
);

-- 8. list_buyers_v1 reflects updated is_active
SET LOCAL ROLE authenticated;
SELECT ok(
  EXISTS (
    SELECT 1
    FROM json_array_elements(
      (public.list_buyers_v1()->'data'->'items')::json
    ) AS b
    WHERE (b->>'id') = 'b14b1000-0000-4000-8000-000000000102'
      AND (b->>'is_active') = 'true'
  ),
  '10.14B1: list_buyers_v1 reflects updated is_active'
);

-- 9. non-member cannot update buyer status
SET LOCAL ROLE postgres;
UPDATE public.user_profiles
SET current_tenant_id = NULL
WHERE id = 'a14b1000-0000-4000-8000-0000000000a1'::uuid;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a14b1000-0000-4000-8000-000000000099","role":"authenticated","tenant_id":"b14b1000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.update_buyer_active_status_v1('b14b1000-0000-4000-8000-000000000101'::uuid, true)::jsonb->>'code'),
  'NOT_AUTHORIZED',
  '10.14B1: non-member cannot update buyer status'
);

SELECT finish();
ROLLBACK;