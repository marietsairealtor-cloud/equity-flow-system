-- 10.11A10: Activity Log Expansion tests
BEGIN;

SELECT plan(17);

-- Seed tenant one: owner
SELECT public.create_active_workspace_seed_v1(
  'b1200000-0000-0000-0000-000000000001'::uuid,
  'a1200000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

-- Seed tenant two: cross-tenant isolation
SELECT public.create_active_workspace_seed_v1(
  'b1200000-0000-0000-0000-000000000002'::uuid,
  'a1200000-0000-0000-0000-000000000002'::uuid,
  'owner'
);

-- Seed deal for tenant one
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1200000-0000-0000-0000-000000000001',
  'b1200000-0000-0000-0000-000000000001',
  1, 1, 'new', '123 Activity St', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e1200000-0000-0000-0000-000000000001',
  'b1200000-0000-0000-0000-000000000001',
  'd1200000-0000-0000-0000-000000000001',
  1,
  '{"arv":300000,"ask_price":200000,"repair_estimate":30000,"assignment_fee":15000,"multiplier":0.70}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e1200000-0000-0000-0000-000000000001'
WHERE id = 'd1200000-0000-0000-0000-000000000001';

-- Seed reminder for tenant one
INSERT INTO public.deal_reminders (id, tenant_id, deal_id, reminder_date, reminder_type)
VALUES (
  'a1200000-0000-0000-0000-000000000099',
  'b1200000-0000-0000-0000-000000000001',
  'd1200000-0000-0000-0000-000000000001',
  now() + interval '3 days',
  'follow_up'
);

-- Set context: owner of tenant one
SELECT set_config('request.jwt.claims',
  '{"sub":"a1200000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1200000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 1. advance_deal_stage_v1 start_analysis succeeds
SELECT is(
  (public.advance_deal_stage_v1('d1200000-0000-0000-0000-000000000001', 'start_analysis')::json)->>'ok',
  'true',
  'advance_deal_stage_v1: start_analysis succeeds'
);

SET LOCAL ROLE postgres;
-- 2. stage_change activity row written
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_activity_log
   WHERE deal_id = 'd1200000-0000-0000-0000-000000000001'
   AND activity_type = 'stage_change'),
  1,
  'advance_deal_stage_v1: writes stage_change activity row'
);

-- 3. activity content correct
SELECT is(
  (SELECT content FROM public.deal_activity_log
   WHERE deal_id = 'd1200000-0000-0000-0000-000000000001'
   AND activity_type = 'stage_change'),
  'Stage advanced to Analyzing',
  'advance_deal_stage_v1: activity content correct'
);
SET LOCAL ROLE authenticated;

-- 4. advance to offer_sent
SELECT is(
  (public.advance_deal_stage_v1('d1200000-0000-0000-0000-000000000001', 'send_offer')::json)->>'ok',
  'true',
  'advance_deal_stage_v1: send_offer succeeds'
);

-- 5. advance to under_contract
SELECT is(
  (public.advance_deal_stage_v1('d1200000-0000-0000-0000-000000000001', 'mark_contract_signed')::json)->>'ok',
  'true',
  'advance_deal_stage_v1: mark_contract_signed succeeds'
);

SET LOCAL ROLE postgres;
-- 6. three stage advances = three activity rows
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_activity_log
   WHERE deal_id = 'd1200000-0000-0000-0000-000000000001'
   AND activity_type = 'stage_change'),
  3,
  'advance_deal_stage_v1: three stage advances write three activity rows'
);
SET LOCAL ROLE authenticated;

-- 7. handoff_to_dispo_v1 writes activity row
SELECT is(
  (public.handoff_to_dispo_v1(
    'd1200000-0000-0000-0000-000000000001',
    'a1200000-0000-0000-0000-000000000001'::uuid
  )::json)->>'ok',
  'true',
  'handoff_to_dispo_v1: handoff succeeds'
);

SET LOCAL ROLE postgres;
-- 8. handoff activity row written
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_activity_log
   WHERE deal_id = 'd1200000-0000-0000-0000-000000000001'
   AND activity_type = 'handoff'),
  1,
  'handoff_to_dispo_v1: writes handoff activity row'
);

-- 9. cross-tenant isolation -- tenant two cannot see tenant one activity rows
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_activity_log
   WHERE deal_id = 'd1200000-0000-0000-0000-000000000001'
   AND tenant_id = 'b1200000-0000-0000-0000-000000000002'),
  0,
  'deal_activity_log: cross-tenant isolation -- tenant two has no activity rows for tenant one deal'
);
SET LOCAL ROLE authenticated;

-- 10. complete_reminder_v1 first completion succeeds
SELECT is(
  (public.complete_reminder_v1('a1200000-0000-0000-0000-000000000099')::json)->>'ok',
  'true',
  'complete_reminder_v1: first completion succeeds'
);

SET LOCAL ROLE postgres;
-- 11. reminder_completed activity row written
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_activity_log
   WHERE deal_id = 'd1200000-0000-0000-0000-000000000001'
   AND activity_type = 'reminder_completed'),
  1,
  'complete_reminder_v1: writes reminder_completed activity row'
);
SET LOCAL ROLE authenticated;

-- 12. complete_reminder_v1 idempotent -- second call ok=true
SELECT is(
  (public.complete_reminder_v1('a1200000-0000-0000-0000-000000000099')::json)->>'ok',
  'true',
  'complete_reminder_v1: idempotent -- second call ok=true'
);

SET LOCAL ROLE postgres;
-- 13. no duplicate activity row on second completion
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_activity_log
   WHERE deal_id = 'd1200000-0000-0000-0000-000000000001'
   AND activity_type = 'reminder_completed'),
  1,
  'complete_reminder_v1: no duplicate activity row on repeat call'
);
SET LOCAL ROLE authenticated;

-- 14. create_deal_note_v1 does NOT write activity row
SELECT is(
  (public.create_deal_note_v1('d1200000-0000-0000-0000-000000000001', 'note', 'Test note content')::json)->>'ok',
  'true',
  'create_deal_note_v1: note creation succeeds'
);

SET LOCAL ROLE postgres;
-- 15. note creation does not write to activity log
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_activity_log
   WHERE deal_id = 'd1200000-0000-0000-0000-000000000001'
   AND activity_type = 'note_added'),
  0,
  'create_deal_note_v1: does not write to activity log'
);

-- 16. activity log total row count for deal -- 3 stage + 1 handoff + 1 reminder = 5
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_activity_log
   WHERE deal_id = 'd1200000-0000-0000-0000-000000000001'
   AND tenant_id = 'b1200000-0000-0000-0000-000000000001'),
  5,
  'deal_activity_log: total activity rows correct for deal'
);

-- 17. activity rows are tenant-scoped correctly
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_activity_log
   WHERE tenant_id = 'b1200000-0000-0000-0000-000000000001'),
  5,
  'deal_activity_log: all activity rows belong to correct tenant'
);

SELECT finish();
ROLLBACK;