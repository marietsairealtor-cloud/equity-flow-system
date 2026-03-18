-- 10_5_rpc_error_contract_tests.test.sql
-- Build Route 10.5: RPC Error Contract Tests
-- Verifies error responses from public RPCs follow the frozen envelope contract.
-- Tests run as superuser with JWT claims set to simulate calling context.

BEGIN;
SELECT plan(40);

-- Seed test tenant, user, and deal
INSERT INTO public.tenants (id)
  VALUES ('a0500000-0000-0000-0000-000000000001'::uuid);

INSERT INTO auth.users (id, email)
  VALUES ('a0500000-0000-0000-0000-000000000002'::uuid, 'error_contract_test@10_5.test');

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES (
    'a0500000-0000-0000-0000-000000000003'::uuid,
    'a0500000-0000-0000-0000-000000000001'::uuid,
    'a0500000-0000-0000-0000-000000000002'::uuid,
    'member'
  );

-- Authenticated context
SELECT set_config('request.jwt.claims',
  '{"sub":"a0500000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"a0500000-0000-0000-0000-000000000001"}',
  true);

-- Seed a deal for token tests
SELECT public.create_deal_v1('a0500000-0000-0000-0000-000000000004'::uuid, 1, '{}'::jsonb);

-- ============================================================
-- create_deal_v1 -- CONFLICT (duplicate deal)
-- ============================================================
SELECT is(
  (public.create_deal_v1('a0500000-0000-0000-0000-000000000004'::uuid)::json)->>'ok',
  'false',
  'create_deal_v1 CONFLICT: ok=false'
);
SELECT is(
  (public.create_deal_v1('a0500000-0000-0000-0000-000000000004'::uuid)::json)->>'code',
  'CONFLICT',
  'create_deal_v1 CONFLICT: code=CONFLICT'
);
SELECT is(
  (public.create_deal_v1('a0500000-0000-0000-0000-000000000004'::uuid)::json)->>'data',
  NULL,
  'create_deal_v1 CONFLICT: data=null'
);
SELECT isnt(
  (public.create_deal_v1('a0500000-0000-0000-0000-000000000004'::uuid)::json)->>'error',
  NULL,
  'create_deal_v1 CONFLICT: error present'
);

-- ============================================================
-- update_deal_v1 -- CONFLICT (row version mismatch)
-- ============================================================
SELECT is(
  (public.update_deal_v1('a0500000-0000-0000-0000-000000000004'::uuid, 999)::json)->>'ok',
  'false',
  'update_deal_v1 CONFLICT: ok=false'
);
SELECT is(
  (public.update_deal_v1('a0500000-0000-0000-0000-000000000004'::uuid, 999)::json)->>'code',
  'CONFLICT',
  'update_deal_v1 CONFLICT: code=CONFLICT'
);
SELECT is(
  (public.update_deal_v1('a0500000-0000-0000-0000-000000000004'::uuid, 999)::json)->>'data',
  NULL,
  'update_deal_v1 CONFLICT: data=null'
);
SELECT isnt(
  (public.update_deal_v1('a0500000-0000-0000-0000-000000000004'::uuid, 999)::json)->>'error',
  NULL,
  'update_deal_v1 CONFLICT: error present'
);

-- ============================================================
-- create_share_token_v1 -- VALIDATION_ERROR (null expires_at)
-- ============================================================
SELECT is(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000004'::uuid, NULL)::json)->>'ok',
  'false',
  'create_share_token_v1 VALIDATION_ERROR null expires_at: ok=false'
);
SELECT is(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000004'::uuid, NULL)::json)->>'code',
  'VALIDATION_ERROR',
  'create_share_token_v1 VALIDATION_ERROR null expires_at: code=VALIDATION_ERROR'
);
SELECT is(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000004'::uuid, NULL)::json)->>'data',
  NULL,
  'create_share_token_v1 VALIDATION_ERROR null expires_at: data=null'
);
SELECT isnt(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000004'::uuid, NULL)::json)->>'error',
  NULL,
  'create_share_token_v1 VALIDATION_ERROR null expires_at: error present'
);

-- ============================================================
-- create_share_token_v1 -- VALIDATION_ERROR (past expires_at)
-- ============================================================
SELECT is(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000004'::uuid, now() - interval '1 day')::json)->>'code',
  'VALIDATION_ERROR',
  'create_share_token_v1 VALIDATION_ERROR past expires_at: code=VALIDATION_ERROR'
);

-- ============================================================
-- create_share_token_v1 -- VALIDATION_ERROR (>90 days expires_at)
-- ============================================================
SELECT is(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000004'::uuid, now() + interval '91 days')::json)->>'code',
  'VALIDATION_ERROR',
  'create_share_token_v1 VALIDATION_ERROR >90d expires_at: code=VALIDATION_ERROR'
);
SELECT isnt(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000004'::uuid, now() + interval '91 days')::json)->'error'->>'fields',
  NULL,
  'create_share_token_v1 VALIDATION_ERROR >90d: error.fields present'
);

-- ============================================================
-- create_share_token_v1 -- NOT_FOUND (deal not in tenant)
-- ============================================================
SELECT is(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000099'::uuid, now() + interval '1 day')::json)->>'ok',
  'false',
  'create_share_token_v1 NOT_FOUND: ok=false'
);
SELECT is(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000099'::uuid, now() + interval '1 day')::json)->>'code',
  'NOT_FOUND',
  'create_share_token_v1 NOT_FOUND: code=NOT_FOUND'
);
SELECT is(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000099'::uuid, now() + interval '1 day')::json)->>'data',
  NULL,
  'create_share_token_v1 NOT_FOUND: data=null'
);
SELECT isnt(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000099'::uuid, now() + interval '1 day')::json)->>'error',
  NULL,
  'create_share_token_v1 NOT_FOUND: error present'
);

-- ============================================================
-- create_share_token_v1 -- CONFLICT (cardinality -- seed 50 tokens)
-- ============================================================
INSERT INTO public.share_tokens (tenant_id, deal_id, token_hash, expires_at)
SELECT
  'a0500000-0000-0000-0000-000000000001'::uuid,
  'a0500000-0000-0000-0000-000000000004'::uuid,
  extensions.digest(gen_random_uuid()::text, 'sha256'),
  now() + interval '1 day'
FROM generate_series(1, 50);

SELECT is(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000004'::uuid, now() + interval '1 day')::json)->>'ok',
  'false',
  'create_share_token_v1 CONFLICT cardinality: ok=false'
);
SELECT is(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000004'::uuid, now() + interval '1 day')::json)->>'code',
  'CONFLICT',
  'create_share_token_v1 CONFLICT cardinality: code=CONFLICT'
);
SELECT is(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000004'::uuid, now() + interval '1 day')::json)->>'data',
  NULL,
  'create_share_token_v1 CONFLICT cardinality: data=null'
);
SELECT isnt(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000004'::uuid, now() + interval '1 day')::json)->>'error',
  NULL,
  'create_share_token_v1 CONFLICT cardinality: error present'
);

-- ============================================================
-- revoke_share_token_v1 -- VALIDATION_ERROR (null token)
-- ============================================================
SELECT is(
  (public.revoke_share_token_v1(NULL)::json)->>'ok',
  'false',
  'revoke_share_token_v1 VALIDATION_ERROR null token: ok=false'
);
SELECT is(
  (public.revoke_share_token_v1(NULL)::json)->>'code',
  'VALIDATION_ERROR',
  'revoke_share_token_v1 VALIDATION_ERROR null token: code=VALIDATION_ERROR'
);
SELECT is(
  (public.revoke_share_token_v1(NULL)::json)->>'data',
  NULL,
  'revoke_share_token_v1 VALIDATION_ERROR null token: data=null'
);
SELECT isnt(
  (public.revoke_share_token_v1(NULL)::json)->>'error',
  NULL,
  'revoke_share_token_v1 VALIDATION_ERROR null token: error present'
);

-- ============================================================
-- lookup_share_token_v1 -- VALIDATION_ERROR (null deal_id)
-- ============================================================
SELECT is(
  (public.lookup_share_token_v1('shr_' || repeat('a', 64), NULL)::json)->>'ok',
  'false',
  'lookup_share_token_v1 VALIDATION_ERROR null deal_id: ok=false'
);
SELECT is(
  (public.lookup_share_token_v1('shr_' || repeat('a', 64), NULL)::json)->>'code',
  'VALIDATION_ERROR',
  'lookup_share_token_v1 VALIDATION_ERROR null deal_id: code=VALIDATION_ERROR'
);
SELECT is(
  (public.lookup_share_token_v1('shr_' || repeat('a', 64), NULL)::json)->>'data',
  NULL,
  'lookup_share_token_v1 VALIDATION_ERROR null deal_id: data=null'
);
SELECT isnt(
  (public.lookup_share_token_v1('shr_' || repeat('a', 64), NULL)::json)->>'error',
  NULL,
  'lookup_share_token_v1 VALIDATION_ERROR null deal_id: error present'
);

-- ============================================================
-- lookup_share_token_v1 -- NOT_FOUND (invalid format -- no existence leak)
-- ============================================================
SELECT is(
  (public.lookup_share_token_v1('bad_token', 'a0500000-0000-0000-0000-000000000004'::uuid)::json)->>'ok',
  'false',
  'lookup_share_token_v1 NOT_FOUND bad format: ok=false'
);
SELECT is(
  (public.lookup_share_token_v1('bad_token', 'a0500000-0000-0000-0000-000000000004'::uuid)::json)->>'code',
  'NOT_FOUND',
  'lookup_share_token_v1 NOT_FOUND bad format: code=NOT_FOUND'
);

-- ============================================================
-- lookup_share_token_v1 -- NOT_FOUND (valid format, nonexistent token)
-- ============================================================
SELECT is(
  (public.lookup_share_token_v1('shr_' || repeat('b', 64), 'a0500000-0000-0000-0000-000000000004'::uuid)::json)->>'ok',
  'false',
  'lookup_share_token_v1 NOT_FOUND nonexistent: ok=false'
);
SELECT is(
  (public.lookup_share_token_v1('shr_' || repeat('b', 64), 'a0500000-0000-0000-0000-000000000004'::uuid)::json)->>'code',
  'NOT_FOUND',
  'lookup_share_token_v1 NOT_FOUND nonexistent: code=NOT_FOUND'
);

-- ============================================================
-- NOT_AUTHORIZED path -- all RPCs (no JWT context)
-- ============================================================
SELECT set_config('request.jwt.claims', '', true);

SELECT is(
  (public.create_deal_v1('a0500000-0000-0000-0000-000000000005'::uuid)::json)->>'code',
  'NOT_AUTHORIZED',
  'create_deal_v1 NOT_AUTHORIZED: code=NOT_AUTHORIZED'
);
SELECT is(
  (public.update_deal_v1('a0500000-0000-0000-0000-000000000004'::uuid, 1)::json)->>'code',
  'NOT_AUTHORIZED',
  'update_deal_v1 NOT_AUTHORIZED: code=NOT_AUTHORIZED'
);
SELECT is(
  (public.create_share_token_v1('a0500000-0000-0000-0000-000000000004'::uuid, now() + interval '1 day')::json)->>'code',
  'NOT_AUTHORIZED',
  'create_share_token_v1 NOT_AUTHORIZED: code=NOT_AUTHORIZED'
);
SELECT is(
  (public.revoke_share_token_v1('shr_' || repeat('a', 64))::json)->>'code',
  'NOT_AUTHORIZED',
  'revoke_share_token_v1 NOT_AUTHORIZED: code=NOT_AUTHORIZED'
);
SELECT is(
  (public.lookup_share_token_v1('shr_' || repeat('a', 64), 'a0500000-0000-0000-0000-000000000004'::uuid)::json)->>'code',
  'NOT_AUTHORIZED',
  'lookup_share_token_v1 NOT_AUTHORIZED: code=NOT_AUTHORIZED'
);

SELECT * FROM finish();
ROLLBACK;