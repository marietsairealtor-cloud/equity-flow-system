-- 10.11A: Acquisition Backend tests
BEGIN;

SELECT plan(47);

SELECT public.create_active_workspace_seed_v1(
  'b1110000-0000-0000-0000-000000000001'::uuid,
  'a1110000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

SELECT public.create_active_workspace_seed_v1(
  'b1110000-0000-0000-0000-000000000001'::uuid,
  'a1110000-0000-0000-0000-000000000002'::uuid,
  'member'
);

SELECT public.create_active_workspace_seed_v1(
  'b1110000-0000-0000-0000-000000000002'::uuid,
  'a1110000-0000-0000-0000-000000000009'::uuid,
  'owner'
);

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, updated_at, created_at)
VALUES
  ('d1110000-0000-0000-0000-000000000001', 'b1110000-0000-0000-0000-000000000001', 1, 1, 'new',            now(), now()),
  ('d1110000-0000-0000-0000-000000000002', 'b1110000-0000-0000-0000-000000000001', 1, 1, 'analyzing',      now(), now()),
  ('d1110000-0000-0000-0000-000000000003', 'b1110000-0000-0000-0000-000000000001', 1, 1, 'offer_sent',     now(), now()),
  ('d1110000-0000-0000-0000-000000000004', 'b1110000-0000-0000-0000-000000000001', 1, 1, 'under_contract', now(), now()),
  ('d1110000-0000-0000-0000-000000000005', 'b1110000-0000-0000-0000-000000000001', 1, 1, 'dispo',          now(), now()),
  ('d1110000-0000-0000-0000-000000000006', 'b1110000-0000-0000-0000-000000000001', 1, 1, 'dead',           now(), now());

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, updated_at, created_at)
VALUES
  ('d1110000-0000-0000-0000-000000000099', 'b1110000-0000-0000-0000-000000000002', 1, 1, 'new', now(), now());

SELECT set_config('request.jwt.claims',
  '{"sub":"a1110000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1110000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- ============================================================
-- get_acq_kpis_v1
-- ============================================================

-- 1.
SELECT is(
  (public.get_acq_kpis_v1()::json)->>'ok',
  'true',
  '10.11A: get_acq_kpis_v1 returns ok=true'
);

-- 2.
SELECT ok(
  (public.get_acq_kpis_v1()::json)->'data'->>'contracts_signed' IS NOT NULL,
  '10.11A: get_acq_kpis_v1 returns contracts_signed'
);

-- 3.
SELECT ok(
  (public.get_acq_kpis_v1()::json)->'data'->>'lead_to_contract_pct' IS NOT NULL,
  '10.11A: get_acq_kpis_v1 returns lead_to_contract_pct'
);

-- 4.
SELECT ok(
  (public.get_acq_kpis_v1()::json)->'data'->>'avg_assignment_fee' IS NOT NULL,
  '10.11A: get_acq_kpis_v1 returns avg_assignment_fee'
);

-- ============================================================
-- list_acq_deals_v1
-- ============================================================

-- 5.
SELECT is(
  (public.list_acq_deals_v1('all')::json)->>'ok',
  'true',
  '10.11A: list_acq_deals_v1 all returns ok=true'
);

-- 6.
SELECT ok(
  (
    SELECT NOT EXISTS (
      SELECT 1
      FROM json_array_elements((public.list_acq_deals_v1('all')::json)->'data'->'items') AS item
      WHERE item->>'stage' IN ('dispo', 'tc', 'closed', 'dead')
    )
  ),
  '10.11A: list_acq_deals_v1 excludes dispo/tc/closed/dead'
);

-- 7.
SELECT is(
  (public.list_acq_deals_v1('new')::json)->>'ok',
  'true',
  '10.11A: list_acq_deals_v1 new filter ok=true'
);

-- 8.
SELECT is(
  (public.list_acq_deals_v1('garbage')::json)->>'ok',
  'false',
  '10.11A: list_acq_deals_v1 invalid filter returns ok=false'
);

-- 9.
SELECT is(
  (public.list_acq_deals_v1('garbage')::json)->>'code',
  'VALIDATION_ERROR',
  '10.11A: list_acq_deals_v1 invalid filter returns VALIDATION_ERROR'
);

-- ============================================================
-- get_acq_deal_v1
-- ============================================================

-- 10.
SELECT is(
  (public.get_acq_deal_v1('d1110000-0000-0000-0000-000000000001')::json)->>'ok',
  'true',
  '10.11A: get_acq_deal_v1 returns ok=true'
);

-- 11.
SELECT is(
  (public.get_acq_deal_v1('d1110000-0000-0000-0000-000000000001')::json)->'data'->>'stage',
  'new',
  '10.11A: get_acq_deal_v1 returns correct stage'
);

-- 12.
SELECT is(
  (public.get_acq_deal_v1('d9990000-0000-0000-0000-000000000001')::json)->>'code',
  'NOT_FOUND',
  '10.11A: get_acq_deal_v1 NOT_FOUND for unknown deal'
);

-- ============================================================
-- update_seller_info_v1
-- ============================================================

-- 13.
SELECT is(
  (public.update_seller_info_v1(
    'd1110000-0000-0000-0000-000000000001',
    'John Doe', '5125550100', 'jdoe@example.com',
    'Inherited property', 'Close in 30d', 'Motivated seller',
    'Follow up on price', now() + interval '1 day'
  )::json)->>'ok',
  'true',
  '10.11A: update_seller_info_v1 succeeds'
);

-- 14. DB state check — reset to superuser
RESET ROLE;
SELECT is(
  (SELECT seller_name FROM public.deals WHERE id = 'd1110000-0000-0000-0000-000000000001'),
  'John Doe',
  '10.11A: update_seller_info_v1 persists seller_name'
);
SET LOCAL ROLE authenticated;

-- 15.
SELECT is(
  (public.update_seller_info_v1('d9990000-0000-0000-0000-000000000001', 'X')::json)->>'code',
  'NOT_FOUND',
  '10.11A: update_seller_info_v1 NOT_FOUND for unknown deal'
);

-- ============================================================
-- update_property_info_v1
-- ============================================================

-- 16.
SELECT is(
  (public.update_property_info_v1(
    'd1110000-0000-0000-0000-000000000001',
    'Single family', 3, 2.0, 1400, '6000 sqft', 1978, 'vacant',
    ARRAY['needs roof', 'HVAC old'], 'Fair condition', 45000.00,
    '1 car', 'partial', 'poured concrete',
    15, 12, 10, 'forced air', 'central'
  )::json)->>'ok',
  'true',
  '10.11A: update_property_info_v1 upsert succeeds'
);

-- 17. DB state check
RESET ROLE;
SELECT is(
  (SELECT property_type FROM public.deal_properties WHERE deal_id = 'd1110000-0000-0000-0000-000000000001'),
  'Single family',
  '10.11A: update_property_info_v1 persists property_type'
);
SET LOCAL ROLE authenticated;

-- 18.
SELECT is(
  (public.update_property_info_v1(
    'd1110000-0000-0000-0000-000000000001',
    'Condo'
  )::json)->>'ok',
  'true',
  '10.11A: update_property_info_v1 second upsert succeeds'
);

-- 19. DB state check
RESET ROLE;
SELECT is(
  (SELECT property_type FROM public.deal_properties WHERE deal_id = 'd1110000-0000-0000-0000-000000000001'),
  'Condo',
  '10.11A: update_property_info_v1 second upsert updates property_type'
);
SET LOCAL ROLE authenticated;

-- ============================================================
-- advance_deal_stage_v1
-- ============================================================

-- 20.
SELECT is(
  (public.advance_deal_stage_v1('d1110000-0000-0000-0000-000000000001', 'start_analysis')::json)->>'ok',
  'true',
  '10.11A: advance_deal_stage_v1 new → analyzing ok=true'
);

-- 21. DB state check
RESET ROLE;
SELECT is(
  (SELECT stage FROM public.deals WHERE id = 'd1110000-0000-0000-0000-000000000001'),
  'analyzing',
  '10.11A: advance_deal_stage_v1 new → analyzing DB state'
);
SET LOCAL ROLE authenticated;

-- 22.
SELECT is(
  (public.advance_deal_stage_v1('d1110000-0000-0000-0000-000000000002', 'send_offer')::json)->>'ok',
  'true',
  '10.11A: advance_deal_stage_v1 analyzing → offer_sent ok=true'
);

-- 23.
SELECT is(
  (public.advance_deal_stage_v1('d1110000-0000-0000-0000-000000000003', 'start_analysis')::json)->>'code',
  'CONFLICT',
  '10.11A: advance_deal_stage_v1 invalid transition returns CONFLICT'
);

-- ============================================================
-- mark_deal_dead_v1
-- ============================================================

-- 24.
SELECT is(
  (public.mark_deal_dead_v1('d1110000-0000-0000-0000-000000000003', 'Seller went with another buyer')::json)->>'ok',
  'true',
  '10.11A: mark_deal_dead_v1 succeeds'
);

-- 25. DB state check
RESET ROLE;
SELECT is(
  (SELECT stage FROM public.deals WHERE id = 'd1110000-0000-0000-0000-000000000003'),
  'dead',
  '10.11A: mark_deal_dead_v1 stage=dead in DB'
);
SET LOCAL ROLE authenticated;

-- 26.
SELECT is(
  (public.mark_deal_dead_v1('d1110000-0000-0000-0000-000000000002', '')::json)->>'code',
  'VALIDATION_ERROR',
  '10.11A: mark_deal_dead_v1 empty reason returns VALIDATION_ERROR'
);

-- 27.
SELECT is(
  (public.mark_deal_dead_v1('d1110000-0000-0000-0000-000000000006', 'reason')::json)->>'code',
  'CONFLICT',
  '10.11A: mark_deal_dead_v1 already dead returns CONFLICT'
);

-- ============================================================
-- handoff_to_dispo_v1
-- ============================================================

-- 28.
SELECT is(
  (public.handoff_to_dispo_v1(
    'd1110000-0000-0000-0000-000000000004',
    'a1110000-0000-0000-0000-000000000002'
  )::json)->>'ok',
  'true',
  '10.11A: handoff_to_dispo_v1 succeeds'
);

-- 29. DB state check
RESET ROLE;
SELECT is(
  (SELECT stage FROM public.deals WHERE id = 'd1110000-0000-0000-0000-000000000004'),
  'dispo',
  '10.11A: handoff_to_dispo_v1 stage=dispo in DB'
);
SET LOCAL ROLE authenticated;

-- 30.
SELECT is(
  (public.handoff_to_dispo_v1(
    'd1110000-0000-0000-0000-000000000002',
    'a1110000-0000-0000-0000-000000000002'
  )::json)->>'code',
  'CONFLICT',
  '10.11A: handoff_to_dispo_v1 non-UC returns CONFLICT'
);

-- ============================================================
-- return_to_acq_v1
-- ============================================================

-- 31.
SELECT is(
  (public.return_to_acq_v1('d1110000-0000-0000-0000-000000000004')::json)->>'ok',
  'true',
  '10.11A: return_to_acq_v1 succeeds'
);

-- 32.
SELECT is(
  (public.return_to_acq_v1('d1110000-0000-0000-0000-000000000002')::json)->>'code',
  'CONFLICT',
  '10.11A: return_to_acq_v1 non-dispo returns CONFLICT'
);

-- ============================================================
-- list_deal_media_v1
-- ============================================================

-- 33.
SELECT is(
  (public.list_deal_media_v1('d1110000-0000-0000-0000-000000000001')::json)->>'ok',
  'true',
  '10.11A: list_deal_media_v1 returns ok=true'
);

-- ============================================================
-- register_deal_media_v1
-- ============================================================

-- 34.
SELECT is(
  (public.register_deal_media_v1(
    'd1110000-0000-0000-0000-000000000001',
    'tenants/b1110000/deals/d1110000/photo1.jpg',
    0
  )::json)->>'ok',
  'true',
  '10.11A: register_deal_media_v1 succeeds'
);

-- 35. DB state check
RESET ROLE;
SELECT ok(
  EXISTS (
    SELECT 1 FROM public.deal_media
    WHERE deal_id = 'd1110000-0000-0000-0000-000000000001'
      AND storage_path = 'tenants/b1110000/deals/d1110000/photo1.jpg'
  ),
  '10.11A: register_deal_media_v1 persists row'
);
SET LOCAL ROLE authenticated;

-- 36.
SELECT is(
  (public.register_deal_media_v1(
    'd1110000-0000-0000-0000-000000000001',
    '',
    0
  )::json)->>'code',
  'VALIDATION_ERROR',
  '10.11A: register_deal_media_v1 empty path returns VALIDATION_ERROR'
);

-- ============================================================
-- delete_deal_media_v1
-- ============================================================

-- 37.
RESET ROLE;
SELECT is(
  (
    SELECT (public.delete_deal_media_v1(m.id)::json)->>'ok'
    FROM public.deal_media m
    WHERE m.deal_id = 'd1110000-0000-0000-0000-000000000001'
    LIMIT 1
  ),
  'true',
  '10.11A: delete_deal_media_v1 succeeds'
);
SET LOCAL ROLE authenticated;

-- 38.
SELECT is(
  (public.delete_deal_media_v1('f9990000-0000-0000-0000-000000000001')::json)->>'code',
  'NOT_FOUND',
  '10.11A: delete_deal_media_v1 NOT_FOUND for unknown media'
);

-- ============================================================
-- Tenant isolation
-- ============================================================

-- 39.
SELECT is(
  (public.get_acq_deal_v1('d1110000-0000-0000-0000-000000000099')::json)->>'code',
  'NOT_FOUND',
  '10.11A: get_acq_deal_v1 cross-tenant returns NOT_FOUND'
);

-- 40.
SELECT is(
  (public.update_seller_info_v1('d1110000-0000-0000-0000-000000000099', 'Hacker')::json)->>'code',
  'NOT_FOUND',
  '10.11A: update_seller_info_v1 cross-tenant returns NOT_FOUND'
);

-- 41.
SELECT is(
  (public.register_deal_media_v1(
    'd1110000-0000-0000-0000-000000000099',
    'tenants/other/photo.jpg',
    0
  )::json)->>'code',
  'NOT_FOUND',
  '10.11A: register_deal_media_v1 cross-tenant returns NOT_FOUND'
);

-- ============================================================
-- Terminal stage immutability
-- ============================================================

-- 42.
SELECT is(
  (public.update_deal_v1(
    'd1110000-0000-0000-0000-000000000006',
    1
  )::json)->>'code',
  'CONFLICT',
  '10.11A: update_deal_v1 on dead deal returns CONFLICT'
);

-- ============================================================
-- Row version concurrency
-- ============================================================

-- 43.
SELECT is(
  (public.update_deal_v1(
    'd1110000-0000-0000-0000-000000000002',
    9999
  )::json)->>'code',
  'CONFLICT',
  '10.11A: update_deal_v1 stale row_version returns CONFLICT'
);

-- ============================================================
-- Duplicate media storage path
-- ============================================================

-- 44.
SELECT is(
  (public.register_deal_media_v1(
    'd1110000-0000-0000-0000-000000000001',
    'tenants/b1110000/deals/d1110000/photo_dup.jpg',
    0
  )::json)->>'ok',
  'true',
  '10.11A: register first media path succeeds'
);

-- 45.
SELECT is(
  (public.register_deal_media_v1(
    'd1110000-0000-0000-0000-000000000001',
    'tenants/b1110000/deals/d1110000/photo_dup.jpg',
    0
  )::json)->>'code',
  'CONFLICT',
  '10.11A: duplicate storage_path returns CONFLICT'
);

-- ============================================================
-- Assignee after handoff + return_to_acq DB state
-- ============================================================

-- 46. d1110000-0000-0000-0000-000000000004 is under_contract after test 31
SELECT is(
  (public.handoff_to_dispo_v1(
    'd1110000-0000-0000-0000-000000000004'::uuid,
    'a1110000-0000-0000-0000-000000000002'::uuid
  )::json)->>'ok',
  'true',
  '10.11A: handoff_to_dispo_v1 second handoff ok=true'
);

-- 47. DB state check for assignee
RESET ROLE;
SELECT is(
  (SELECT assignee_user_id::text FROM public.deals WHERE id = 'd1110000-0000-0000-0000-000000000004'),
  'a1110000-0000-0000-0000-000000000002',
  '10.11A: handoff_to_dispo_v1 persists assignee_user_id'
);

SELECT finish();
ROLLBACK;