-- pgTAP: 7.5 RLS negative suite for product tables
-- Proves: cross-tenant read/write attempts fail on all product tables.
-- Direct table access blocked by privilege firewall + RLS.
BEGIN;
SELECT plan(12);

-- Seed data as superuser
INSERT INTO public.tenants (id) VALUES
  ('c0000000-0000-0000-0000-000000000001'::uuid),
  ('c0000000-0000-0000-0000-000000000002'::uuid);

SET CONSTRAINTS ALL DEFERRED;

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES ('c2000000-0000-0000-0000-000000000001'::uuid, 'c0000000-0000-0000-0000-000000000001'::uuid, 1, 1,
        'c1000000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
VALUES ('c1000000-0000-0000-0000-000000000001'::uuid, 'c0000000-0000-0000-0000-000000000001'::uuid,
        'c2000000-0000-0000-0000-000000000001'::uuid, 1, 1, '{"test": true}'::jsonb);

INSERT INTO public.deal_outputs (id, tenant_id, deal_id, calc_version, row_version, outputs)
VALUES ('c3000000-0000-0000-0000-000000000001'::uuid, 'c0000000-0000-0000-0000-000000000001'::uuid,
        'c2000000-0000-0000-0000-000000000001'::uuid, 1, 1, '{"result": 42}'::jsonb);

INSERT INTO public.activity_log (id, tenant_id, actor_id, action, meta)
VALUES ('c4000000-0000-0000-0000-000000000001'::uuid, 'c0000000-0000-0000-0000-000000000001'::uuid,
        null, 'test_seed', '{}'::jsonb);

-- ============================================================
-- Tenant A context: own-tenant access via privilege firewall
-- ============================================================
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'c0000000-0000-0000-0000-000000000001', true);

-- Test 1-3: Direct SELECT on product tables blocked (privilege firewall)
SELECT throws_ok(
  $tap$SELECT * FROM public.deal_inputs LIMIT 1$tap$,
  '42501',
  NULL,
  'deal_inputs: direct SELECT blocked for authenticated (privilege firewall)'
);

SELECT throws_ok(
  $tap$SELECT * FROM public.deal_outputs LIMIT 1$tap$,
  '42501',
  NULL,
  'deal_outputs: direct SELECT blocked for authenticated (privilege firewall)'
);

SELECT throws_ok(
  $tap$SELECT * FROM public.activity_log LIMIT 1$tap$,
  '42501',
  NULL,
  'activity_log: direct SELECT blocked for authenticated (privilege firewall)'
);

-- Test 4-6: Direct INSERT on product tables blocked
SELECT throws_ok(
  $tap$INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
  VALUES ('c1000000-0000-0000-0000-000000000099'::uuid, 'c0000000-0000-0000-0000-000000000001'::uuid,
          'c2000000-0000-0000-0000-000000000001'::uuid, 1, 1, '{}'::jsonb)$tap$,
  '42501',
  NULL,
  'deal_inputs: direct INSERT blocked for authenticated (privilege firewall)'
);

SELECT throws_ok(
  $tap$INSERT INTO public.deal_outputs (id, tenant_id, deal_id, calc_version, row_version, outputs)
  VALUES ('c3000000-0000-0000-0000-000000000099'::uuid, 'c0000000-0000-0000-0000-000000000001'::uuid,
          'c2000000-0000-0000-0000-000000000001'::uuid, 1, 1, '{}'::jsonb)$tap$,
  '42501',
  NULL,
  'deal_outputs: direct INSERT blocked for authenticated (privilege firewall)'
);

SELECT throws_ok(
  $tap$INSERT INTO public.activity_log (id, tenant_id, actor_id, action, meta)
  VALUES ('c4000000-0000-0000-0000-000000000099'::uuid, 'c0000000-0000-0000-0000-000000000001'::uuid,
          null, 'test_inject', '{}'::jsonb)$tap$,
  '42501',
  NULL,
  'activity_log: direct INSERT blocked for authenticated (privilege firewall)'
);

-- ============================================================
-- Cross-tenant context: Tenant B cannot see Tenant A data
-- ============================================================
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'c0000000-0000-0000-0000-000000000002', true);

-- Test 7-9: Cross-tenant direct SELECT blocked (same privilege firewall)
SELECT throws_ok(
  $tap$SELECT * FROM public.deal_inputs LIMIT 1$tap$,
  '42501',
  NULL,
  'deal_inputs: cross-tenant SELECT blocked (privilege firewall)'
);

SELECT throws_ok(
  $tap$SELECT * FROM public.deal_outputs LIMIT 1$tap$,
  '42501',
  NULL,
  'deal_outputs: cross-tenant SELECT blocked (privilege firewall)'
);

SELECT throws_ok(
  $tap$SELECT * FROM public.activity_log LIMIT 1$tap$,
  '42501',
  NULL,
  'activity_log: cross-tenant SELECT blocked (privilege firewall)'
);

-- ============================================================
-- Activity log RPC: cross-tenant write blocked
-- ============================================================

-- Test 10: Tenant B cannot write to Tenant A activity log via RPC
SELECT is(
  (public.foundation_log_activity_v1(
    'c0000000-0000-0000-0000-000000000001'::uuid,
    'cross_tenant_attempt',
    '{}'::jsonb,
    null
  )::json ->> 'code'),
  'NOT_AUTHORIZED',
  'activity_log RPC: cross-tenant write returns NOT_AUTHORIZED'
);

-- ============================================================
-- Share-link cannot bypass tenant boundaries (reference test)
-- ============================================================

-- Test 11: Share token lookup with wrong tenant returns NOT_AUTHORIZED
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'c0000000-0000-0000-0000-000000000002', true);

-- Seed a share token for Tenant A
RESET ROLE;
INSERT INTO public.share_tokens (id, tenant_id, deal_id, token, expires_at)
VALUES ('c5000000-0000-0000-0000-000000000001'::uuid, 'c0000000-0000-0000-0000-000000000001'::uuid,
        'c2000000-0000-0000-0000-000000000001'::uuid, 'cross_tenant_token_75', NULL);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.tenant_id', 'c0000000-0000-0000-0000-000000000002', true);

SELECT is(
  (public.lookup_share_token_v1(
    'c0000000-0000-0000-0000-000000000001'::uuid,
    'cross_tenant_token_75'
  )::json ->> 'code'),
  'NOT_AUTHORIZED',
  'share-link: cross-tenant token lookup returns NOT_AUTHORIZED'
);

-- ============================================================
-- Anon role: zero access
-- ============================================================
RESET ROLE;
SET ROLE anon;

-- Test 12: Anon cannot access any product table
SELECT throws_ok(
  $tap$SELECT * FROM public.deals LIMIT 1$tap$,
  '42501',
  NULL,
  'anon: zero access to deals (privilege firewall)'
);

SELECT finish();
ROLLBACK;






