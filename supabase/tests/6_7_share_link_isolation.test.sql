-- supabase/tests/share_link_isolation.test.sql
-- 6.7: Share-link surface tests.
-- Cross-tenant negative test, expiry semantics, packet view validation.
-- EXPLAIN planner proof captured in proof log (not pgTAP).
-- Plain SQL only. No DO blocks. No psql meta-commands. No bare dollar-quoting.
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
INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at)
VALUES
  ('d7200000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid,
   'd7000000-0000-0000-0000-000000000001'::uuid, extensions.digest('shr_67000000000000000000000000000000000000000000000000000000000000aa', 'sha256'), now() + interval '30 days'),
  ('d7200000-0000-0000-0000-000000000002'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid,
   'd7000000-0000-0000-0000-000000000001'::uuid, extensions.digest('shr_67000000000000000000000000000000000000000000000000000000000000bb', 'sha256'), '2020-01-01 00:00:00+00');

-- Switch to Tenant A authenticated context
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'a0000000-0000-0000-0000-000000000001', true);

-- Test 1: Valid token lookup returns OK
SELECT is(
  (public.lookup_share_token_v1('shr_67000000000000000000000000000000000000000000000000000000000000aa', 'd7000000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  'OK',
  'Valid token + correct tenant returns OK'
);

-- Test 2: Valid token returns correct deal_id in data
SELECT is(
  (public.lookup_share_token_v1('shr_67000000000000000000000000000000000000000000000000000000000000aa', 'd7000000-0000-0000-0000-000000000001'::uuid)::json -> 'data' ->> 'deal_id'),
  'd7000000-0000-0000-0000-000000000001',
  'Valid token returns correct deal_id'
);

-- Test 3: Cross-tenant isolation -- Tenant B JWT cannot see Tenant A token
SELECT set_config('request.jwt.claim.tenant_id', 'b0000000-0000-0000-0000-000000000001', true);
SELECT is(
  (public.lookup_share_token_v1('shr_67000000000000000000000000000000000000000000000000000000000000aa', 'd7000000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  'NOT_FOUND',
  'Tenant A token under Tenant B JWT context returns NOT_FOUND (isolated)'
);

-- Restore Tenant A context
SELECT set_config('request.jwt.claim.tenant_id', 'a0000000-0000-0000-0000-000000000001', true);

-- Test 4: Expired token returns NOT_FOUND (no existence leak per 8.9)
SELECT is(
  (public.lookup_share_token_v1('shr_67000000000000000000000000000000000000000000000000000000000000bb', 'd7000000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  'NOT_FOUND',
  'Expired token returns NOT_FOUND (no existence leak)'
);

-- Test 5: Nonexistent token returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_v1('shr_67000000000000000000000000000000000000000000000000000000000000cc', 'd7000000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  'NOT_FOUND',
  'Nonexistent token returns NOT_FOUND'
);

-- Test 6: Packet view only exposes allowlisted columns
RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'share_token_packet'),
  3,
  'Packet view exposes exactly 3 columns (deal_id, expires_at, calc_version)'
);

SELECT * FROM finish();
ROLLBACK;
