-- 10.14B8B -- Dispo Backend -- Expanded Share Packet Fields
-- Paired migrations: 20260616000001 + 20260616000002 + 20260616000003
-- Test count: 43

BEGIN;

SELECT plan(43);

-- ============================================================
-- Seed: tenant 1
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

INSERT INTO public.deals (id, tenant_id, stage, address)
VALUES ('d1000000-0000-0000-0000-000000000001',
        'a1000000-0000-0000-0000-000000000001', 'dispo', '123 Test St');

INSERT INTO public.share_tokens
  (id, tenant_id, deal_id, token_hash, expires_at)
VALUES
  ('f1000000-0000-0000-0000-000000000001',
   'a1000000-0000-0000-0000-000000000001',
   'd1000000-0000-0000-0000-000000000001',
   extensions.digest('shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'sha256'),
   now() + interval '1 day');

-- ============================================================
-- Seed: tenant 2 (cross-tenant)
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
-- TESTS 1-8: Schema columns exist and default to NULL
-- ============================================================
SELECT has_column('public', 'deals', 'dispo_headline',       'deals.dispo_headline column exists');
SELECT has_column('public', 'deals', 'dispo_tagline',        'deals.dispo_tagline column exists');
SELECT has_column('public', 'deals', 'dispo_offer_deadline', 'deals.dispo_offer_deadline column exists');
SELECT has_column('public', 'deals', 'dispo_walkthrough',    'deals.dispo_walkthrough column exists');
SELECT has_column('public', 'deals', 'dispo_features',       'deals.dispo_features column exists');
SELECT has_column('public', 'deals', 'dispo_contact_name',   'deals.dispo_contact_name column exists');
SELECT has_column('public', 'deals', 'dispo_contact_phone',  'deals.dispo_contact_phone column exists');

SELECT is(
  (SELECT dispo_headline FROM public.deals WHERE id = 'd1000000-0000-0000-0000-000000000001'::uuid),
  NULL,
  'existing deal defaults dispo_headline to NULL'
);

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
-- TESTS 9-15: Save new fields via update_dispo_packet_v1
-- ============================================================
SELECT ok(
  (SELECT (public.update_dispo_packet_v1(
    'd1000000-0000-0000-0000-000000000001'::uuid,
    '{"dispo_headline":"Prime Lorne Park Opportunity","dispo_tagline":"Builder & Developer Play","dispo_offer_deadline":"2026-06-19T17:00:00Z","dispo_walkthrough":"TBD -- contact us to schedule","dispo_features":"<ul><li>Massive estate lot</li><li>R2 zoning</li></ul>","dispo_contact_name":"Jami","dispo_contact_phone":"613-703-6781"}'::jsonb
  ) ->> 'ok')::boolean),
  'update_dispo_packet_v1 saves all 7 new B8B fields'
);

SET LOCAL ROLE postgres;
SELECT is(
  (SELECT dispo_headline FROM public.deals WHERE id = 'd1000000-0000-0000-0000-000000000001'::uuid),
  'Prime Lorne Park Opportunity',
  'dispo_headline saved correctly'
);
SELECT is(
  (SELECT dispo_tagline FROM public.deals WHERE id = 'd1000000-0000-0000-0000-000000000001'::uuid),
  'Builder & Developer Play',
  'dispo_tagline saved correctly'
);
SELECT isnt(
  (SELECT dispo_offer_deadline FROM public.deals WHERE id = 'd1000000-0000-0000-0000-000000000001'::uuid),
  NULL,
  'dispo_offer_deadline saved (not null)'
);
SELECT is(
  (SELECT dispo_walkthrough FROM public.deals WHERE id = 'd1000000-0000-0000-0000-000000000001'::uuid),
  'TBD -- contact us to schedule',
  'dispo_walkthrough saved correctly'
);
SELECT isnt(
  (SELECT dispo_features FROM public.deals WHERE id = 'd1000000-0000-0000-0000-000000000001'::uuid),
  NULL,
  'dispo_features saved (not null)'
);
SELECT is(
  (SELECT dispo_contact_name FROM public.deals WHERE id = 'd1000000-0000-0000-0000-000000000001'::uuid),
  'Jami',
  'dispo_contact_name saved correctly'
);
SELECT is(
  (SELECT dispo_contact_phone FROM public.deals WHERE id = 'd1000000-0000-0000-0000-000000000001'::uuid),
  '613-703-6781',
  'dispo_contact_phone saved correctly'
);
SET LOCAL ROLE authenticated;

-- ============================================================
-- TESTS 16-18: Patch semantics
-- ============================================================

-- Omitted field preserved on patch
SELECT ok(
  (SELECT (public.update_dispo_packet_v1(
    'd1000000-0000-0000-0000-000000000001'::uuid,
    '{"dispo_tagline":"Updated tagline"}'::jsonb
  ) ->> 'ok')::boolean),
  'patch with omitted fields returns ok=true'
);

SET LOCAL ROLE postgres;
SELECT is(
  (SELECT dispo_headline FROM public.deals WHERE id = 'd1000000-0000-0000-0000-000000000001'::uuid),
  'Prime Lorne Park Opportunity',
  'omitted dispo_headline preserved on patch'
);

-- Explicit null clears field
SET LOCAL ROLE authenticated;
SELECT ok(
  (SELECT (public.update_dispo_packet_v1(
    'd1000000-0000-0000-0000-000000000001'::uuid,
    '{"dispo_walkthrough":null}'::jsonb
  ) ->> 'ok')::boolean),
  'explicit null clears dispo_walkthrough'
);

SET LOCAL ROLE postgres;
SELECT is(
  (SELECT dispo_walkthrough FROM public.deals WHERE id = 'd1000000-0000-0000-0000-000000000001'::uuid),
  NULL,
  'dispo_walkthrough cleared to NULL by explicit null'
);

-- Empty string normalizes to NULL
SET LOCAL ROLE authenticated;
SELECT ok(
  (SELECT (public.update_dispo_packet_v1(
    'd1000000-0000-0000-0000-000000000001'::uuid,
    '{"dispo_contact_name":""}'::jsonb
  ) ->> 'ok')::boolean),
  'empty string saves ok'
);

SET LOCAL ROLE postgres;
SELECT is(
  (SELECT dispo_contact_name FROM public.deals WHERE id = 'd1000000-0000-0000-0000-000000000001'::uuid),
  NULL,
  'empty string normalizes to NULL for dispo_contact_name'
);
SET LOCAL ROLE authenticated;

-- ============================================================
-- TESTS 22-24: Validation
-- ============================================================
SELECT is(
  (SELECT public.update_dispo_packet_v1(
    'd1000000-0000-0000-0000-000000000001'::uuid,
    '{"dispo_offer_deadline":"not-a-timestamp"}'::jsonb
  ) ->> 'code'),
  'VALIDATION_ERROR',
  'invalid dispo_offer_deadline returns VALIDATION_ERROR'
);

SELECT is(
  (SELECT public.update_dispo_packet_v1(
    'd1000000-0000-0000-0000-000000000001'::uuid,
    '{"unknown_field":"value"}'::jsonb
  ) ->> 'code'),
  'VALIDATION_ERROR',
  'unknown field key returns VALIDATION_ERROR'
);

-- Wrong stage (need an ACQ deal)
SET LOCAL ROLE postgres;
INSERT INTO public.deals (id, tenant_id, stage, address)
VALUES ('d9000000-0000-0000-0000-000000000009',
        'a1000000-0000-0000-0000-000000000001', 'new', '999 Wrong Stage St');
SET LOCAL ROLE authenticated;

SELECT is(
  (SELECT public.update_dispo_packet_v1(
    'd9000000-0000-0000-0000-000000000009'::uuid,
    '{"dispo_headline":"Should fail"}'::jsonb
  ) ->> 'code'),
  'CONFLICT',
  'wrong-stage deal returns CONFLICT'
);

-- ============================================================
-- TESTS 25-26: Guards
-- ============================================================
SET LOCAL request.jwt.claim.sub       = 'b2000000-0000-0000-0000-000000000002';
SET LOCAL request.jwt.claim.role      = 'authenticated';
SET LOCAL request.jwt.claim.tenant_id = 'a2000000-0000-0000-0000-000000000002';
SELECT set_config('request.jwt.claims',
  '{"sub":"b2000000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"a2000000-0000-0000-0000-000000000002"}',
  true);

SELECT is(
  (SELECT public.update_dispo_packet_v1(
    'd1000000-0000-0000-0000-000000000001'::uuid,
    '{"dispo_headline":"Cross-tenant attack"}'::jsonb
  ) ->> 'code'),
  'NOT_FOUND',
  'cross-tenant mutation returns NOT_FOUND'
);

SET LOCAL request.jwt.claim.sub       = 'b1000000-0000-0000-0000-000000000001';
SET LOCAL request.jwt.claim.role      = 'authenticated';
SET LOCAL request.jwt.claim.tenant_id = 'a1000000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claims',
  '{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"a1000000-0000-0000-0000-000000000001"}',
  true);

SET LOCAL ROLE postgres;
DELETE FROM public.tenant_memberships
 WHERE tenant_id = 'a1000000-0000-0000-0000-000000000001'::uuid
   AND user_id   = 'b1000000-0000-0000-0000-000000000001'::uuid;
SET LOCAL ROLE authenticated;

SELECT is(
  (SELECT public.update_dispo_packet_v1(
    'd1000000-0000-0000-0000-000000000001'::uuid,
    '{"dispo_headline":"Non-member attack"}'::jsonb
  ) ->> 'code'),
  'NOT_AUTHORIZED',
  'non-member mutation returns NOT_AUTHORIZED'
);

SET LOCAL ROLE postgres;
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (gen_random_uuid(), 'a1000000-0000-0000-0000-000000000001',
        'b1000000-0000-0000-0000-000000000001', 'member');
SET LOCAL ROLE authenticated;

-- ============================================================
-- Re-save fields for read tests
-- ============================================================
SELECT public.update_dispo_packet_v1(
  'd1000000-0000-0000-0000-000000000001'::uuid,
  '{"dispo_headline":"Prime Lorne Park Opportunity","dispo_tagline":"Builder & Developer Play","dispo_offer_deadline":"2026-06-19T17:00:00Z","dispo_walkthrough":"TBD","dispo_features":"Massive lot, R2 zoning","dispo_contact_name":"Jami","dispo_contact_phone":"613-703-6781"}'::jsonb
);

-- ============================================================
-- TESTS 27-33: Dashboard read returns new fields
-- ============================================================
SELECT is(
  (SELECT items ->> 'dispo_headline'
     FROM json_array_elements(public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items') items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'),
  'Prime Lorne Park Opportunity',
  'list_dispo_dashboard_deals_v1 returns dispo_headline'
);

SELECT is(
  (SELECT items ->> 'dispo_tagline'
     FROM json_array_elements(public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items') items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'),
  'Builder & Developer Play',
  'list_dispo_dashboard_deals_v1 returns dispo_tagline'
);

SELECT isnt(
  (SELECT items ->> 'dispo_offer_deadline'
     FROM json_array_elements(public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items') items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'),
  NULL,
  'list_dispo_dashboard_deals_v1 returns dispo_offer_deadline'
);

SELECT is(
  (SELECT items ->> 'dispo_walkthrough'
     FROM json_array_elements(public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items') items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'),
  'TBD',
  'list_dispo_dashboard_deals_v1 returns dispo_walkthrough'
);

SELECT is(
  (SELECT items ->> 'dispo_features'
     FROM json_array_elements(public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items') items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'),
  'Massive lot, R2 zoning',
  'list_dispo_dashboard_deals_v1 returns dispo_features'
);

SELECT is(
  (SELECT items ->> 'dispo_contact_name'
     FROM json_array_elements(public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items') items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'),
  'Jami',
  'list_dispo_dashboard_deals_v1 returns dispo_contact_name'
);

SELECT is(
  (SELECT items ->> 'dispo_contact_phone'
     FROM json_array_elements(public.list_dispo_dashboard_deals_v1() -> 'data' -> 'items') items
    WHERE items ->> 'id' = 'd1000000-0000-0000-0000-000000000001'),
  '613-703-6781',
  'list_dispo_dashboard_deals_v1 returns dispo_contact_phone'
);

-- ============================================================
-- Switch to anon for public lookup tests
-- ============================================================
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);

-- ============================================================
-- TESTS 34-40: Public lookup returns new fields
-- ============================================================
SELECT is(
  (SELECT public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  ) -> 'data' ->> 'dispo_headline'),
  'Prime Lorne Park Opportunity',
  'lookup_share_token_public_v1 returns dispo_headline'
);

SELECT is(
  (SELECT public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  ) -> 'data' ->> 'dispo_tagline'),
  'Builder & Developer Play',
  'lookup_share_token_public_v1 returns dispo_tagline'
);

SELECT isnt(
  (SELECT public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  ) -> 'data' ->> 'dispo_offer_deadline'),
  NULL,
  'lookup_share_token_public_v1 returns dispo_offer_deadline'
);

SELECT is(
  (SELECT public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  ) -> 'data' ->> 'dispo_walkthrough'),
  'TBD',
  'lookup_share_token_public_v1 returns dispo_walkthrough'
);

SELECT is(
  (SELECT public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  ) -> 'data' ->> 'dispo_features'),
  'Massive lot, R2 zoning',
  'lookup_share_token_public_v1 returns dispo_features'
);

SELECT is(
  (SELECT public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  ) -> 'data' ->> 'dispo_contact_name'),
  'Jami',
  'lookup_share_token_public_v1 returns dispo_contact_name'
);

SELECT is(
  (SELECT public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  ) -> 'data' ->> 'dispo_contact_phone'),
  '613-703-6781',
  'lookup_share_token_public_v1 returns dispo_contact_phone'
);

-- ============================================================
-- TESTS 41-42: Public safety + regression
-- ============================================================
SELECT is(
  (SELECT (public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  )::jsonb -> 'data') ? 'address'),
  false,
  'public lookup does not expose exact address'
);

SELECT is(
  (SELECT (public.lookup_share_token_public_v1(
    'shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  )::jsonb -> 'data') ? 'seller_name'),
  false,
  'public lookup does not expose seller_name'
);

SELECT finish();
ROLLBACK;
