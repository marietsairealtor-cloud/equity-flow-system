-- 10.13E: Save deal + reopen deal (ACQ detail)
-- Save: update_deal_pricing_v1 (append-only deal_inputs, snapshot pointer, pricing_save activity)
-- Reopen: get_acq_deal_v1 pricing must match persisted snapshot; cross-tenant isolation.
BEGIN;

SELECT plan(28);

SELECT public.create_active_workspace_seed_v1(
  'b13e0000-0000-0000-0000-000000000001'::uuid,
  'a13e0000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

SELECT public.create_active_workspace_seed_v1(
  'b13e0000-0000-0000-0000-000000000002'::uuid,
  'a13e0000-0000-0000-0000-000000000002'::uuid,
  'owner'
);

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd13e0000-0000-0000-0000-000000000001',
  'b13e0000-0000-0000-0000-000000000001',
  1, 7, 'analyzing', '10.13E Save Reopen Ln', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e13e0000-0000-0000-0000-000000000001',
  'b13e0000-0000-0000-0000-000000000001',
  'd13e0000-0000-0000-0000-000000000001',
  7,
  '{"arv":100000,"ask_price":90000,"repair_estimate":5000,"assignment_fee":0,"mao":65000,"multiplier":0.70}'::jsonb,
  now() - interval '2 hours'
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e13e0000-0000-0000-0000-000000000001'
WHERE id = 'd13e0000-0000-0000-0000-000000000001';

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd13e0000-0000-0000-0000-000000000002',
  'b13e0000-0000-0000-0000-000000000002',
  1, 1, 'new', 'Other Tenant Deal', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e13e0000-0000-0000-0000-000000000002',
  'b13e0000-0000-0000-0000-000000000002',
  'd13e0000-0000-0000-0000-000000000002',
  1,
  '{"arv":200000,"repair_estimate":10000,"multiplier":0.60,"mao":110000}'::jsonb,
  now() - interval '1 hour'
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e13e0000-0000-0000-0000-000000000002'
WHERE id = 'd13e0000-0000-0000-0000-000000000002';

-- Authenticated user with no membership in tenant 1 (require_min_role_v1 / membership guard)
INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES (
  'a13e0000-0000-0000-0000-000000000003',
  'seed_10_13e_nomember@test.local',
  now(), now(), '{}', '{}', 'authenticated', 'authenticated'
)
ON CONFLICT DO NOTHING;

SELECT set_config('request.jwt.claims',
  '{"sub":"a13e0000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b13e0000-0000-0000-0000-000000000001"}',
  true);
SET LOCAL ROLE authenticated;

-- MAO = 400000 * 0.65 - 25000 - 1500 = 233500
SELECT is(
  (public.update_deal_pricing_v1(
    'd13e0000-0000-0000-0000-000000000001',
    '{"arv":400000,"ask_price":310000,"repair_estimate":25000,"assignment_fee":1500,"multiplier":0.65}'::jsonb
  )::json)->>'ok',
  'true',
  '10.13E: update_deal_pricing_v1 succeeds on full-field save'
);

SET LOCAL ROLE postgres;

SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_inputs WHERE deal_id = 'd13e0000-0000-0000-0000-000000000001'),
  2,
  '10.13E: new deal_inputs row appended'
);

SELECT is(
  (SELECT d.assumptions_snapshot_id FROM public.deals d WHERE d.id = 'd13e0000-0000-0000-0000-000000000001'),
  (SELECT di.id FROM public.deal_inputs di
   WHERE di.deal_id = 'd13e0000-0000-0000-0000-000000000001'
   ORDER BY di.created_at DESC, di.id DESC LIMIT 1),
  '10.13E: deals.assumptions_snapshot_id points at newest deal_inputs'
);

SELECT is(
  (SELECT di.calc_version FROM public.deals d
   JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
   WHERE d.id = 'd13e0000-0000-0000-0000-000000000001'),
  7,
  '10.13E: persisted calc_version unchanged on new snapshot'
);

SELECT is(
  (SELECT (di.assumptions->>'arv')::numeric FROM public.deals d
   JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
   WHERE d.id = 'd13e0000-0000-0000-0000-000000000001'),
  400000::numeric,
  '10.13E: snapshot arv persisted'
);

SELECT is(
  (SELECT (di.assumptions->>'ask_price')::numeric FROM public.deals d
   JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
   WHERE d.id = 'd13e0000-0000-0000-0000-000000000001'),
  310000::numeric,
  '10.13E: snapshot ask_price persisted'
);

SELECT is(
  (SELECT (di.assumptions->>'repair_estimate')::numeric FROM public.deals d
   JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
   WHERE d.id = 'd13e0000-0000-0000-0000-000000000001'),
  25000::numeric,
  '10.13E: snapshot repair_estimate persisted'
);

SELECT is(
  (SELECT (di.assumptions->>'assignment_fee')::numeric FROM public.deals d
   JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
   WHERE d.id = 'd13e0000-0000-0000-0000-000000000001'),
  1500::numeric,
  '10.13E: snapshot assignment_fee persisted'
);

SELECT is(
  (SELECT (di.assumptions->>'multiplier')::numeric FROM public.deals d
   JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
   WHERE d.id = 'd13e0000-0000-0000-0000-000000000001'),
  0.65::numeric,
  '10.13E: snapshot multiplier persisted'
);

SELECT is(
  (SELECT (di.assumptions->>'mao')::numeric FROM public.deals d
   JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
   WHERE d.id = 'd13e0000-0000-0000-0000-000000000001'),
  233500::numeric,
  '10.13E: server-derived mao persisted as output'
);

SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_activity_log
   WHERE deal_id = 'd13e0000-0000-0000-0000-000000000001'
     AND activity_type = 'pricing_save'),
  1,
  '10.13E: exactly one pricing_save activity row'
);

SELECT is(
  (SELECT activity_type FROM public.deal_activity_log
   WHERE deal_id = 'd13e0000-0000-0000-0000-000000000001' AND activity_type = 'pricing_save'),
  'pricing_save',
  '10.13E: activity_type is pricing_save'
);

SELECT is(
  (SELECT content FROM public.deal_activity_log
   WHERE deal_id = 'd13e0000-0000-0000-0000-000000000001' AND activity_type = 'pricing_save'),
  'Pricing saved',
  '10.13E: activity content'
);

SELECT is(
  (SELECT tenant_id FROM public.deal_activity_log
   WHERE deal_id = 'd13e0000-0000-0000-0000-000000000001' AND activity_type = 'pricing_save'),
  'b13e0000-0000-0000-0000-000000000001'::uuid,
  '10.13E: activity tenant_id'
);

SELECT is(
  (SELECT created_by FROM public.deal_activity_log
   WHERE deal_id = 'd13e0000-0000-0000-0000-000000000001' AND activity_type = 'pricing_save'),
  'a13e0000-0000-0000-0000-000000000001'::uuid,
  '10.13E: activity created_by'
);

SELECT ok(
  (SELECT created_at IS NOT NULL FROM public.deal_activity_log
   WHERE deal_id = 'd13e0000-0000-0000-0000-000000000001' AND activity_type = 'pricing_save'),
  '10.13E: activity created_at set'
);

SET LOCAL ROLE authenticated;

SELECT is(
  (public.get_acq_deal_v1('d13e0000-0000-0000-0000-000000000001')::json)->>'ok',
  'true',
  '10.13E: get_acq_deal_v1 ok after save'
);

SELECT is(
  (public.get_acq_deal_v1('d13e0000-0000-0000-0000-000000000001')::json)->'data'->'pricing'->>'arv',
  '400000',
  '10.13E: reopen arv matches save'
);

SELECT is(
  (public.get_acq_deal_v1('d13e0000-0000-0000-0000-000000000001')::json)->'data'->'pricing'->>'ask_price',
  '310000',
  '10.13E: reopen ask_price matches save'
);

SELECT is(
  (public.get_acq_deal_v1('d13e0000-0000-0000-0000-000000000001')::json)->'data'->'pricing'->>'repair_estimate',
  '25000',
  '10.13E: reopen repair_estimate matches save'
);

SELECT is(
  (public.get_acq_deal_v1('d13e0000-0000-0000-0000-000000000001')::json)->'data'->'pricing'->>'assignment_fee',
  '1500',
  '10.13E: reopen assignment_fee matches save'
);

SELECT is(
  (public.get_acq_deal_v1('d13e0000-0000-0000-0000-000000000001')::json)->'data'->'pricing'->>'multiplier',
  '0.65',
  '10.13E: reopen multiplier matches save'
);

SELECT is(
  ((public.get_acq_deal_v1('d13e0000-0000-0000-0000-000000000001')::json)->'data'->'pricing'->>'mao')::numeric,
  233500::numeric,
  '10.13E: reopen mao matches persisted output'
);

SELECT is(
  (public.get_acq_deal_v1('d13e0000-0000-0000-0000-000000000001')::json)->'data'->'pricing'->>'calc_version',
  '7',
  '10.13E: reopen calc_version matches snapshot'
);

-- JWT names tenant 1 but caller is not a member → require_min_role_v1 → NOT_AUTHORIZED
SELECT set_config('request.jwt.claims',
  '{"sub":"a13e0000-0000-0000-0000-000000000003","role":"authenticated","tenant_id":"b13e0000-0000-0000-0000-000000000001"}',
  true);

SELECT is(
  (public.update_deal_pricing_v1(
    'd13e0000-0000-0000-0000-000000000001',
    '{"arv":500000}'::jsonb
  )::json)->>'code',
  'NOT_AUTHORIZED',
  '10.13E: non-member JWT cannot save pricing (require_min_role_v1)'
);

SELECT set_config('request.jwt.claims',
  '{"sub":"a13e0000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b13e0000-0000-0000-0000-000000000001"}',
  true);

SELECT is(
  (public.update_deal_pricing_v1(
    'd13e0000-0000-0000-0000-000000000002',
    '{"arv":999999}'::jsonb
  )::json)->>'code',
  'NOT_FOUND',
  '10.13E: cross-tenant pricing save is NOT_FOUND'
);

SELECT is(
  (public.get_acq_deal_v1('d13e0000-0000-0000-0000-000000000002')::json)->>'code',
  'NOT_FOUND',
  '10.13E: cross-tenant reopen is NOT_FOUND'
);

SET LOCAL ROLE postgres;

SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_activity_log
   WHERE deal_id = 'd13e0000-0000-0000-0000-000000000002'
     AND activity_type = 'pricing_save'),
  0,
  '10.13E: other-tenant deal has no pricing_save activity after cross-tenant attempt'
);

SELECT finish();
ROLLBACK;
