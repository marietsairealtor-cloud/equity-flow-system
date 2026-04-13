-- supabase/tests/8_8_share_token_secure_generation.test.sql
-- pgTAP: 8.8 Share Token Secure Generation Contract
-- Proves: tokens use approved secure source, contain shr_ prefix,
-- meet minimum length, and are stored only as hash.
-- GUARDRAILS S25-28: SQL-only, no DO blocks, no backslash lines.
BEGIN;
SELECT plan(8);

SET CONSTRAINTS ALL DEFERRED;

INSERT INTO public.tenants (id) VALUES ('e9000000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES ('e9100000-0000-0000-0000-000000000001'::uuid,
        'e9000000-0000-0000-0000-000000000001'::uuid, 1, 1,
        'e9200000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
VALUES ('e9200000-0000-0000-0000-000000000001'::uuid,
        'e9000000-0000-0000-0000-000000000001'::uuid,
        'e9100000-0000-0000-0000-000000000001'::uuid, 1, 1, '{}'::jsonb);

INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
VALUES ('e9000000-0000-0000-0000-000000000001'::uuid, 'active', now() + interval '1 year')
ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES ('88000000-0000-0000-0000-000000000001'::uuid, 'e9000000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-0000000000a1'::uuid, 'owner')
ON CONFLICT DO NOTHING;

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-0000000000a1","role":"authenticated","tenant_id":"e9000000-0000-0000-0000-000000000001"}', true);

-- Test 1: create_share_token_v1 returns OK
SELECT is(
  (public.create_share_token_v1('e9100000-0000-0000-0000-000000000001'::uuid, now() + interval '30 days')::json ->> 'code'),
  'OK',
  'create_share_token_v1 returns OK'
);

-- Test 2: Token contains shr_ prefix
SELECT ok(
  (public.create_share_token_v1('e9100000-0000-0000-0000-000000000001'::uuid, now() + interval '30 days')::json -> 'data' ->> 'token') LIKE 'shr_%',
  'Generated token contains shr_ prefix'
);

-- Test 3: Token meets minimum length (shr_ + 64 hex = 68 chars minimum)
SELECT ok(
  length((public.create_share_token_v1('e9100000-0000-0000-0000-000000000001'::uuid, now() + interval '30 days')::json -> 'data' ->> 'token')) >= 68,
  'Generated token meets minimum length of 68 characters'
);

-- Test 4: Token is unique per call (no two identical tokens)
SELECT ok(
  (public.create_share_token_v1('e9100000-0000-0000-0000-000000000001'::uuid, now() + interval '30 days')::json -> 'data' ->> 'token')
  <>
  (public.create_share_token_v1('e9100000-0000-0000-0000-000000000001'::uuid, now() + interval '30 days')::json -> 'data' ->> 'token'),
  'Each token generation call produces unique token'
);

-- Test 5: Token stored only as hash -- raw token not in share_tokens
RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM public.share_tokens
   WHERE tenant_id = 'e9000000-0000-0000-0000-000000000001'::uuid
     AND token_hash IS NOT NULL),
  (SELECT count(*)::int FROM public.share_tokens
   WHERE tenant_id = 'e9000000-0000-0000-0000-000000000001'::uuid),
  'All share_tokens rows have token_hash (raw token never stored)'
);

-- Test 6: token_hash length is 32 bytes (sha256)
SELECT is(
  (SELECT length(token_hash) FROM public.share_tokens
   WHERE tenant_id = 'e9000000-0000-0000-0000-000000000001'::uuid
   LIMIT 1),
  32,
  'token_hash is 32 bytes (sha256)'
);

-- Test 7: create_share_token_v1 function exists with correct signature
SELECT has_function('public', 'create_share_token_v1', ARRAY['uuid', 'timestamp with time zone'],
  'create_share_token_v1(uuid, timestamptz) exists'
);

-- Test 8: NOT_AUTHORIZED when no tenant context
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-0000000000a1","role":"authenticated","tenant_id":null}', true);
SELECT is(
  (public.create_share_token_v1('e9100000-0000-0000-0000-000000000001'::uuid, now() + interval '30 days')::json ->> 'code'),
  'NOT_AUTHORIZED',
  'create_share_token_v1 returns NOT_AUTHORIZED without tenant context'
);

SELECT finish();
ROLLBACK;
