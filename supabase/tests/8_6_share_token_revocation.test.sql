-- supabase/tests/8_6_share_token_revocation.test.sql
-- pgTAP: 8.6 Share Token Revocation
-- Proves: revoked tokens return NOT_FOUND, identical to nonexistent tokens.
-- Revocation is idempotent. Revoked token cannot be used even if expires_at in future.
-- GUARDRAILS §25-28: SQL-only, no DO blocks, no backslash lines.
BEGIN;
SELECT plan(10);

SET CONSTRAINTS ALL DEFERRED;

-- Seed tenant
INSERT INTO public.tenants (id) VALUES ('f0000000-0000-0000-0000-000000000001'::uuid);

-- Seed deal
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES ('f1000000-0000-0000-0000-000000000001'::uuid,
        'f0000000-0000-0000-0000-000000000001'::uuid, 1, 1,
        'f2000000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
VALUES ('f2000000-0000-0000-0000-000000000001'::uuid,
        'f0000000-0000-0000-0000-000000000001'::uuid,
        'f1000000-0000-0000-0000-000000000001'::uuid, 1, 1, '{}'::jsonb);

-- Seed share tokens
INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at, revoked_at)
VALUES
  -- valid token (not revoked, no expiry)
  ('f3000000-0000-0000-0000-000000000001'::uuid,
   'f0000000-0000-0000-0000-000000000001'::uuid,
   'f1000000-0000-0000-0000-000000000001'::uuid,
   extensions.digest('valid_token_8_6', 'sha256'), now() + interval '30 days', NULL),
  -- revoked token (future expiry — revocation must override)
  ('f3000000-0000-0000-0000-000000000002'::uuid,
   'f0000000-0000-0000-0000-000000000001'::uuid,
   'f1000000-0000-0000-0000-000000000001'::uuid,
   extensions.digest('revoked_token_8_6', 'sha256'),
   now() + interval '1 year',
   now() - interval '1 hour');

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'f0000000-0000-0000-0000-000000000001', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-0000000000a1', true);

-- Test 1: Valid token returns OK
SELECT is(
  (public.lookup_share_token_v1('valid_token_8_6')::json ->> 'code'),
  'OK',
  'Valid token returns OK'
);

-- Test 2: Revoked token returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_v1('revoked_token_8_6')::json ->> 'code'),
  'NOT_FOUND',
  'Revoked token returns NOT_FOUND'
);

-- Test 3: Revoked token response identical to nonexistent token (no existence leak)
SELECT is(
  (public.lookup_share_token_v1('revoked_token_8_6')::json::text),
  (public.lookup_share_token_v1('does_not_exist_8_6')::json::text),
  'Revoked token response identical to nonexistent token (no existence leak)'
);

-- Test 4: Revoked token cannot be used even if expires_at is in the future
SELECT is(
  (public.lookup_share_token_v1('revoked_token_8_6')::json ->> 'code'),
  'NOT_FOUND',
  'Revoked token cannot be used even if expires_at in future (revocation overrides expiration)'
);

-- Test 5: revoke_share_token_v1 succeeds on valid token
SELECT is(
  (public.revoke_share_token_v1('valid_token_8_6')::json ->> 'code'),
  'OK',
  'revoke_share_token_v1 returns OK'
);

-- Test 6: Token is now revoked — lookup returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_v1('valid_token_8_6')::json ->> 'code'),
  'NOT_FOUND',
  'Token is NOT_FOUND after revocation'
);

-- Test 7: Revocation is idempotent — revoking again returns OK
SELECT is(
  (public.revoke_share_token_v1('valid_token_8_6')::json ->> 'code'),
  'OK',
  'Revocation is idempotent — second revoke returns OK'
);

-- Test 8: Revoking nonexistent token returns OK (silent success)
SELECT is(
  (public.revoke_share_token_v1('does_not_exist_8_6')::json ->> 'code'),
  'OK',
  'Revoking nonexistent token returns OK silently'
);

-- Test 9: revoked_at column exists on share_tokens
SELECT has_column('public', 'share_tokens', 'revoked_at',
  'share_tokens has revoked_at column');

-- Test 10: revoke_share_token_v1 function exists
SELECT has_function('public', 'revoke_share_token_v1', ARRAY['text'],
  'revoke_share_token_v1(text) exists');

SELECT finish();
ROLLBACK;

