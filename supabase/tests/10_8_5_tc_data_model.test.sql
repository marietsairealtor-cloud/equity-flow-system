-- 10.8.5: TC Checklist Data Model tests
BEGIN;

SELECT plan(12);

-- 1. deal_tc table exists
SELECT has_table('public', 'deal_tc', '10.8.5: deal_tc table exists');

-- 2. deal_tc_checklist table exists
SELECT has_table('public', 'deal_tc_checklist', '10.8.5: deal_tc_checklist table exists');

-- 3. deal_tc has row_version
SELECT has_column('public', 'deal_tc', 'row_version', '10.8.5: deal_tc has row_version');

-- 4. deal_tc_checklist has row_version
SELECT has_column('public', 'deal_tc_checklist', 'row_version', '10.8.5: deal_tc_checklist has row_version');

-- 5. deal_tc_checklist unique constraint on (deal_id, item_key)
SELECT ok(
  EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_schema = 'public'
    AND table_name = 'deal_tc_checklist'
    AND constraint_type = 'UNIQUE'
    AND constraint_name = 'deal_tc_checklist_deal_item_key'
  ),
  '10.8.5: deal_tc_checklist has unique constraint on (deal_id, item_key)'
);

-- Seed all data as superuser before SET ROLE
INSERT INTO public.tenants (id) VALUES
  ('d0000000-0000-0000-0000-000000000001'::uuid)
  ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role) VALUES
  ('d8000000-0000-0000-0000-000000000001'::uuid,
   'd0000000-0000-0000-0000-000000000001'::uuid,
   'd9000000-0000-0000-0000-000000000001'::uuid,
   'owner')
  ON CONFLICT DO NOTHING;

-- Active deal
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage) VALUES
  ('d2000000-0000-0000-0000-000000000001'::uuid,
   'd0000000-0000-0000-0000-000000000001'::uuid,
   1, 1, 'New')
  ON CONFLICT DO NOTHING;

-- Terminal deal
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage) VALUES
  ('d2000000-0000-0000-0000-000000000002'::uuid,
   'd0000000-0000-0000-0000-000000000001'::uuid,
   1, 1, 'Closed / Dead')
  ON CONFLICT DO NOTHING;

-- Checklist items for progress test (superuser context)
INSERT INTO public.deal_tc_checklist
  (id, deal_id, tenant_id, item_key, completed_at) VALUES
  ('d3000000-0000-0000-0000-000000000001'::uuid,
   'd2000000-0000-0000-0000-000000000001'::uuid,
   'd0000000-0000-0000-0000-000000000001'::uuid,
   'aps_signed', now()),
  ('d3000000-0000-0000-0000-000000000002'::uuid,
   'd2000000-0000-0000-0000-000000000001'::uuid,
   'd0000000-0000-0000-0000-000000000001'::uuid,
   'deposit_received', null)
  ON CONFLICT DO NOTHING;

-- TC record for days-to-close test (superuser context)
INSERT INTO public.deal_tc
  (id, deal_id, tenant_id, closing_date) VALUES
  ('d4000000-0000-0000-0000-000000000001'::uuid,
   'd2000000-0000-0000-0000-000000000001'::uuid,
   'd0000000-0000-0000-0000-000000000001'::uuid,
   now() + INTERVAL '10 days')
  ON CONFLICT DO NOTHING;

SET ROLE authenticated;
SET request.jwt.claim.sub = 'd9000000-0000-0000-0000-000000000001';
SET request.jwt.claim.tenant_id = 'd0000000-0000-0000-0000-000000000001';

-- 6. update_deal_v1 succeeds on non-terminal deal
SELECT is(
  public.update_deal_v1('d2000000-0000-0000-0000-000000000001'::uuid, 1)::json->>'code',
  'OK',
  '10.8.5: update_deal_v1 succeeds on non-terminal deal'
);

-- 7. update_deal_v1 rejects write to terminal deal
SELECT is(
  public.update_deal_v1('d2000000-0000-0000-0000-000000000002'::uuid, 1)::json->>'code',
  'DEAL_IMMUTABLE',
  '10.8.5: update_deal_v1 rejects write to Closed/Dead deal'
);

-- 8. Progress derivable: 1 of 2 items completed
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_tc_checklist
   WHERE deal_id = 'd2000000-0000-0000-0000-000000000001'::uuid
   AND completed_at IS NOT NULL),
  1,
  '10.8.5: progress derivable - 1 of 2 items completed'
);

-- 9. Days to close derivable from closing_date
SELECT ok(
  (SELECT (closing_date - now()) > INTERVAL '9 days'
   FROM public.deal_tc
   WHERE deal_id = 'd2000000-0000-0000-0000-000000000001'::uuid),
  '10.8.5: days to close derivable from closing_date'
);

-- 10. RLS: deal_tc tenant isolation
SET request.jwt.claim.tenant_id = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_tc),
  0,
  '10.8.5: deal_tc RLS - other tenant sees zero rows'
);

-- 11. RLS: deal_tc_checklist tenant isolation
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_tc_checklist),
  0,
  '10.8.5: deal_tc_checklist RLS - other tenant sees zero rows'
);

RESET ROLE;
RESET request.jwt.claim.sub;
RESET request.jwt.claim.tenant_id;

-- 12. update_deal_v1 function exists with hardened signature
SELECT has_function(
  'public', 'update_deal_v1',
  ARRAY['uuid','bigint','integer'],
  '10.8.5: update_deal_v1(uuid,bigint,integer) exists'
);

SELECT finish();
ROLLBACK;