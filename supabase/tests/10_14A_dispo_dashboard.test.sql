-- 10.14A: Dispo dashboard KPI read path + list_dispo_dashboard_deals_v1 + handoff_to_tc_v1 activity
BEGIN;

SELECT plan(24);

SELECT public.create_active_workspace_seed_v1(
  'b14a0000-0000-4000-8000-000000000001'::uuid,
  'a14a0000-0000-4000-8000-0000000000a1'::uuid,
  'member'::public.tenant_role
);

SELECT public.create_active_workspace_seed_v1(
  'b14a0000-0000-4000-8000-000000000002'::uuid,
  'a14a0000-0000-4000-8000-0000000000b2'::uuid,
  'member'::public.tenant_role
);

INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES (
  'a14a0000-0000-4000-8000-000000000099'::uuid,
  'seed_10_14a_nomember@test.local',
  now(), now(), '{}', '{}', 'authenticated', 'authenticated'
)
ON CONFLICT DO NOTHING;

SET LOCAL ROLE postgres;

INSERT INTO public.deals (
  id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at
)
VALUES
  (
    'd14a0000-0000-4000-8000-000000000001'::uuid,
    'b14a0000-0000-4000-8000-000000000001'::uuid,
    1, 1, 'dispo', '10.14A Dispo One',
    '2026-06-01 12:00:00+00', now()
  ),
  (
    'd14a0000-0000-4000-8000-000000000002'::uuid,
    'b14a0000-0000-4000-8000-000000000001'::uuid,
    1, 1, 'dispo', '10.14A Dispo Two',
    '2026-05-15 12:00:00+00', now()
  ),
  (
    'd14a0000-0000-4000-8000-000000000003'::uuid,
    'b14a0000-0000-4000-8000-000000000001'::uuid,
    1, 1, 'dispo', '10.14A Dispo Handoff',
    '2026-05-01 12:00:00+00', now()
  ),
  (
    'd14a0000-0000-4000-8000-000000000004'::uuid,
    'b14a0000-0000-4000-8000-000000000001'::uuid,
    1, 1, 'analyzing', '10.14A Acq Only',
    now(), now()
  ),
  (
    'd14a0000-0000-4000-8000-000000000005'::uuid,
    'b14a0000-0000-4000-8000-000000000002'::uuid,
    1, 1, 'dispo', '10.14A Other Tenant',
    now(), now()
  );

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES
  (
    'e14a0000-0000-4000-8000-000000000001'::uuid,
    'b14a0000-0000-4000-8000-000000000001'::uuid,
    'd14a0000-0000-4000-8000-000000000001'::uuid,
    1,
    '{"arv":400000,"ask_price":350000,"repair_estimate":20000,"assignment_fee":10000,"multiplier":0.72,"mao":218000}'::jsonb,
    now()
  ),
  (
    'e14a0000-0000-4000-8000-000000000002'::uuid,
    'b14a0000-0000-4000-8000-000000000001'::uuid,
    'd14a0000-0000-4000-8000-000000000002'::uuid,
    1,
    '{"arv":200000,"ask_price":180000,"repair_estimate":5000,"assignment_fee":20000,"multiplier":0.70,"mao":115000}'::jsonb,
    now()
  ),
  (
    'e14a0000-0000-4000-8000-000000000003'::uuid,
    'b14a0000-0000-4000-8000-000000000001'::uuid,
    'd14a0000-0000-4000-8000-000000000003'::uuid,
    1,
    '{"arv":100000,"repair_estimate":5000,"multiplier":0.65,"mao":60000}'::jsonb,
    now()
  ),
  (
    'e14a0000-0000-4000-8000-000000000004'::uuid,
    'b14a0000-0000-4000-8000-000000000001'::uuid,
    'd14a0000-0000-4000-8000-000000000004'::uuid,
    1,
    '{"arv":300000,"repair_estimate":10000,"multiplier":0.70,"mao":200000}'::jsonb,
    now()
  ),
  (
    'e14a0000-0000-4000-8000-000000000005'::uuid,
    'b14a0000-0000-4000-8000-000000000002'::uuid,
    'd14a0000-0000-4000-8000-000000000005'::uuid,
    1,
    '{"arv":150000,"assignment_fee":5000,"multiplier":0.70,"mao":100000}'::jsonb,
    now()
  );

UPDATE public.deals
SET assumptions_snapshot_id = 'e14a0000-0000-4000-8000-000000000001'::uuid
WHERE id = 'd14a0000-0000-4000-8000-000000000001'::uuid;

UPDATE public.deals
SET assumptions_snapshot_id = 'e14a0000-0000-4000-8000-000000000002'::uuid
WHERE id = 'd14a0000-0000-4000-8000-000000000002'::uuid;

UPDATE public.deals
SET assumptions_snapshot_id = 'e14a0000-0000-4000-8000-000000000003'::uuid
WHERE id = 'd14a0000-0000-4000-8000-000000000003'::uuid;

UPDATE public.deals
SET assumptions_snapshot_id = 'e14a0000-0000-4000-8000-000000000004'::uuid
WHERE id = 'd14a0000-0000-4000-8000-000000000004'::uuid;

UPDATE public.deals
SET assumptions_snapshot_id = 'e14a0000-0000-4000-8000-000000000005'::uuid
WHERE id = 'd14a0000-0000-4000-8000-000000000005'::uuid;

INSERT INTO public.deal_activity_log (
  tenant_id, deal_id, activity_type, content, created_by, created_at
)
VALUES
  (
    'b14a0000-0000-4000-8000-000000000001'::uuid,
    'd14a0000-0000-4000-8000-000000000001'::uuid,
    'handoff',
    'Deal handed off to TC',
    'a14a0000-0000-4000-8000-0000000000a1'::uuid,
    '2026-05-12 10:00:00+00'
  ),
  (
    'b14a0000-0000-4000-8000-000000000001'::uuid,
    'd14a0000-0000-4000-8000-000000000002'::uuid,
    'handoff',
    'Deal handed off to TC',
    'a14a0000-0000-4000-8000-0000000000a1'::uuid,
    '2026-05-12 11:00:00+00'
  ),
  (
    'b14a0000-0000-4000-8000-000000000001'::uuid,
    'd14a0000-0000-4000-8000-000000000001'::uuid,
    'handoff',
    'Deal handed off to Dispo',
    'a14a0000-0000-4000-8000-0000000000a1'::uuid,
    '2026-05-12 09:00:00+00'
  ),
  (
    'b14a0000-0000-4000-8000-000000000001'::uuid,
    'd14a0000-0000-4000-8000-000000000001'::uuid,
    'stage_change',
    'Dispo dashboard teaser',
    'a14a0000-0000-4000-8000-0000000000a1'::uuid,
    '2026-05-12 08:00:00+00'
  );

INSERT INTO public.deal_tc_checklist (id, deal_id, tenant_id, item_key, completed_at)
VALUES
  (
    'c14a0000-0000-4000-8000-000000000001'::uuid,
    'd14a0000-0000-4000-8000-000000000001'::uuid,
    'b14a0000-0000-4000-8000-000000000001'::uuid,
    'deposit_received',
    '2026-05-10 15:00:00+00'
  ),
  (
    'c14a0000-0000-4000-8000-000000000002'::uuid,
    'd14a0000-0000-4000-8000-000000000002'::uuid,
    'b14a0000-0000-4000-8000-000000000001'::uuid,
    'deposit_received',
    '2026-05-11 15:00:00+00'
  );

INSERT INTO public.share_tokens (tenant_id, deal_id, token_hash, expires_at)
VALUES (
  'b14a0000-0000-4000-8000-000000000001'::uuid,
  'd14a0000-0000-4000-8000-000000000001'::uuid,
  decode('00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff', 'hex'),
  now() + interval '60 days'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a14a0000-0000-4000-8000-0000000000a1","role":"authenticated","tenant_id":"b14a0000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (
    public.get_dispo_kpis_v1(
      timestamptz '2026-05-10 00:00:00+00',
      timestamptz '2026-05-01 00:00:00+00'
    )::json
  )->>'code',
  'VALIDATION_ERROR',
  '10.14A: get_dispo_kpis_v1 rejects date_to before date_from'
);

SELECT is(
  (
    public.get_dispo_kpis_v1(
      '2026-05-01 00:00:00+00'::timestamptz,
      '2026-05-31 23:59:59+00'::timestamptz
    )::json
  )->>'code',
  'OK',
  '10.14A: get_dispo_kpis_v1 returns OK for May 2026 window'
);

SELECT is(
  (
    public.get_dispo_kpis_v1(
      '2026-05-01 00:00:00+00'::timestamptz,
      '2026-05-31 23:59:59+00'::timestamptz
    )::json
  )->'data'->>'deals_moved_to_tc',
  '2',
  '10.14A: deals_moved_to_tc counts only TC handoff rows in window'
);

SELECT is(
  (
    public.get_dispo_kpis_v1(
      '2026-05-01 00:00:00+00'::timestamptz,
      '2026-05-31 23:59:59+00'::timestamptz
    )::json
  )->'data'->>'deposit_collected',
  '2',
  '10.14A: deposit_collected counts deposit_received completions in window'
);

SELECT is(
  (
    public.get_dispo_kpis_v1(
      '2026-05-01 00:00:00+00'::timestamptz,
      '2026-05-31 23:59:59+00'::timestamptz
    )::json
  )->'data'->>'avg_assignment_fee',
  '15000.00',
  '10.14A: avg_assignment_fee is mean of assignment_fee on current dispo deals with fee'
);

SELECT is(
  (public.list_dispo_dashboard_deals_v1()::json)->>'code',
  'OK',
  '10.14A: list_dispo_dashboard_deals_v1 returns OK'
);

SELECT is(
  json_array_length(COALESCE((public.list_dispo_dashboard_deals_v1()::json)->'data'->'items', '[]'::json)),
  3,
  '10.14A: list returns three dispo deals for tenant A (excludes analyzing)'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM json_array_elements(
      COALESCE((public.list_dispo_dashboard_deals_v1()::json)->'data'->'items', '[]'::json)
    ) AS t(elem)
    WHERE (elem->>'id') = 'd14a0000-0000-4000-8000-000000000004'
  ),
  '10.14A: analyzing deal is not in Dispo dashboard list'
);

SELECT is(
  (
    (public.list_dispo_dashboard_deals_v1()::json)->'data'->'items'->0->'share_link'->>'status'
  ),
  'active',
  '10.14A: first row (newest updated_at) has active share link'
);

SELECT is(
  (public.list_dispo_dashboard_deals_v1()::json)->'data'->'items'->0->>'id',
  'd14a0000-0000-4000-8000-000000000001',
  '10.14A: newest dispo deal by updated_at is listed first'
);

SELECT is(
  (
    (public.list_dispo_dashboard_deals_v1()::json)->'data'->'items'->1->'share_link'->>'status'
  ),
  'none',
  '10.14A: second row has no share tokens (status none)'
);

SELECT is(
  (
    (public.list_dispo_dashboard_deals_v1()::json)->'data'->'items'->0->'buyer_interest'->>'schema_version'
  ),
  '1',
  '10.14A: buyer_interest schema_version is 1'
);

SELECT is(
  json_array_length(
    (public.list_dispo_dashboard_deals_v1()::json)->'data'->'items'->0->'buyer_interest'->'signals'
  ),
  0,
  '10.14A: buyer_interest.signals is empty array (deterministic v1)'
);

SELECT ok(
  (
    (public.list_dispo_dashboard_deals_v1()::json)->'data'->'items'->0->'activity'->>'entry_count'
  )::bigint >= 2,
  '10.14A: activity teaser entry_count includes seeded rows'
);

SELECT is(
  (
    public.handoff_to_tc_v1(
      'd14a0000-0000-4000-8000-000000000004'::uuid,
      NULL::uuid
    )::json
  )->>'code',
  'CONFLICT',
  '10.14A: handoff_to_tc_v1 rejects non-dispo stage'
);

SET LOCAL ROLE postgres;

UPDATE public.deals
SET assignment_agreement_signed_at = '2026-05-01 08:00:00+00'::timestamptz,
    earnest_money_received_at     = '2026-05-01 09:00:00+00'::timestamptz
WHERE id = 'd14a0000-0000-4000-8000-000000000003'::uuid;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a14a0000-0000-4000-8000-0000000000a1","role":"authenticated","tenant_id":"b14a0000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (
    public.handoff_to_tc_v1(
      'd14a0000-0000-4000-8000-000000000003'::uuid,
      NULL::uuid
    )::json
  )->>'ok',
  'true',
  '10.14A: handoff_to_tc_v1 succeeds from dispo'
);

SET LOCAL ROLE postgres;

SELECT is(
  (SELECT stage FROM public.deals WHERE id = 'd14a0000-0000-4000-8000-000000000003'::uuid),
  'tc',
  '10.14A: handoff_to_tc_v1 persists tc stage on deal'
);

SELECT is(
  (
    SELECT COUNT(*)::text
    FROM public.deal_activity_log
    WHERE deal_id = 'd14a0000-0000-4000-8000-000000000003'::uuid
      AND tenant_id = 'b14a0000-0000-4000-8000-000000000001'::uuid
      AND activity_type = 'handoff'
      AND content = 'Deal handed off to TC'
  ),
  '1',
  '10.14A: handoff_to_tc_v1 inserts TC handoff activity row'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a14a0000-0000-4000-8000-0000000000a1","role":"authenticated","tenant_id":"b14a0000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  json_array_length(COALESCE((public.list_dispo_dashboard_deals_v1()::json)->'data'->'items', '[]'::json)),
  2,
  '10.14A: after handoff, dispo list drops tc-stage deal'
);

SET LOCAL ROLE postgres;

UPDATE public.user_profiles
SET current_tenant_id = NULL
WHERE id = 'a14a0000-0000-4000-8000-0000000000a1'::uuid;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a14a0000-0000-4000-8000-000000000099","role":"authenticated","tenant_id":"b14a0000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.get_dispo_kpis_v1()::json)->>'code',
  'NOT_AUTHORIZED',
  '10.14A: user without membership cannot read Dispo KPIs'
);

SELECT is(
  (public.list_dispo_dashboard_deals_v1()::json)->>'code',
  'NOT_AUTHORIZED',
  '10.14A: user without membership cannot list Dispo deals'
);

SELECT is(
  (public.handoff_to_tc_v1('d14a0000-0000-4000-8000-000000000001'::uuid, NULL::uuid)::json)->>'code',
  'NOT_AUTHORIZED',
  '10.14A: user without membership cannot handoff to TC'
);

SET LOCAL ROLE postgres;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a14a0000-0000-4000-8000-0000000000b2","role":"authenticated","tenant_id":"b14a0000-0000-4000-8000-000000000002"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM json_array_elements(
      COALESCE((public.list_dispo_dashboard_deals_v1()::json)->'data'->'items', '[]'::json)
    ) AS t(elem)
    WHERE (elem->>'id') = 'd14a0000-0000-4000-8000-000000000001'
  ),
  '10.14A: tenant B list does not include tenant A dispo deal'
);

SELECT is(
  json_array_length(COALESCE((public.list_dispo_dashboard_deals_v1()::json)->'data'->'items', '[]'::json)),
  1,
  '10.14A: tenant B sees only its own dispo deal'
);

SELECT finish();
ROLLBACK;
