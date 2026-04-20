-- 10.8.4: Deal health computation tests
-- All behavioral tests call list_deals_v1 RPC only (GUARDRAILS s29G).
BEGIN;

SELECT plan(7);

-- Seed tenant + membership + deal for auth context tests
INSERT INTO public.tenants (id) VALUES
  ('c0000000-0000-0000-0000-000000000001'::uuid)
  ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role) VALUES
  ('c8000000-0000-0000-0000-000000000001'::uuid,
   'c0000000-0000-0000-0000-000000000001'::uuid,
   'c9000000-0000-0000-0000-000000000001'::uuid,
   'owner')
  ON CONFLICT DO NOTHING;

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, updated_at) VALUES
  ('c2000000-0000-0000-0000-000000000001'::uuid,
   'c0000000-0000-0000-0000-000000000001'::uuid,
   1, 1, 'new', now() - INTERVAL '4 days')
  ON CONFLICT DO NOTHING;

-- 1. list_deals_v1 function exists with new signature
SELECT has_function(
  'public', 'list_deals_v1',
  ARRAY['integer','text'],
  '10.8.4: list_deals_v1(integer,text) exists'
);

-- 2. get_deal_health_color function exists
SELECT has_function(
  'public', 'get_deal_health_color',
  ARRAY['text','timestamp with time zone'],
  '10.8.4: get_deal_health_color function exists'
);

-- Set auth context for RPC tests
SET ROLE authenticated;
SET request.jwt.claim.sub = 'c9000000-0000-0000-0000-000000000001';
SET request.jwt.claim.tenant_id = 'c0000000-0000-0000-0000-000000000001';

-- 3. list_deals_v1 returns ok=true for authorized tenant
SELECT is(
  public.list_deals_v1()::json->>'code',
  'OK',
  '10.8.4: list_deals_v1 returns code=OK'
);

-- 4. list_deals_v1 returns items array (never null)
SELECT ok(
  json_typeof(public.list_deals_v1()::json->'data'->'items') = 'array',
  '10.8.4: list_deals_v1 data.items is always an array'
);

-- 5. list_deals_v1 items contain health_color field
SELECT ok(
  (
    SELECT (elem->>'health_color') IS NOT NULL
    FROM json_array_elements(public.list_deals_v1()::json->'data'->'items') AS elem
    LIMIT 1
  ) IS NOT DISTINCT FROM true,
  '10.8.4: list_deals_v1 items contain health_color field'
);

-- 6. Deal updated 4 days ago with stage=New returns red (threshold=3d)
SELECT is(
  (
    SELECT elem->>'health_color'
    FROM json_array_elements(public.list_deals_v1()::json->'data'->'items') AS elem
    WHERE elem->>'id' = 'c2000000-0000-0000-0000-000000000001'
    LIMIT 1
  ),
  'red',
  '10.8.4: New stage deal 4d old = red health_color'
);

RESET ROLE;
RESET request.jwt.claim.sub;
RESET request.jwt.claim.tenant_id;

-- 7. authenticated role cannot execute helper directly
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM information_schema.routine_privileges
    WHERE routine_schema = 'public'
    AND routine_name = 'get_deal_health_color'
    AND grantee = 'authenticated'
    AND privilege_type = 'EXECUTE'
  ),
  '10.8.4: authenticated cannot execute get_deal_health_color directly'
);

SELECT finish();
ROLLBACK;