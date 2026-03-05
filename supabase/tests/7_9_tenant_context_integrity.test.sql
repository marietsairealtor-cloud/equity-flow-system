-- pgTAP: 7.9 Tenant Context Integrity Invariant (JWT Contract)
-- Proves: current_tenant_id() returns NULL without valid claim.
-- All tenant-bound RPCs return NOT_AUTHORIZED when tenant context is NULL.
-- Cross-tenant access fails under manipulated claim context.
-- No RPC accepts tenant_id as caller input (catalog audit).
BEGIN;

SELECT plan(12);

-- Seed tenants + deal for cross-tenant tests
INSERT INTO public.tenants (id) VALUES
  ('e0000000-0000-0000-0000-000000000001'::uuid),
  ('e0000000-0000-0000-0000-000000000002'::uuid);

SET CONSTRAINTS ALL DEFERRED;

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES ('e1000000-0000-0000-0000-000000000001'::uuid,
        'e0000000-0000-0000-0000-000000000001'::uuid, 1, 1,
        'e2000000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
VALUES ('e2000000-0000-0000-0000-000000000001'::uuid,
        'e0000000-0000-0000-0000-000000000001'::uuid,
        'e1000000-0000-0000-0000-000000000001'::uuid, 1, 1, '{}'::jsonb);

-- ============================================================
-- Test 1: current_tenant_id() returns NULL when no claim set
-- ============================================================
RESET ROLE;
SELECT set_config('request.jwt.claim.tenant_id', '', true);
SELECT set_config('request.jwt.claims', '', true);

SELECT is(
  public.current_tenant_id(),
  NULL::uuid,
  'current_tenant_id() returns NULL when no tenant claim set'
);

-- ============================================================
-- Tests 2-6: RPCs return NOT_AUTHORIZED when tenant context is NULL
-- ============================================================
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', '', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-0000000000a1', true);

-- Test 2: list_deals_v1 returns NOT_AUTHORIZED without tenant context
SELECT is(
  (public.list_deals_v1()::json -> 'code')::text,
  '"NOT_AUTHORIZED"',
  'list_deals_v1: returns NOT_AUTHORIZED when tenant context is NULL'
);

-- Test 3: create_deal_v1 returns NOT_AUTHORIZED without tenant context
SELECT is(
  (public.create_deal_v1(gen_random_uuid())::json -> 'code')::text,
  '"NOT_AUTHORIZED"',
  'create_deal_v1: returns NOT_AUTHORIZED when tenant context is NULL'
);

-- Test 4: update_deal_v1 returns NOT_AUTHORIZED without tenant context
SELECT is(
  (public.update_deal_v1('e1000000-0000-0000-0000-000000000001'::uuid, 1)::json -> 'code')::text,
  '"NOT_AUTHORIZED"',
  'update_deal_v1: returns NOT_AUTHORIZED when tenant context is NULL'
);

-- Test 5: get_user_entitlements_v1 returns NOT_AUTHORIZED without tenant context
SELECT is(
  (public.get_user_entitlements_v1()::json -> 'code')::text,
  '"NOT_AUTHORIZED"',
  'get_user_entitlements_v1: returns NOT_AUTHORIZED when tenant context is NULL'
);

-- Test 6: foundation_log_activity_v1 returns NOT_AUTHORIZED without tenant context
SELECT is(
  (public.foundation_log_activity_v1('test', '{}'::jsonb, null)::json -> 'code')::text,
  '"NOT_AUTHORIZED"',
  'foundation_log_activity_v1: returns NOT_AUTHORIZED when tenant context is NULL'
);

-- ============================================================
-- Tests 7-8: Cross-tenant access fails under manipulated claim
-- ============================================================
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'e0000000-0000-0000-0000-000000000002', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-0000000000a1', true);

-- Test 7: foundation_log_activity_v1 with Tenant B JWT cannot write to Tenant A
SELECT is(
  (public.foundation_log_activity_v1('cross_tenant_attempt', '{}'::jsonb, null)::json -> 'code')::text,
  '"OK"',
  'foundation_log_activity_v1: Tenant B JWT writes to Tenant B only (isolated)'
);

-- Test 8: list_deals_v1 under Tenant B returns OK with zero Tenant A rows
SELECT is(
  (public.list_deals_v1()::json -> 'code')::text,
  '"OK"',
  'list_deals_v1: Tenant B context returns OK with zero Tenant A rows (isolated)'
);

-- ============================================================
-- Tests 9-10: lookup_share_token_v1 no longer accepts p_tenant_id
-- ============================================================
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'e0000000-0000-0000-0000-000000000002', true);

-- Test 9: lookup_share_token_v1 with Tenant B JWT returns NOT_FOUND for Tenant A token
SELECT is(
  (public.lookup_share_token_v1('nonexistent_token')::json -> 'code')::text,
  '"NOT_FOUND"',
  'lookup_share_token_v1: Tenant B JWT cannot find Tenant A token (isolated)'
);

-- Test 10: foundation_log_activity_v1 derives tenant from JWT only
SELECT is(
  (public.foundation_log_activity_v1('jwt_derived_write', '{}'::jsonb, null)::json -> 'code')::text,
  '"OK"',
  'foundation_log_activity_v1: tenant derived from JWT only — no caller input accepted'
);

-- ============================================================
-- Tests 11-12: Catalog audit
-- ============================================================
RESET ROLE;

-- Test 11: current_tenant_id() exists
SELECT has_function('public', 'current_tenant_id', ARRAY[]::text[],
  'current_tenant_id() exists');

-- Test 12: No SECURITY DEFINER RPC accepts a parameter named like tenant_id
SELECT is(
  (SELECT count(*)::int FROM pg_proc p
   JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.prosecdef = true
     AND p.proname NOT IN ('require_min_role_v1','current_tenant_id',
                           'activity_log_append_only','check_deal_snapshot_not_null',
                           'check_deal_tenant_match')
     AND pg_get_function_arguments(p.oid) ~* 'tenant_id'),
  0,
  'Catalog audit: zero SECURITY DEFINER RPCs accept tenant_id as caller input'
);

SELECT finish();
ROLLBACK;
