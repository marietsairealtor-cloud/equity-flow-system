-- 10.14B8A -- Dispo Dashboard Packet + Media Approval Read Extension
-- Paired migrations: 20260613000001 + 20260613000002
-- Test count: 18

BEGIN;

SELECT plan(20);

-- ============================================================
-- Seed: tenant 1 (primary)
-- ============================================================
INSERT INTO public.tenants (id, name)
VALUES ('a1000000-0000-0000-0000-000000000001', 'T1');

INSERT INTO auth.users (id, email)
VALUES ('b1000000-0000-0000-0000-000000000001', 'member1@t1.test');

INSERT INTO public.user_profiles (id, current_tenant_id)
VALUES ('b1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001');

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (gen_random_uuid(), 'a1000000-0000-0000-0000-000000000001',
        'b1000000-0000-0000-0000-000000000001', 'member');

INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
VALUES ('a1000000-0000-0000-0000-000000000001', 'active', now() + interval '30 days');

-- Deal with packet fields set
INSERT INTO public.deals (
  id, tenant_id, stage, address,
  dispo_asking_price, dispo_intersection, dispo_closing_date,
  dispo_description, dispo_comparables, dispo_media_url,
  dispo_market_value_estimate, dispo_below_market_override
)
VALUES (
  'd1000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001',
  'dispo', '123 Test St',
  350000, 'King & Spadina', '2026-08-01',
  'Great brick detached.', 'Comp1 sold $400k.', 'https://example.com/media',
  430000, NULL
);

-- Deal with override set
INSERT INTO public.deals (
  id, tenant_id, stage, address,
  dispo_asking_price, dispo_market_value_estimate, dispo_below_market_override
)
VALUES (
  'd2000000-0000-0000-0000-000000000002',
  'a1000000-0000-0000-0000-000000000001',
  'dispo', '456 Override St',
  300000, 400000, 90000
);

-- Deal with null market + null asking
INSERT INTO public.deals (id, tenant_id, stage, address)
VALUES (
  'd3000000-0000-0000-0000-000000000003',
  'a1000000-0000-0000-0000-000000000001',
  'dispo', '789 Null St'
);

-- Media for deal 1: one approved, one unapproved
INSERT INTO public.deal_media (id, tenant_id, deal_id, storage_path, sort_order, uploaded_by)
VALUES
  ('e1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001',
   'd1000000-0000-0000-0000-000000000001',
   'a1000000/d1000000/e1000000.jpg', 1, 'b1000000-0000-0000-0000-000000000001'),
  ('e2000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000001',
   'd1000000-0000-0000-0000-000000000001',
   'a1000000/d1000000/e2000000.jpg', 2, 'b1000000-0000-0000-0000-000000000001');

-- Approve e1
UPDATE public.deal_media
   SET is_dispo_approved = true,
       dispo_approved_at = now(),
       dispo_approved_by = 'b1000000-0000-0000-0000-000000000001'::uuid
 WHERE id = 'e1000000-0000-0000-0000-000000000001'::uuid;

-- ============================================================
-- Seed: tenant 2 (cross-tenant isolation)
-- ============================================================
INSERT INTO public.tenants (id, name)
VALUES ('a2000000-0000-0000-0000-000000000002', 'T2');

INSERT INTO auth.users (id, email)
VALUES ('b2000000-0000-0000-0000-000000000002', 'member2@t2.test');

INSERT INTO public.user_profiles (id, current_tenant_id)
VALUES ('b2000000-0000-0000-0000-000000000002', 'a2000000-0000-0000-0000-000000000002');

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (gen_random_uuid(), 'a2000000-0000-0000-0000-000000000002',
        'b2000000-0000-0000-0000-000000000002', 'member');

INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
VALUES ('a2000000-0000-0000-0000-000000000002', 'active', now() + interval '30 days');

-- ============================================================
-- Set JWT context: tenant 1 member
-- ============================================================
SET LOCAL request.jwt.claim.sub       = 'b1000000-0000-0000-0000-000000000001';
SET LOCAL request.jwt.claim.role      = 'authenticated';
SET LOCAL request.jwt.claim.tenant_id = 'a1000000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claims',
  '{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"a1000000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- ============================================================
-- TESTS 1-8: packet fields present in list_dispo_dashboard_deals_v1
-- ============================================================
SELECT is(
  (SELECT (
    SELECT items ->> 'dispo_asking_price'
    FROM json_array_elements(
      public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items'
    ) items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'
  )::numeric),
  350000::numeric,
  'list_dispo_dashboard_deals_v1 returns dispo_asking_price'
);

SELECT is(
  (SELECT (
    SELECT items ->> 'dispo_intersection'
    FROM json_array_elements(
      public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items'
    ) items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'
  )),
  'King & Spadina',
  'list_dispo_dashboard_deals_v1 returns dispo_intersection'
);

SELECT is(
  (SELECT (
    SELECT items ->> 'dispo_closing_date'
    FROM json_array_elements(
      public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items'
    ) items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'
  )),
  '2026-08-01',
  'list_dispo_dashboard_deals_v1 returns dispo_closing_date'
);

SELECT is(
  (SELECT (
    SELECT items ->> 'dispo_description'
    FROM json_array_elements(
      public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items'
    ) items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'
  )),
  'Great brick detached.',
  'list_dispo_dashboard_deals_v1 returns dispo_description'
);

SELECT is(
  (SELECT (
    SELECT items ->> 'dispo_comparables'
    FROM json_array_elements(
      public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items'
    ) items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'
  )),
  'Comp1 sold $400k.',
  'list_dispo_dashboard_deals_v1 returns dispo_comparables'
);

SELECT is(
  (SELECT (
    SELECT items ->> 'dispo_media_url'
    FROM json_array_elements(
      public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items'
    ) items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'
  )),
  'https://example.com/media',
  'list_dispo_dashboard_deals_v1 returns dispo_media_url'
);

SELECT is(
  (SELECT (
    SELECT items ->> 'dispo_market_value_estimate'
    FROM json_array_elements(
      public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items'
    ) items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'
  )::numeric),
  430000::numeric,
  'list_dispo_dashboard_deals_v1 returns dispo_market_value_estimate'
);

SELECT is(
  (SELECT (
    SELECT items ->> 'dispo_below_market_override'
    FROM json_array_elements(
      public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items'
    ) items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'
  )),
  NULL,
  'list_dispo_dashboard_deals_v1 returns dispo_below_market_override (null when not set)'
);

-- ============================================================
-- TEST 9: derived dispo_below_market_value = market - asking
-- Deal 1: 430000 - 350000 = 80000
-- ============================================================
SELECT is(
  (SELECT (
    SELECT items ->> 'dispo_below_market_value'
    FROM json_array_elements(
      public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items'
    ) items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'
  )::numeric),
  80000::numeric,
  'dispo_below_market_value derived as market_value - asking_price'
);

-- ============================================================
-- TEST 10: override takes precedence over derived
-- Deal 2: override=90000, derived would be 400000-300000=100000
-- ============================================================
SELECT is(
  (SELECT (
    SELECT items ->> 'dispo_below_market_value'
    FROM json_array_elements(
      public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items'
    ) items
    WHERE items ->> 'id' = 'd2000000-0000-0000-0000-000000000002'
  )::numeric),
  90000::numeric,
  'dispo_below_market_override takes precedence over derived value'
);

-- ============================================================
-- TEST 11: null market + null asking = null dispo_below_market_value
-- ============================================================
SELECT is(
  (SELECT (
    SELECT items ->> 'dispo_below_market_value'
    FROM json_array_elements(
      public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items'
    ) items
    WHERE items ->> 'id' = 'd3000000-0000-0000-0000-000000000003'
  )),
  NULL,
  'null market value and null asking price returns null dispo_below_market_value'
);

-- ============================================================
-- TESTS 12-15: list_deal_media_v1 returns approval fields
-- ============================================================
SELECT is(
  (SELECT (
    SELECT m ->> 'is_dispo_approved'
    FROM json_array_elements(
      public.list_deal_media_v1('d1000000-0000-0000-0000-000000000001'::uuid) -> 'data' -> 'items'
    ) m
    WHERE m ->> 'id' = 'e1000000-0000-0000-0000-000000000001'
  )),
  'true',
  'list_deal_media_v1 returns is_dispo_approved on approved media'
);

SELECT isnt(
  (SELECT (
    SELECT m ->> 'dispo_approved_at'
    FROM json_array_elements(
      public.list_deal_media_v1('d1000000-0000-0000-0000-000000000001'::uuid) -> 'data' -> 'items'
    ) m
    WHERE m ->> 'id' = 'e1000000-0000-0000-0000-000000000001'
  )),
  NULL,
  'list_deal_media_v1 returns dispo_approved_at (not null) for approved media'
);

SELECT is(
  (SELECT (
    SELECT m ->> 'dispo_approved_by'
    FROM json_array_elements(
      public.list_deal_media_v1('d1000000-0000-0000-0000-000000000001'::uuid) -> 'data' -> 'items'
    ) m
    WHERE m ->> 'id' = 'e1000000-0000-0000-0000-000000000001'
  )),
  'b1000000-0000-0000-0000-000000000001',
  'list_deal_media_v1 returns dispo_approved_by for approved media'
);

-- Unapproved media (e2) also readable -- is_dispo_approved = false
SELECT is(
  (SELECT (
    SELECT m ->> 'is_dispo_approved'
    FROM json_array_elements(
      public.list_deal_media_v1('d1000000-0000-0000-0000-000000000001'::uuid) -> 'data' -> 'items'
    ) m
    WHERE m ->> 'id' = 'e2000000-0000-0000-0000-000000000002'
  )),
  'false',
  'list_deal_media_v1 returns unapproved media with is_dispo_approved=false'
);

-- ============================================================
-- TEST 16: list_deal_media_v1 non-member returns NOT_AUTHORIZED
-- ============================================================
SET LOCAL ROLE postgres;
DELETE FROM public.tenant_memberships
 WHERE tenant_id = 'a1000000-0000-0000-0000-000000000001'::uuid
   AND user_id   = 'b1000000-0000-0000-0000-000000000001'::uuid;
SET LOCAL ROLE authenticated;

SELECT is(
  (SELECT public.list_deal_media_v1(
    'd1000000-0000-0000-0000-000000000001'::uuid) ->> 'code'),
  'NOT_AUTHORIZED',
  'list_deal_media_v1 non-member returns NOT_AUTHORIZED'
);

SET LOCAL ROLE postgres;
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (gen_random_uuid(), 'a1000000-0000-0000-0000-000000000001',
        'b1000000-0000-0000-0000-000000000001', 'member');
SET LOCAL ROLE authenticated;

-- ============================================================
-- TEST 17: cross-tenant returns NOT_FOUND
-- Tenant 2 member tries to read tenant 1 deal media
-- ============================================================
SET LOCAL request.jwt.claim.sub       = 'b2000000-0000-0000-0000-000000000002';
SET LOCAL request.jwt.claim.role      = 'authenticated';
SET LOCAL request.jwt.claim.tenant_id = 'a2000000-0000-0000-0000-000000000002';
SELECT set_config('request.jwt.claims',
  '{"sub":"b2000000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"a2000000-0000-0000-0000-000000000002"}',
  true);

SELECT is(
  (SELECT public.list_deal_media_v1(
    'd1000000-0000-0000-0000-000000000001'::uuid) ->> 'code'),
  'NOT_FOUND',
  'list_deal_media_v1 cross-tenant returns NOT_FOUND'
);

-- ============================================================
-- TEST 18: list_dispo_dashboard_deals_v1 still returns ok=true
-- ============================================================
SET LOCAL request.jwt.claim.sub       = 'b1000000-0000-0000-0000-000000000001';
SET LOCAL request.jwt.claim.role      = 'authenticated';
SET LOCAL request.jwt.claim.tenant_id = 'a1000000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claims',
  '{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"a1000000-0000-0000-0000-000000000001"}',
  true);

SELECT ok(
  (SELECT (public.list_dispo_dashboard_deals_v1() ->> 'ok')::boolean),
  'list_dispo_dashboard_deals_v1 still returns ok=true (existing contract intact)'
);

-- ============================================================
-- TEST 19: list_dispo_dashboard_deals_v1 does not return cross-tenant deals
-- ============================================================
SET LOCAL request.jwt.claim.sub       = 'b2000000-0000-0000-0000-000000000002';
SET LOCAL request.jwt.claim.role      = 'authenticated';
SET LOCAL request.jwt.claim.tenant_id = 'a2000000-0000-0000-0000-000000000002';
SELECT set_config('request.jwt.claims',
  '{"sub":"b2000000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"a2000000-0000-0000-0000-000000000002"}',
  true);

SELECT is(
  (SELECT count(*)::int
     FROM json_array_elements(
       public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items'
     ) items
    WHERE items ->> 'id' IN (
      'd1000000-0000-0000-0000-000000000001',
      'd2000000-0000-0000-0000-000000000002',
      'd3000000-0000-0000-0000-000000000003'
    )
  ),
  0,
  'list_dispo_dashboard_deals_v1 does not return cross-tenant deals'
);

-- ============================================================
-- TEST 20: list_dispo_dashboard_deals_v1 non-member returns NOT_AUTHORIZED
-- ============================================================
SET LOCAL request.jwt.claim.sub       = 'b1000000-0000-0000-0000-000000000001';
SET LOCAL request.jwt.claim.role      = 'authenticated';
SET LOCAL request.jwt.claim.tenant_id = 'a1000000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claims',
  '{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"a1000000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

SET LOCAL ROLE postgres;
DELETE FROM public.tenant_memberships
 WHERE tenant_id = 'a1000000-0000-0000-0000-000000000001'::uuid
   AND user_id   = 'b1000000-0000-0000-0000-000000000001'::uuid;
SET LOCAL ROLE authenticated;

SELECT is(
  (SELECT public.list_dispo_dashboard_deals_v1() ->> 'code'),
  'NOT_AUTHORIZED',
  'list_dispo_dashboard_deals_v1 non-member returns NOT_AUTHORIZED'
);

SET LOCAL ROLE postgres;
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (gen_random_uuid(), 'a1000000-0000-0000-0000-000000000001',
        'b1000000-0000-0000-0000-000000000001', 'member');
SET LOCAL ROLE authenticated;

SELECT finish();
ROLLBACK;
