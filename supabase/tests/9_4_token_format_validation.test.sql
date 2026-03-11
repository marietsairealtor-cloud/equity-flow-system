-- supabase/tests/9_4_token_format_validation.test.sql
-- pgTAP: 9.4 RPC Token Format Validation
-- Proves: lookup_share_token_v1 validates token format before hashing.
-- Malformed tokens fail with NOT_FOUND - identical shape to invalid tokens (no format leak).
-- Valid format proceeds to lookup stage.
-- GUARDRAILS SS25-28: SQL-only, no DO blocks, no backslash lines.
BEGIN;
SELECT plan(9);

SET CONSTRAINTS ALL DEFERRED;

INSERT INTO public.tenants (id) VALUES ('ec000000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES ('ec100000-0000-0000-0000-000000000001'::uuid,
        'ec000000-0000-0000-0000-000000000001'::uuid, 1, 1,
        'ec200000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
VALUES ('ec200000-0000-0000-0000-000000000001'::uuid,
        'ec000000-0000-0000-0000-000000000001'::uuid,
        'ec100000-0000-0000-0000-000000000001'::uuid, 1, 1, '{}'::jsonb);

-- Seed one valid-format token so Test 9 (valid format proceeds) can resolve OK.
-- Token: shr_ + 64 x 'a' (lowercase hex). Hash matches full token string.
INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at)
VALUES ('ec300000-0000-0000-0000-000000000001'::uuid,
        'ec000000-0000-0000-0000-000000000001'::uuid,
        'ec100000-0000-0000-0000-000000000001'::uuid,
        extensions.digest('shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'sha256'),
        now() + interval '1 hour');

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'ec000000-0000-0000-0000-000000000001', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-0000000000a1', true);

-- Test 1: NULL token returns NOT_FOUND (format guard)
SELECT is(
  (public.lookup_share_token_v1(NULL, 'ec100000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  'NOT_FOUND',
  'NULL token returns NOT_FOUND (format guard fires before hashing)'
);

-- Test 2: Token without shr_ prefix returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_v1('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'ec100000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  'NOT_FOUND',
  'Token without shr_ prefix returns NOT_FOUND'
);

-- Test 3: Token too short (shr_ + 63 hex chars) returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_v1('shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'ec100000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  'NOT_FOUND',
  'Token too short (67 chars) returns NOT_FOUND'
);

-- Test 4: Token with invalid charset in body (uppercase hex) returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_v1('shr_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', 'ec100000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  'NOT_FOUND',
  'Token with uppercase hex body returns NOT_FOUND (charset restricted to [0-9a-f])'
);

-- Test 5: Token with non-hex chars in body returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_v1('shr_zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz', 'ec100000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  'NOT_FOUND',
  'Token with non-hex body returns NOT_FOUND'
);

-- Test 6: Malformed token response code identical to nonexistent valid-format token
SELECT is(
  (public.lookup_share_token_v1('no_prefix_here', 'ec100000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  (public.lookup_share_token_v1('shr_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', 'ec100000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  'Malformed token response code identical to nonexistent valid-format token (no format leak)'
);

-- Test 7: Malformed token error message identical to nonexistent valid-format token
SELECT is(
  (public.lookup_share_token_v1('no_prefix_here', 'ec100000-0000-0000-0000-000000000001'::uuid)::json -> 'error' ->> 'message'),
  (public.lookup_share_token_v1('shr_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', 'ec100000-0000-0000-0000-000000000001'::uuid)::json -> 'error' ->> 'message'),
  'Malformed token error message identical to nonexistent valid-format token (no format leak)'
);

-- Test 8: lookup_share_token_v1(text, uuid) function exists
SELECT has_function('public', 'lookup_share_token_v1', ARRAY['text', 'uuid'],
  'lookup_share_token_v1(text, uuid) exists'
);

-- Test 9: Valid format token proceeds to lookup stage and returns OK
SELECT is(
  (public.lookup_share_token_v1('shr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'ec100000-0000-0000-0000-000000000001'::uuid)::json ->> 'code'),
  'OK',
  'Valid format token proceeds to lookup stage and resolves OK'
);

SELECT finish();
ROLLBACK;