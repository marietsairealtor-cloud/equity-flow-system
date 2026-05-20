-- 10.14B4C: ACQ Backend Cleanup -- Remove Unused Call Log Surface tests
BEGIN;

SELECT plan(13);

-- Seed tenant + owner
SELECT public.create_active_workspace_seed_v1(
  'b1144300-0000-0000-0000-000000000001'::uuid,
  'a1144300-0000-0000-0000-000000000001'::uuid,
  'owner'
);

-- Seed deal
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd1144300-0000-0000-0000-000000000001',
  'b1144300-0000-0000-0000-000000000001',
  1, 1, 'new', '123 CallLog St', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e1144300-0000-0000-0000-000000000001',
  'b1144300-0000-0000-0000-000000000001',
  'd1144300-0000-0000-0000-000000000001',
  1,
  '{"arv":300000,"ask_price":200000}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e1144300-0000-0000-0000-000000000001'
WHERE id = 'd1144300-0000-0000-0000-000000000001';

-- Seed historical call_log note directly (simulates pre-existing data)
INSERT INTO public.deal_notes (id, tenant_id, deal_id, note_type, content, created_by, created_at, updated_at)
VALUES (
  'f1144300-0000-0000-0000-000000000001',
  'b1144300-0000-0000-0000-000000000001',
  'd1144300-0000-0000-0000-000000000001',
  'call_log',
  'Historical call log entry',
  'a1144300-0000-0000-0000-000000000001',
  '2026-01-01 10:00:00+00',
  '2026-01-01 10:00:00+00'
);

-- Set context: tenant one owner
SELECT set_config('request.jwt.claims',
  '{"sub":"a1144300-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1144300-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 1. create_deal_note_v1 accepts note type
SELECT is(
  (public.create_deal_note_v1(
    'd1144300-0000-0000-0000-000000000001',
    'note',
    'A normal note'
  )::json)->>'code',
  'OK',
  'create_deal_note_v1: note type still accepted'
);

-- 2. create_deal_note_v1 rejects call_log type
SELECT is(
  (public.create_deal_note_v1(
    'd1144300-0000-0000-0000-000000000001',
    'call_log',
    'Rejected call log'
  )::json)->>'code',
  'VALIDATION_ERROR',
  'create_deal_note_v1: call_log type rejected'
);

-- 3. rejected call_log does not insert a row
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_notes
   WHERE content = 'Rejected call log' AND tenant_id = 'b1144300-0000-0000-0000-000000000001'),
  0,
  'create_deal_note_v1: rejected call_log does not insert a row'
);
SET LOCAL ROLE authenticated;

-- 4. get_acq_deal_v1: last_contacted_at key absent from data
SELECT ok(
  NOT ((public.get_acq_deal_v1('d1144300-0000-0000-0000-000000000001')::jsonb)->'data' ? 'last_contacted_at'),
  'get_acq_deal_v1: last_contacted_at key absent after 10.14B4C'
);

-- 5. get_acq_deal_v1 still returns address (regression)
SELECT is(
  (public.get_acq_deal_v1('d1144300-0000-0000-0000-000000000001')::json)->'data'->>'address',
  '123 CallLog St',
  'get_acq_deal_v1: address still returned'
);

-- 6. get_acq_deal_v1 still returns stage (regression)
SELECT is(
  (public.get_acq_deal_v1('d1144300-0000-0000-0000-000000000001')::json)->'data'->>'stage',
  'new',
  'get_acq_deal_v1: stage still returned'
);

-- 7. historical call_log row still exists in deal_notes (not deleted)
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_notes
   WHERE note_type = 'call_log' AND tenant_id = 'b1144300-0000-0000-0000-000000000001'),
  1,
  'deal_notes: historical call_log rows not deleted'
);
SET LOCAL ROLE authenticated;

-- 8. list_deal_notes_v1 still returns historical call_log note (readable)
SELECT ok(
  EXISTS (
    SELECT 1
    FROM json_array_elements(
      (public.list_deal_notes_v1('d1144300-0000-0000-0000-000000000001')::json)->'data'->'notes'
    ) AS n
    WHERE n->>'note_type' = 'call_log'
      AND n->>'content' = 'Historical call log entry'
  ),
  'list_deal_notes_v1: historical call_log note still readable'
);

-- 9. list_deal_notes_v1 still returns ok (regression)
SELECT is(
  (public.list_deal_notes_v1('d1144300-0000-0000-0000-000000000001')::json)->>'ok',
  'true',
  'list_deal_notes_v1: still returns ok'
);

-- 10. create_deal_note_v1 rejects null note_type
SELECT is(
  (public.create_deal_note_v1(
    'd1144300-0000-0000-0000-000000000001',
    null,
    'content'
  )::json)->>'code',
  'VALIDATION_ERROR',
  'create_deal_note_v1: null note_type returns VALIDATION_ERROR'
);

-- 11. create_deal_note_v1 rejects empty content
SELECT is(
  (public.create_deal_note_v1(
    'd1144300-0000-0000-0000-000000000001',
    'note',
    ''
  )::json)->>'code',
  'VALIDATION_ERROR',
  'create_deal_note_v1: empty content returns VALIDATION_ERROR'
);

-- 12. non-member returns NOT_AUTHORIZED on create_deal_note_v1
SELECT set_config('request.jwt.claims',
  '{"sub":"a1144300-0000-0000-0000-000000000099","role":"authenticated","tenant_id":"b1144300-0000-0000-0000-000000000001"}',
  true);
SELECT is(
  (public.create_deal_note_v1(
    'd1144300-0000-0000-0000-000000000001',
    'note',
    'unauthorized'
  )::json)->>'code',
  'NOT_AUTHORIZED',
  'create_deal_note_v1: non-member returns NOT_AUTHORIZED'
);

-- 13. get_acq_deal_v1 non-member returns NOT_AUTHORIZED
SELECT is(
  (public.get_acq_deal_v1('d1144300-0000-0000-0000-000000000001')::json)->>'code',
  'NOT_AUTHORIZED',
  'get_acq_deal_v1: non-member returns NOT_AUTHORIZED'
);

SELECT finish();
ROLLBACK;