-- 8.4: Share Token Hash-at-Rest pgTAP tests
-- Proves: raw token not stored, lookup succeeds with correct token,
-- lookup fails with altered token.

BEGIN;
SELECT plan(5);

-- Setup: create test tenant, membership, deal
INSERT INTO public.tenants (id) VALUES ('a0000000-0000-0000-0000-000000000084');
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES ('a1000000-0000-0000-0000-000000000084', 'a0000000-0000-0000-0000-000000000084', '00000000-0000-0000-0000-000000000001', 'owner');
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES ('d0000000-0000-0000-0000-000000000084', 'a0000000-0000-0000-0000-000000000084', 1, 1, 'd0100000-0000-0000-0000-000000000084');

-- Insert a share token using hash
INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at)
VALUES (
  'e0000000-0000-0000-0000-000000000084',
  'a0000000-0000-0000-0000-000000000084',
  'd0000000-0000-0000-0000-000000000084',
  extensions.digest('test-token-84', 'sha256'),
  now() + interval '30 days'
);

-- Test 1: share_tokens table has token_hash column
SELECT has_column('public', 'share_tokens', 'token_hash', 'share_tokens has token_hash column');

-- Test 2: share_tokens table does NOT have raw token column
SELECT hasnt_column('public', 'share_tokens', 'token', 'share_tokens does not have raw token column');

-- Test 3: Raw token cannot be reconstructed -- token_hash is bytea, not reversible
SELECT ok(
  (SELECT pg_typeof(token_hash)::text = 'bytea' FROM public.share_tokens WHERE id = 'e0000000-0000-0000-0000-000000000084'),
  'token_hash is bytea (not reversible text)'
);

-- Test 4: Lookup by correct hash succeeds
SELECT ok(
  (SELECT COUNT(*) = 1 FROM public.share_tokens
   WHERE token_hash = extensions.digest('test-token-84', 'sha256')
     AND tenant_id = 'a0000000-0000-0000-0000-000000000084'),
  'Lookup succeeds with correct token hash'
);

-- Test 5: Lookup by altered token fails
SELECT ok(
  (SELECT COUNT(*) = 0 FROM public.share_tokens
   WHERE token_hash = extensions.digest('wrong-token', 'sha256')
     AND tenant_id = 'a0000000-0000-0000-0000-000000000084'),
  'Lookup fails with altered token hash'
);

SELECT finish();
ROLLBACK;
