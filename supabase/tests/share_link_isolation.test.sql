-- supabase/tests/share_link_isolation.test.sql
-- 6.7: Share-link surface tests.
-- Cross-tenant negative test, expiry semantics, packet view validation.
-- EXPLAIN planner proof captured in proof log (not pgTAP).
-- Plain SQL only. No DO blocks. No psql meta-commands. No $$ tags.
BEGIN;
SELECT plan(6);

-- Seed: create deals with circular FK pattern (deferred constraints)
SET CONSTRAINTS ALL DEFERRED;

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES
  ('d7000000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 1, 1,
   'd7100000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
VALUES
  ('d7100000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid,
   'd7000000-0000-0000-0000-000000000001'::uuid, 1, 1, '{}'::jsonb);

-- Seed share tokens: one valid, one expired (both Tenant A)
INSERT INTO public.share_tokens (id, tenant_id, deal_id, token, expires_at)
VALUES
  ('d7200000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid,
   'd7000000-0000-0000-0000-000000000001'::uuid, 'valid_token_abc123', NULL),
  ('d7200000-0000-0000-0000-000000000002'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid,
   'd7000000-0000-0000-0000-000000000001'::uuid, 'expired_token_xyz789', '2020-01-01 00:00:00+00');

-- Switch to Tenant A authenticated context
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'a0000000-0000-0000-0000-000000000001', true);

-- Test 1: Valid token lookup with correct tenant returns OK
SELECT is(
  (public.lookup_share_token_v1(
    'a0000000-0000-0000-0000-000000000001'::uuid, 'valid_token_abc123'
  ))::json ->> 'code',
  'OK',
  'Valid token + correct tenant returns OK'
);

-- Test 2: Valid token returns correct deal_id in data
SELECT is(
  ((public.lookup_share_token_v1(
    'a0000000-0000-0000-0000-000000000001'::uuid, 'valid_token_abc123'
  ))::json -> 'data' ->> 'deal_id'),
  'd7000000-0000-0000-0000-000000000001',
  'Valid token returns correct deal_id'
);

-- Test 3: Cross-tenant negative test — Tenant A token looked up with Tenant B tenant_id
-- Caller context is Tenant A, but requesting Tenant B → NOT_AUTHORIZED (context mismatch)
SELECT is(
  (public.lookup_share_token_v1(
    'b0000000-0000-0000-0000-000000000001'::uuid, 'valid_token_abc123'
  ))::json ->> 'code',
  'NOT_AUTHORIZED',
  'Tenant A token looked up under Tenant B context returns NOT_AUTHORIZED'
);

-- Test 4: Expired token returns TOKEN_EXPIRED (distinct code per CONTRACTS S1)
SELECT is(
  (public.lookup_share_token_v1(
    'a0000000-0000-0000-0000-000000000001'::uuid, 'expired_token_xyz789'
  ))::json ->> 'code',
  'TOKEN_EXPIRED',
  'Expired token returns TOKEN_EXPIRED (distinct from NOT_FOUND)'
);

-- Test 5: Nonexistent token returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_v1(
    'a0000000-0000-0000-0000-000000000001'::uuid, 'does_not_exist'
  ))::json ->> 'code',
  'NOT_FOUND',
  'Nonexistent token returns NOT_FOUND'
);

-- Test 6: Packet view only exposes allowlisted columns
RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'share_token_packet'),
  4,
  'Packet view exposes exactly 4 columns (token, deal_id, expires_at, calc_version)'
);

SELECT * FROM finish();
ROLLBACK;
