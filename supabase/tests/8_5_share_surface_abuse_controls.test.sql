-- 8.5: Share Surface Abuse Controls pgTAP tests
-- Anti-enumeration: invalid token response shape = nonexistent token response shape.
-- Expiry: expired token fails deterministically with TOKEN_EXPIRED.
-- Cross-tenant: token under wrong tenant context returns NOT_FOUND.

BEGIN;
SELECT plan(6);

-- Seed: Tenant A with deal and share tokens
SET CONSTRAINTS ALL DEFERRED;
INSERT INTO public.tenants (id) VALUES ('a0000000-0000-0000-0000-000000000085');
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES ('a1000000-0000-0000-0000-000000000085', 'a0000000-0000-0000-0000-000000000085', '00000000-0000-0000-0000-000000000001', 'owner');
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES ('d0000000-0000-0000-0000-000000000085', 'a0000000-0000-0000-0000-000000000085', 1, 1, 'd0100000-0000-0000-0000-000000000085');

-- Valid token (not expired)
INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash)
VALUES ('e0000000-0000-0000-0000-000000000085', 'a0000000-0000-0000-0000-000000000085', 'd0000000-0000-0000-0000-000000000085',
  extensions.digest('valid-abuse-test-token', 'sha256'));

-- Expired token
INSERT INTO public.share_tokens (id, tenant_id, deal_id, token_hash, expires_at)
VALUES ('e1000000-0000-0000-0000-000000000085', 'a0000000-0000-0000-0000-000000000085', 'd0000000-0000-0000-0000-000000000085',
  extensions.digest('expired-abuse-test-token', 'sha256'), '2020-01-01 00:00:00+00');

-- Tenant B (for cross-tenant test)
INSERT INTO public.tenants (id) VALUES ('b0000000-0000-0000-0000-000000000085');
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES ('b1000000-0000-0000-0000-000000000085', 'b0000000-0000-0000-0000-000000000085', '00000000-0000-0000-0000-000000000002', 'owner');

-- Set Tenant A context
SELECT set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000001')::text, true);
SELECT set_config('request.jwt.claim.tenant_id', 'a0000000-0000-0000-0000-000000000085', true);
SET ROLE authenticated;

-- Test 1: Expired token returns TOKEN_EXPIRED deterministically
SELECT is(
  (public.lookup_share_token_v1('expired-abuse-test-token')::json ->> 'code'),
  'TOKEN_EXPIRED',
  'Expired token returns TOKEN_EXPIRED deterministically'
);

-- Test 2: Nonexistent token returns NOT_FOUND
SELECT is(
  (public.lookup_share_token_v1('completely-nonexistent-token')::json ->> 'code'),
  'NOT_FOUND',
  'Nonexistent token returns NOT_FOUND'
);

-- Test 3: Invalid (random garbage) token returns NOT_FOUND — same shape as nonexistent
SELECT is(
  (public.lookup_share_token_v1('aaaa-bbbb-cccc-not-a-real-token')::json ->> 'code'),
  'NOT_FOUND',
  'Invalid token returns NOT_FOUND — same response shape as nonexistent (anti-enumeration)'
);

-- Test 4: NOT_FOUND response shape matches between nonexistent and invalid tokens
SELECT is(
  (public.lookup_share_token_v1('completely-nonexistent-token')::json ->> 'error'),
  (public.lookup_share_token_v1('aaaa-bbbb-cccc-not-a-real-token')::json ->> 'error'),
  'Nonexistent and invalid tokens produce identical error shape (no existence leak)'
);

-- Test 5: Cross-tenant — Tenant B cannot see Tenant A token
RESET ROLE;
SELECT set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000002')::text, true);
SELECT set_config('request.jwt.claim.tenant_id', 'b0000000-0000-0000-0000-000000000085', true);
SET ROLE authenticated;

SELECT is(
  (public.lookup_share_token_v1('valid-abuse-test-token')::json ->> 'code'),
  'NOT_FOUND',
  'Cross-tenant: Tenant A token under Tenant B context returns NOT_FOUND (isolated)'
);

-- Test 6: Cross-tenant NOT_FOUND shape matches regular NOT_FOUND (no tenant-existence leak)
SELECT is(
  (public.lookup_share_token_v1('valid-abuse-test-token')::json ->> 'error'),
  (public.lookup_share_token_v1('does-not-exist-at-all')::json ->> 'error'),
  'Cross-tenant NOT_FOUND shape matches regular NOT_FOUND (no tenant leak)'
);

SELECT finish();
ROLLBACK;