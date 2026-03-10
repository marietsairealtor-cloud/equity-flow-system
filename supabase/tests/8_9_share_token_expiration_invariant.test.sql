-- supabase/tests/8_9_share_token_expiration_invariant.test.sql
-- pgTAP: 8.9 Share Token Expiration Invariant
-- Proves: expires_at NOT NULL, lookup refuses expired tokens,
-- expired response identical to invalid token, revocation precedence holds.
-- GUARDRAILS §25-28: SQL-only, no DO blocks, no backslash lines.
BEGIN;
SELECT plan(7);

SET CONSTRAINTS ALL DEFERRED;

INSERT INTO public.tenants (id) VALUES ('ea000000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES ('ea100000-0000-0000-0000-000000000001'::uuid,
        'ea000000-0000-0000-0000-000000000001'::uuid, 1, 1,
        'ea200000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
VALUES ('ea200000-0000-0000-0000-000000000001'::uuid,
        'ea000000-0000-0000-0000-000000000001'::uuid,
        'ea100000-0000-0000-0000-000000000001'::uuid, 1, 1, '{}'::jsonb);

INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at, revoked_at)
VALUES
  -- valid token (future expiry)
  ('ea300000-0000-0000-0000-000000000001'::uuid,
   'ea000000-0000-0000-0000-000000000001'::uuid,
   'ea100000-0000-0000-0000-000000000001'::uuid,
   extensions.digest('valid_token_8_9', 'sha256'),
   now() + interval '1 hour', NULL),
  -- expired token
  ('ea300000-0000-0000-0000-000000000002'::uuid,
   'ea000000-0000-0000-0000-000000000001'::uuid,
   'ea100000-0000-0000-0000-000000000001'::uuid,
   extensions.digest('expired_token_8_9', 'sha256'),
   now() - interval '1 hour', NULL),
  -- revoked token with future expiry (revocation must override)
  ('ea300000-0000-0000-0000-000000000003'::uuid,
   'ea000000-0000-0000-0000-000000000001'::uuid,
   'ea100000-0000-0000-0000-000000000001'::uuid,
   extensions.digest('revoked_token_8_9', 'sha256'),
   now() + interval '1 year',
   now() - interval '1 hour');

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'ea000000-0000-0000-0000-000000000001', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-0000000000a1', true);

-- Test 1: expires_at column is NOT NULL
RESET ROLE;
SELECT col_not_null('public', 'share_tokens', 'expires_at',
  'expires_at column is NOT NULL'
);

-- Test 2: Valid token before expiry resolves successfully
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'ea000000-0000-0000-0000-000000000001', true);
SELECT is(
  (public.lookup_share_token_v1('valid_token_8_9')::json ->> 'code'),
  'OK',
  'Valid token before expiry resolves successfully'
);

-- Test 3: Expired token returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_v1('expired_token_8_9')::json ->> 'code'),
  'NOT_FOUND',
  'Expired token returns NOT_FOUND'
);

-- Test 4: Expired token response shape identical to nonexistent token
SELECT is(
  (public.lookup_share_token_v1('expired_token_8_9')::json ->> 'code'),
  (public.lookup_share_token_v1('does_not_exist_8_9')::json ->> 'code'),
  'Expired token response code identical to nonexistent token'
);

-- Test 5: Expired token error message identical to nonexistent token
SELECT is(
  (public.lookup_share_token_v1('expired_token_8_9')::json -> 'error' ->> 'message'),
  (public.lookup_share_token_v1('does_not_exist_8_9')::json -> 'error' ->> 'message'),
  'Expired token error message identical to nonexistent token (no existence leak)'
);

-- Test 6: Revoked token with future expiry returns NOT_FOUND (revocation overrides expiration)
SELECT is(
  (public.lookup_share_token_v1('revoked_token_8_9')::json ->> 'code'),
  'NOT_FOUND',
  'Revoked token with future expiry returns NOT_FOUND (revocation overrides expiration)'
);

-- Test 7: create_share_token_v1 requires expires_at — returns VALIDATION_ERROR when NULL passed
SELECT is(
  (public.create_share_token_v1('ea100000-0000-0000-0000-000000000001'::uuid, NULL)::json ->> 'code'),
  'VALIDATION_ERROR',
  'create_share_token_v1 returns VALIDATION_ERROR when expires_at is NULL'
);

SELECT finish();
ROLLBACK;
