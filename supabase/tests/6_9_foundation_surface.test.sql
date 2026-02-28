-- pgTAP: 6.9 Foundation Surface Ready — activity log
BEGIN;
SELECT plan(8);

-- 1) activity_log table exists
SELECT has_table('public', 'activity_log', 'activity_log table exists');

-- 2) Required columns
SELECT has_column('public', 'activity_log', 'tenant_id', 'activity_log has tenant_id');
SELECT has_column('public', 'activity_log', 'actor_id', 'activity_log has actor_id');
SELECT has_column('public', 'activity_log', 'action', 'activity_log has action');
SELECT has_column('public', 'activity_log', 'meta', 'activity_log has meta');

-- 3) RLS enabled
SELECT results_eq(
  $tap$SELECT relrowsecurity FROM pg_class WHERE oid = 'public.activity_log'::regclass$tap$,
  ARRAY[true],
  'RLS enabled on activity_log'
);

-- 4) No direct GRANTs to anon/authenticated on table
SELECT is_empty(
  $tap$SELECT grantee FROM information_schema.role_table_grants
   WHERE table_schema = 'public'
     AND table_name = 'activity_log'
     AND grantee IN ('anon', 'authenticated')$tap$,
  'No table GRANTs to anon/authenticated on activity_log'
);

-- 5) RPC exists and is executable
SELECT has_function('public', 'foundation_log_activity_v1',
  ARRAY['uuid', 'text', 'jsonb', 'uuid'],
  'foundation_log_activity_v1 RPC exists'
);

SELECT finish();
ROLLBACK;
