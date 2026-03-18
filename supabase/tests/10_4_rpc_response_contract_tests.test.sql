-- 10_4_rpc_response_contract_tests.test.sql
-- Build Route 10.4: RPC Response Contract Tests
-- Verifies list_deals_v1 and get_user_entitlements_v1 response shapes
-- match governed schemas in docs/truth/rpc_schemas/.
-- Tests run as superuser with JWT claims set to simulate calling context.

BEGIN;
SELECT plan(27);

-- Seed test tenant and user
INSERT INTO public.tenants (id)
  VALUES ('a0400000-0000-0000-0000-000000000001'::uuid);

INSERT INTO auth.users (id, email)
  VALUES ('a0400000-0000-0000-0000-000000000002'::uuid, 'contract_test_user@10_4.test');

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES (
    'a0400000-0000-0000-0000-000000000003'::uuid,
    'a0400000-0000-0000-0000-000000000001'::uuid,
    'a0400000-0000-0000-0000-000000000002'::uuid,
    'member'
  );

-- ============================================================
-- list_deals_v1 -- NOT_AUTHORIZED path (no JWT context)
-- ============================================================
SELECT set_config('request.jwt.claims', '', true);

SELECT is(
  (public.list_deals_v1()::json)->>'ok',
  'false',
  'list_deals_v1 NOT_AUTHORIZED: ok=false'
);

SELECT is(
  (public.list_deals_v1()::json)->>'code',
  'NOT_AUTHORIZED',
  'list_deals_v1 NOT_AUTHORIZED: code=NOT_AUTHORIZED'
);

SELECT is(
  (public.list_deals_v1()::json)->>'data',
  NULL,
  'list_deals_v1 NOT_AUTHORIZED: data=null'
);

SELECT isnt(
  (public.list_deals_v1()::json)->>'error',
  NULL,
  'list_deals_v1 NOT_AUTHORIZED: error is not null'
);

SELECT isnt(
  (public.list_deals_v1()::json)->'error'->>'message',
  NULL,
  'list_deals_v1 NOT_AUTHORIZED: error.message present'
);

SELECT isnt(
  (public.list_deals_v1()::json)->'error'->>'fields',
  NULL,
  'list_deals_v1 NOT_AUTHORIZED: error.fields present'
);

-- ============================================================
-- list_deals_v1 -- OK path (authenticated tenant context)
-- ============================================================
SELECT set_config('request.jwt.claims',
  '{"sub":"a0400000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"a0400000-0000-0000-0000-000000000001"}',
  true);

SELECT is(
  (public.list_deals_v1()::json)->>'ok',
  'true',
  'list_deals_v1 OK: ok=true'
);

SELECT is(
  (public.list_deals_v1()::json)->>'code',
  'OK',
  'list_deals_v1 OK: code=OK'
);

SELECT is(
  (public.list_deals_v1()::json)->>'error',
  NULL,
  'list_deals_v1 OK: error=null'
);

SELECT isnt(
  (public.list_deals_v1()::json)->'data'->>'items',
  NULL,
  'list_deals_v1 OK: data.items present'
);

SELECT is(
  json_typeof((public.list_deals_v1()::json)->'data'->'items'),
  'array',
  'list_deals_v1 OK: data.items is array'
);

SELECT is(
  (public.list_deals_v1()::json)->'data'->>'next_cursor',
  NULL,
  'list_deals_v1 OK: data.next_cursor=null'
);

-- ============================================================
-- get_user_entitlements_v1 -- NOT_AUTHORIZED path
-- ============================================================
SELECT set_config('request.jwt.claims', '', true);

SELECT is(
  (public.get_user_entitlements_v1()::json)->>'ok',
  'false',
  'get_user_entitlements_v1 NOT_AUTHORIZED: ok=false'
);

SELECT is(
  (public.get_user_entitlements_v1()::json)->>'code',
  'NOT_AUTHORIZED',
  'get_user_entitlements_v1 NOT_AUTHORIZED: code=NOT_AUTHORIZED'
);

SELECT is(
  (public.get_user_entitlements_v1()::json)->>'data',
  NULL,
  'get_user_entitlements_v1 NOT_AUTHORIZED: data=null'
);

SELECT isnt(
  (public.get_user_entitlements_v1()::json)->>'error',
  NULL,
  'get_user_entitlements_v1 NOT_AUTHORIZED: error is not null'
);

SELECT isnt(
  (public.get_user_entitlements_v1()::json)->'error'->>'message',
  NULL,
  'get_user_entitlements_v1 NOT_AUTHORIZED: error.message present'
);

SELECT isnt(
  (public.get_user_entitlements_v1()::json)->'error'->>'fields',
  NULL,
  'get_user_entitlements_v1 NOT_AUTHORIZED: error.fields present'
);

-- ============================================================
-- get_user_entitlements_v1 -- OK path
-- ============================================================
SELECT set_config('request.jwt.claims',
  '{"sub":"a0400000-0000-0000-0000-000000000002","role":"authenticated","tenant_id":"a0400000-0000-0000-0000-000000000001"}',
  true);

SELECT is(
  (public.get_user_entitlements_v1()::json)->>'ok',
  'true',
  'get_user_entitlements_v1 OK: ok=true'
);

SELECT is(
  (public.get_user_entitlements_v1()::json)->>'code',
  'OK',
  'get_user_entitlements_v1 OK: code=OK'
);

SELECT is(
  (public.get_user_entitlements_v1()::json)->>'error',
  NULL,
  'get_user_entitlements_v1 OK: error=null'
);

SELECT isnt(
  (public.get_user_entitlements_v1()::json)->'data'->>'tenant_id',
  NULL,
  'get_user_entitlements_v1 OK: data.tenant_id present'
);

SELECT isnt(
  (public.get_user_entitlements_v1()::json)->'data'->>'user_id',
  NULL,
  'get_user_entitlements_v1 OK: data.user_id present'
);

SELECT isnt(
  (public.get_user_entitlements_v1()::json)->'data'->>'is_member',
  NULL,
  'get_user_entitlements_v1 OK: data.is_member present'
);

SELECT isnt(
  (public.get_user_entitlements_v1()::json)->'data'->>'entitled',
  NULL,
  'get_user_entitlements_v1 OK: data.entitled present'
);

SELECT isnt(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_status',
  NULL,
  'get_user_entitlements_v1 OK: data.subscription_status present'
);

SELECT is(
  (public.get_user_entitlements_v1()::json)->'data'->>'subscription_status',
  'none',
  'get_user_entitlements_v1 OK: data.subscription_status=none (no subscription seeded)'
);

SELECT * FROM finish();
ROLLBACK;