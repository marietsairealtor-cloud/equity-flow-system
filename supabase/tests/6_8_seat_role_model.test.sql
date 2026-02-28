-- pgTAP: 6.8 Seat + role model
BEGIN;
SELECT plan(10);

-- 1) tenant_role enum exists
SELECT has_type('public', 'tenant_role', 'tenant_role enum exists');

-- 2) tenant_role has exactly 3 values
SELECT results_eq(
  $tap$SELECT unnest(enum_range(NULL::public.tenant_role))::text ORDER BY 1$tap$,
  ARRAY['admin', 'member', 'owner'],
  'tenant_role enum has exactly admin, member, owner'
);

-- 3) tenant_memberships has required columns
SELECT has_column('public', 'tenant_memberships', 'tenant_id', 'tenant_memberships has tenant_id');
SELECT has_column('public', 'tenant_memberships', 'user_id', 'tenant_memberships has user_id');
SELECT has_column('public', 'tenant_memberships', 'role', 'tenant_memberships has role');

-- 4) Unique constraint on (tenant_id, user_id)
SELECT index_is_unique('public', 'tenant_memberships', 'tenant_memberships_tenant_user_unique',
  'unique constraint on (tenant_id, user_id)');

-- 5) RLS enabled on tenant_memberships
SELECT results_eq(
  $tap$SELECT relrowsecurity FROM pg_class WHERE oid = 'public.tenant_memberships'::regclass$tap$,
  ARRAY[true],
  'RLS enabled on tenant_memberships'
);

-- 6) RLS policies exist
SELECT policies_are('public', 'tenant_memberships',
  ARRAY[
    'tenant_memberships_select_own',
    'tenant_memberships_insert_own',
    'tenant_memberships_update_own',
    'tenant_memberships_delete_own'
  ],
  'All 4 tenant-isolation policies exist on tenant_memberships'
);

-- 7) No direct GRANTs to anon on tenant_memberships
SELECT is_empty(
  $tap$SELECT grantee FROM information_schema.role_table_grants
   WHERE table_schema = 'public'
     AND table_name = 'tenant_memberships'
     AND grantee = 'anon'$tap$,
  'No GRANTs to anon on tenant_memberships'
);

-- 8) No direct GRANTs to authenticated on tenant_memberships
SELECT is_empty(
  $tap$SELECT grantee FROM information_schema.role_table_grants
   WHERE table_schema = 'public'
     AND table_name = 'tenant_memberships'
     AND grantee = 'authenticated'$tap$,
  'No GRANTs to authenticated on tenant_memberships'
);

SELECT finish();
ROLLBACK;
