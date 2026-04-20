-- 10.11A1: Deal Notes / Activity Log tests
BEGIN;

SELECT plan(20);

-- Seed tenant one: owner + member
SELECT public.create_active_workspace_seed_v1(
  'b1110001-0000-0000-0000-000000000001'::uuid,
  'a1110001-0000-0000-0000-000000000001'::uuid,
  'owner'
);
SELECT public.create_active_workspace_seed_v1(
  'b1110001-0000-0000-0000-000000000001'::uuid,
  'a1110001-0000-0000-0000-000000000002'::uuid,
  'member'
);

-- Seed tenant two: cross-tenant isolation
SELECT public.create_active_workspace_seed_v1(
  'b1110001-0000-0000-0000-000000000002'::uuid,
  'a1110001-0000-0000-0000-000000000003'::uuid,
  'owner'
);

-- Set display names
UPDATE public.user_profiles
SET display_name = 'Owner A1'
WHERE id = 'a1110001-0000-0000-0000-000000000001';

UPDATE public.user_profiles
SET display_name = 'Member A1'
WHERE id = 'a1110001-0000-0000-0000-000000000002';

-- Seed deals
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, updated_at, created_at)
VALUES
  ('d1110001-0000-0000-0000-000000000001', 'b1110001-0000-0000-0000-000000000001', 1, 1, 'new', now(), now());

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, updated_at, created_at)
VALUES
  ('d1110001-0000-0000-0000-000000000002', 'b1110001-0000-0000-0000-000000000002', 1, 1, 'new', now(), now());

-- Direct seed inserts run as superuser (before SET LOCAL ROLE authenticated)
-- deal_notes and deal_activity_log have REVOKE ALL FROM authenticated
-- so seeding must happen here, before role switch

INSERT INTO public.deal_notes (id, tenant_id, deal_id, note_type, content, created_by, created_at, updated_at)
VALUES
  ('e1110001-0000-0000-0000-000000000001', 'b1110001-0000-0000-0000-000000000001', 'd1110001-0000-0000-0000-000000000001', 'note',     'Older note', 'a1110001-0000-0000-0000-000000000001', '2026-01-01 10:00:00+00', '2026-01-01 10:00:00+00'),
  ('e1110001-0000-0000-0000-000000000002', 'b1110001-0000-0000-0000-000000000001', 'd1110001-0000-0000-0000-000000000001', 'call_log', 'Newer note', 'a1110001-0000-0000-0000-000000000001', '2026-01-01 11:00:00+00', '2026-01-01 11:00:00+00');

INSERT INTO public.deal_activity_log (id, tenant_id, deal_id, activity_type, content, created_by, created_at)
VALUES
  ('f1110001-0000-0000-0000-000000000001', 'b1110001-0000-0000-0000-000000000001', 'd1110001-0000-0000-0000-000000000001', 'stage_changed', 'Deal moved to analyzing', 'a1110001-0000-0000-0000-000000000001', '2026-01-01 09:00:00+00'),
  ('f1110001-0000-0000-0000-000000000002', 'b1110001-0000-0000-0000-000000000001', 'd1110001-0000-0000-0000-000000000001', 'marked_dead',   'Deal marked dead',        'a1110001-0000-0000-0000-000000000001', '2026-01-01 10:30:00+00');

-- Set context: owner of tenant one
SELECT set_config('request.jwt.claims',
  '{"sub":"a1110001-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1110001-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- 1. create_deal_note_v1 success (note)
SELECT is(
  (public.create_deal_note_v1('d1110001-0000-0000-0000-000000000001', 'note', 'Fresh note')::json)->>'ok',
  'true',
  'create_deal_note_v1: note type succeeds'
);

-- 2. create_deal_note_v1 success (call_log)
SELECT is(
  (public.create_deal_note_v1('d1110001-0000-0000-0000-000000000001', 'call_log', 'Called seller')::json)->>'ok',
  'true',
  'create_deal_note_v1: call_log type succeeds'
);

-- Pin created_at for the two RPC-inserted notes to distinct known timestamps
-- Must reset role to superuser to UPDATE the table directly
SET LOCAL ROLE postgres;

UPDATE public.deal_notes
SET created_at = '2026-01-01 13:00:00+00', updated_at = '2026-01-01 13:00:00+00'
WHERE content = 'Fresh note' AND tenant_id = 'b1110001-0000-0000-0000-000000000001';

UPDATE public.deal_notes
SET created_at = '2026-01-01 14:00:00+00', updated_at = '2026-01-01 14:00:00+00'
WHERE content = 'Called seller' AND tenant_id = 'b1110001-0000-0000-0000-000000000001';

SET LOCAL ROLE authenticated;

-- 3. create_deal_note_v1 invalid note_type rejected
SELECT is(
  (public.create_deal_note_v1('d1110001-0000-0000-0000-000000000001', 'garbage', 'content')::json)->>'code',
  'VALIDATION_ERROR',
  'create_deal_note_v1: invalid note_type returns VALIDATION_ERROR'
);

-- 4. create_deal_note_v1 empty content rejected
SELECT is(
  (public.create_deal_note_v1('d1110001-0000-0000-0000-000000000001', 'note', '')::json)->>'code',
  'VALIDATION_ERROR',
  'create_deal_note_v1: empty content returns VALIDATION_ERROR'
);

-- 5. create_deal_note_v1 cross-tenant deal returns NOT_FOUND
SELECT is(
  (public.create_deal_note_v1('d1110001-0000-0000-0000-000000000002', 'note', 'cross tenant')::json)->>'code',
  'NOT_FOUND',
  'create_deal_note_v1: cross-tenant deal returns NOT_FOUND'
);

-- 6. list_deal_notes_v1 returns ok
SELECT is(
  (public.list_deal_notes_v1('d1110001-0000-0000-0000-000000000001')::json)->>'ok',
  'true',
  'list_deal_notes_v1: returns ok'
);

-- 7. list_deal_notes_v1 notes array not empty
SELECT ok(
  json_array_length(
    (public.list_deal_notes_v1('d1110001-0000-0000-0000-000000000001')::json)->'data'->'notes'
  ) > 0,
  'list_deal_notes_v1: notes array has entries'
);

-- 8. list_deal_notes_v1 newest first
-- Called seller pinned to 2026-01-01 14:00 -- must be index 0
SELECT is(
  (
    (public.list_deal_notes_v1('d1110001-0000-0000-0000-000000000001')::json)
    ->'data'->'notes'->0->>'content'
  ),
  'Called seller',
  'list_deal_notes_v1: newest note appears first'
);

-- 9. list_deal_notes_v1 oldest note appears last
-- Older note pinned to 2026-01-01 10:00 -- must be index 3
SELECT is(
  (
    (public.list_deal_notes_v1('d1110001-0000-0000-0000-000000000001')::json)
    ->'data'->'notes'->3->>'content'
  ),
  'Older note',
  'list_deal_notes_v1: oldest note appears last'
);

-- 10. list_deal_notes_v1 created_by_name exact match
SELECT is(
  (
    (public.list_deal_notes_v1('d1110001-0000-0000-0000-000000000001')::json)
    ->'data'->'notes'->0->>'created_by_name'
  ),
  'Owner A1',
  'list_deal_notes_v1: created_by_name matches expected display name'
);

-- 11. list_deal_notes_v1 cross-tenant deal returns NOT_FOUND
SELECT is(
  (public.list_deal_notes_v1('d1110001-0000-0000-0000-000000000002')::json)->>'code',
  'NOT_FOUND',
  'list_deal_notes_v1: cross-tenant deal returns NOT_FOUND'
);

-- 12. list_deal_activity_v1 returns ok
SELECT is(
  (public.list_deal_activity_v1('d1110001-0000-0000-0000-000000000001')::json)->>'ok',
  'true',
  'list_deal_activity_v1: returns ok'
);

-- 13. list_deal_activity_v1 has entries
SELECT ok(
  json_array_length(
    (public.list_deal_activity_v1('d1110001-0000-0000-0000-000000000001')::json)->'data'->'activity'
  ) > 0,
  'list_deal_activity_v1: has activity entries'
);

-- 14. list_deal_activity_v1 newest first
-- marked_dead pinned to 2026-01-01 10:30 -- must be index 0
SELECT is(
  (
    (public.list_deal_activity_v1('d1110001-0000-0000-0000-000000000001')::json)
    ->'data'->'activity'->0->>'activity_type'
  ),
  'marked_dead',
  'list_deal_activity_v1: newest activity appears first'
);

-- 15. list_deal_activity_v1 older entry appears after newer
SELECT is(
  (
    (public.list_deal_activity_v1('d1110001-0000-0000-0000-000000000001')::json)
    ->'data'->'activity'->1->>'activity_type'
  ),
  'stage_changed',
  'list_deal_activity_v1: older activity appears after newer'
);

-- 16. list_deal_activity_v1 created_by_name exact match
SELECT is(
  (
    (public.list_deal_activity_v1('d1110001-0000-0000-0000-000000000001')::json)
    ->'data'->'activity'->0->>'created_by_name'
  ),
  'Owner A1',
  'list_deal_activity_v1: created_by_name matches expected display name'
);

-- 17. list_deal_activity_v1 cross-tenant deal returns NOT_FOUND
SELECT is(
  (public.list_deal_activity_v1('d1110001-0000-0000-0000-000000000002')::json)->>'code',
  'NOT_FOUND',
  'list_deal_activity_v1: cross-tenant deal returns NOT_FOUND'
);

-- 18. mark_deal_dead_v1 succeeds
SELECT is(
  (public.mark_deal_dead_v1('d1110001-0000-0000-0000-000000000001', 'No longer interested')::json)->>'ok',
  'true',
  'mark_deal_dead_v1: succeeds'
);

-- 19. stream separation: activity count is exactly 3 (2 seeded + 1 from mark_dead)
SELECT is(
  json_array_length(
    (public.list_deal_activity_v1('d1110001-0000-0000-0000-000000000001')::json)->'data'->'activity'
  ),
  3,
  'stream separation: user notes do not appear in activity log'
);

-- 20. notes count is independent from activity count
SELECT ok(
  json_array_length(
    (public.list_deal_notes_v1('d1110001-0000-0000-0000-000000000001')::json)->'data'->'notes'
  ) > json_array_length(
    (public.list_deal_activity_v1('d1110001-0000-0000-0000-000000000001')::json)->'data'->'activity'
  ),
  'stream separation: notes count is independent from activity count'
);

SELECT finish();
ROLLBACK;