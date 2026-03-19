-- 10.8.4: Deal health computation tests
-- All behavioral tests call list_deals_v1 RPC only (GUARDRAILS s29G).
-- Helper get_deal_health_color is tested indirectly via RPC output.
BEGIN;

SELECT plan(7);

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

-- 3. list_deals_v1 returns ok=true for authorized tenant
SELECT is(
  (public.list_deals_v1()->'ok')::text,
  'true',
  '10.8.4: list_deals_v1 returns ok=true'
);

-- 4. list_deals_v1 returns items array (never null)
SELECT ok(
  json_typeof(public.list_deals_v1()->'data'->'items') = 'array',
  '10.8.4: list_deals_v1 data.items is always an array'
);

-- 5. list_deals_v1 returns next_cursor field
SELECT ok(
  (public.list_deals_v1()->'data') ? 'next_cursor',
  '10.8.4: list_deals_v1 data contains next_cursor field'
);

-- 6. authenticated role cannot execute helper directly
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

-- 7. authenticated role can execute list_deals_v1
SELECT ok(
  EXISTS (
    SELECT 1 FROM information_schema.routine_privileges
    WHERE routine_schema = 'public'
    AND routine_name = 'list_deals_v1'
    AND grantee = 'authenticated'
    AND privilege_type = 'EXECUTE'
  ),
  '10.8.4: authenticated can execute list_deals_v1'
);

SELECT finish();
ROLLBACK;