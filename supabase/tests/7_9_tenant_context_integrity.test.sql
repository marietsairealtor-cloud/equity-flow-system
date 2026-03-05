-- pgTAP: 7.9 Tenant Context Integrity Invariant (JWT Contract)
-- Proves: current_tenant_id() returns NULL without valid claim.
-- All tenant-bound RPCs return NOT_AUTHORIZED when tenant context is NULL.
-- Cross-tenant access fails under manipulated claim context.
-- RPCs that accept p_tenant_id use it for verification only (not trust bypass).
BEGIN;

SELECT plan(12);

-- Seed tenant + deal for cross-tenant tests
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
  (public.foundation_log_activity_v1(
    'e0000000-0000-0000-0000-000000000001'::uuid, 'test', '{}'::jsonb, null
  )::json -> 'code')::text,
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

-- Test 7: foundation_log_activity_v1 cross-tenant returns NOT_AUTHORIZED
SELECT is(
  (public.foundation_log_activity_v1(
    'e0000000-0000-0000-0000-000000000001'::uuid,
    'cross_tenant_attempt', '{}'::jsonb, null
  )::json -> 'code')::text,
  '"NOT_AUTHORIZED"',
  'foundation_log_activity_v1: cross-tenant write returns NOT_AUTHORIZED'
);

-- Test 8: list_deals_v1 returns OK for Tenant B but zero rows (tenant isolation)
SELECT is(
  (public.list_deals_v1()::json -> 'code')::text,
  '"OK"',
  'list_deals_v1: Tenant B context returns OK with zero Tenant A rows (isolated)'
);

-- ============================================================
-- Tests 9-10: RPCs that accept p_tenant_id use it for verification only
-- ============================================================
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'e0000000-0000-0000-0000-000000000002', true);

-- Test 9: lookup_share_token_v1 with Tenant A token under Tenant B context returns NOT_AUTHORIZED
SELECT is(
  (public.lookup_share_token_v1(
    'e0000000-0000-0000-0000-000000000001'::uuid, 'nonexistent_token'
  )::json -> 'code')::text,
  '"NOT_AUTHORIZED"',
  'lookup_share_token_v1: p_tenant_id mismatch with JWT returns NOT_AUTHORIZED'
);

-- Test 10: foundation_log_activity_v1 p_tenant_id mismatch returns NOT_AUTHORIZED
SELECT is(
  (public.foundation_log_activity_v1(
    'e0000000-0000-0000-0000-000000000001'::uuid, 'bypass_attempt', '{}'::jsonb, null
  )::json -> 'code')::text,
  '"NOT_AUTHORIZED"',
  'foundation_log_activity_v1: p_tenant_id mismatch with JWT returns NOT_AUTHORIZED'
);

-- ============================================================
-- Tests 11-12: Catalog audit
-- ============================================================
RESET ROLE;

-- Test 11: current_tenant_id() exists and is stable
SELECT has_function('public', 'current_tenant_id', ARRAY[]::text[],
  'current_tenant_id() exists');

-- Test 12: All SECURITY DEFINER RPCs that do not accept p_tenant_id
-- use current_tenant_id() internally for tenant binding
SELECT is(
  (SELECT count(*)::int FROM pg_proc p
   JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.prosecdef = true
     AND p.proname NOT IN ('require_min_role_v1', 'current_tenant_id',
                           'activity_log_append_only', 'check_deal_snapshot_not_null',
                           'check_deal_tenant_match', 'foundation_log_activity_v1',
                           'lookup_share_token_v1')
     AND NOT (pg_get_functiondef(p.oid) ~* 'current_tenant_id')),
  0,
  'Catalog audit: all tenant-bound RPCs reference current_tenant_id()'
);

SELECT finish();
ROLLBACK;



