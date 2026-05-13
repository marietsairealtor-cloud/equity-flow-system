-- 10.14B: Dispo Backend — Share Link + Handoff Control
-- Handoff gates + return_to_acq activity + share-token create/revoke/lookup (NOT_FOUND envelope parity).
BEGIN;

SELECT plan(20);

SELECT public.create_active_workspace_seed_v1(
  'b14b0000-0000-4000-8000-000000000001'::uuid,
  'a14b0000-0000-4000-8000-0000000000a1'::uuid,
  'member'::public.tenant_role
);

SELECT public.create_active_workspace_seed_v1(
  'b14b0000-0000-4000-8000-000000000001'::uuid,
  'a14b0000-0000-4000-8000-0000000000a2'::uuid,
  'member'::public.tenant_role
);

INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES (
  'a14b0000-0000-4000-8000-000000000099'::uuid,
  'seed_10_14b_external@test.local',
  now(), now(), '{}', '{}', 'authenticated', 'authenticated'
)
ON CONFLICT DO NOTHING;

SET LOCAL ROLE postgres;

INSERT INTO public.deals (
  id,
  tenant_id,
  row_version,
  calc_version,
  stage,
  address,
  updated_at,
  created_at,
  assignment_agreement_signed_at,
  earnest_money_received_at
)
VALUES
  (
    'd14b0000-0000-4000-8000-000000000001'::uuid,
    'b14b0000-0000-4000-8000-000000000001'::uuid,
    1,
    1,
    'dispo',
    '10.14B no prerequisites',
    now(),
    now(),
    NULL,
    NULL
  ),
  (
    'd14b0000-0000-4000-8000-000000000002'::uuid,
    'b14b0000-0000-4000-8000-000000000001'::uuid,
    1,
    1,
    'dispo',
    '10.14B assignment signed only',
    now(),
    now(),
    '2026-05-01 10:00:00+00'::timestamptz,
    NULL
  ),
  (
    'd14b0000-0000-4000-8000-000000000003'::uuid,
    'b14b0000-0000-4000-8000-000000000001'::uuid,
    1,
    1,
    'dispo',
    '10.14B earnest only',
    now(),
    now(),
    NULL,
    '2026-05-01 10:00:00+00'::timestamptz
  ),
  (
    'd14b0000-0000-4000-8000-000000000004'::uuid,
    'b14b0000-0000-4000-8000-000000000001'::uuid,
    1,
    1,
    'dispo',
    '10.14B handoff null assignee',
    now(),
    now(),
    '2026-05-01 11:00:00+00'::timestamptz,
    '2026-05-01 12:00:00+00'::timestamptz
  ),
  (
    'd14b0000-0000-4000-8000-000000000005'::uuid,
    'b14b0000-0000-4000-8000-000000000001'::uuid,
    1,
    1,
    'dispo',
    '10.14B handoff with assignee',
    now(),
    now(),
    '2026-05-01 13:00:00+00'::timestamptz,
    '2026-05-01 14:00:00+00'::timestamptz
  ),
  (
    'd14b0000-0000-4000-8000-000000000006'::uuid,
    'b14b0000-0000-4000-8000-000000000001'::uuid,
    1,
    1,
    'dispo',
    '10.14B return to acq',
    now(),
    now(),
    '2026-05-01 15:00:00+00'::timestamptz,
    '2026-05-01 16:00:00+00'::timestamptz
  ),
  (
    'd14b0000-0000-4000-8000-000000000007'::uuid,
    'b14b0000-0000-4000-8000-000000000001'::uuid,
    1,
    1,
    'dispo',
    '10.14B invalid assignee',
    now(),
    now(),
    '2026-05-01 17:00:00+00'::timestamptz,
    '2026-05-01 18:00:00+00'::timestamptz
  ),
  (
    'd14b0000-0000-4000-8000-000000000008'::uuid,
    'b14b0000-0000-4000-8000-000000000001'::uuid,
    1,
    1,
    'dispo',
    '10.14B share token expired/revoked seeds',
    now(),
    now(),
    '2026-05-01 19:00:00+00'::timestamptz,
    '2026-05-01 20:00:00+00'::timestamptz
  ),
  (
    'd14b0000-0000-4000-8000-000000000009'::uuid,
    'b14b0000-0000-4000-8000-000000000001'::uuid,
    1,
    1,
    'dispo',
    '10.14B share token revoke path',
    now(),
    now(),
    '2026-05-01 21:00:00+00'::timestamptz,
    '2026-05-01 22:00:00+00'::timestamptz
  ),
  (
    'd14b0000-0000-4000-8000-000000000010'::uuid,
    'b14b0000-0000-4000-8000-000000000001'::uuid,
    1,
    1,
    'dispo',
    '10.14B create_share_token_v1 target',
    now(),
    now(),
    '2026-05-01 23:00:00+00'::timestamptz,
    '2026-05-02 00:00:00+00'::timestamptz
  );

INSERT INTO public.share_tokens (tenant_id, deal_id, token_hash, expires_at, revoked_at)
VALUES
  (
    'b14b0000-0000-4000-8000-000000000001'::uuid,
    'd14b0000-0000-4000-8000-000000000008'::uuid,
    extensions.digest('shr_' || repeat('b', 64), 'sha256'),
    now() - interval '2 days',
    NULL
  ),
  (
    'b14b0000-0000-4000-8000-000000000001'::uuid,
    'd14b0000-0000-4000-8000-000000000008'::uuid,
    extensions.digest('shr_' || repeat('c', 64), 'sha256'),
    now() + interval '365 days',
    now() - interval '1 hour'
  ),
  (
    'b14b0000-0000-4000-8000-000000000001'::uuid,
    'd14b0000-0000-4000-8000-000000000009'::uuid,
    extensions.digest('shr_' || repeat('e', 64), 'sha256'),
    now() + interval '60 days',
    NULL
  );

SELECT has_table(
  'public',
  'workspace_handoff_notifications',
  '10.14B: workspace_handoff_notifications exists'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a14b0000-0000-4000-8000-0000000000a1","role":"authenticated","tenant_id":"b14b0000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (
    public.create_share_token_v1(
      'd14b0000-0000-4000-8000-000000000010'::uuid,
      now() + interval '30 days'
    )::json
  )->>'code',
  'OK',
  '10.14B: create_share_token_v1 returns OK for Dispo deal'
);

SELECT is(
  (
    public.lookup_share_token_v1(
      'shr_' || repeat('e', 64),
      'd14b0000-0000-4000-8000-000000000009'::uuid
    )::json
  )->>'code',
  'OK',
  '10.14B: lookup_share_token_v1 returns OK for active seeded token'
);

SELECT is(
  (
    public.revoke_share_token_v1('shr_' || repeat('e', 64))::json
  )->>'code',
  'OK',
  '10.14B: revoke_share_token_v1 returns OK for active token'
);

SELECT is(
  (
    public.lookup_share_token_v1(
      'shr_' || repeat('e', 64),
      'd14b0000-0000-4000-8000-000000000009'::uuid
    )::json
  )::text,
  (
    public.lookup_share_token_v1(
      'shr_' || repeat('f', 64),
      'd14b0000-0000-4000-8000-000000000009'::uuid
    )::json
  )::text,
  '10.14B: lookup_share_token_v1 revoked vs unknown token identical response envelope'
);

SELECT is(
  (
    public.lookup_share_token_v1(
      'shr_' || repeat('b', 64),
      'd14b0000-0000-4000-8000-000000000008'::uuid
    )::json
  )::text,
  (
    public.lookup_share_token_v1(
      'shr_' || repeat('d', 64),
      'd14b0000-0000-4000-8000-000000000008'::uuid
    )::json
  )::text,
  '10.14B: lookup_share_token_v1 expired vs unknown token identical response envelope'
);

SELECT is(
  (
    public.lookup_share_token_v1(
      'shr_' || repeat('c', 64),
      'd14b0000-0000-4000-8000-000000000008'::uuid
    )::json
  )::text,
  (
    public.lookup_share_token_v1(
      'shr_' || repeat('d', 64),
      'd14b0000-0000-4000-8000-000000000008'::uuid
    )::json
  )::text,
  '10.14B: lookup_share_token_v1 revoked vs unknown token identical response envelope'
);

SELECT is(
  (
    public.handoff_to_tc_v1(
      'd14b0000-0000-4000-8000-000000000001'::uuid,
      NULL::uuid
    )::json
  )->>'code',
  'CONFLICT',
  '10.14B: handoff_to_tc_v1 rejects when both milestones unset'
);

SELECT ok(
  (
    (
      public.handoff_to_tc_v1(
        'd14b0000-0000-4000-8000-000000000001'::uuid,
        NULL::uuid
      )::json
    )->'error'->'fields'
  )::jsonb ? 'assignment_agreement_signed_at',
  '10.14B: missing-milestones error.fields names assignment_agreement_signed_at'
);

SELECT is(
  (
    public.handoff_to_tc_v1(
      'd14b0000-0000-4000-8000-000000000002'::uuid,
      NULL::uuid
    )::json
  )->>'code',
  'CONFLICT',
  '10.14B: handoff_to_tc_v1 rejects when earnest money timestamp unset'
);

SELECT is(
  (
    public.handoff_to_tc_v1(
      'd14b0000-0000-4000-8000-000000000003'::uuid,
      NULL::uuid
    )::json
  )->>'code',
  'CONFLICT',
  '10.14B: handoff_to_tc_v1 rejects when assignment agreement timestamp unset'
);

SELECT is(
  (
    public.handoff_to_tc_v1(
      'd14b0000-0000-4000-8000-000000000004'::uuid,
      NULL::uuid
    )::json
  )->>'ok',
  'true',
  '10.14B: handoff_to_tc_v1 succeeds when milestones set (null assignee)'
);

SET LOCAL ROLE postgres;

SELECT is(
  (SELECT stage FROM public.deals WHERE id = 'd14b0000-0000-4000-8000-000000000004'::uuid),
  'tc',
  '10.14B: handoff_to_tc_v1 moves deal to tc when gated'
);

SELECT is(
  (
    SELECT COUNT(*)::text
    FROM public.workspace_handoff_notifications
    WHERE deal_id = 'd14b0000-0000-4000-8000-000000000004'::uuid
  ),
  '0',
  '10.14B: no workspace_handoff_notifications row when assignee is null'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a14b0000-0000-4000-8000-0000000000a1","role":"authenticated","tenant_id":"b14b0000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (
    public.handoff_to_tc_v1(
      'd14b0000-0000-4000-8000-000000000005'::uuid,
      'a14b0000-0000-4000-8000-0000000000a2'::uuid
    )::json
  )->>'ok',
  'true',
  '10.14B: handoff_to_tc_v1 succeeds with assignee when milestones set'
);

SET LOCAL ROLE postgres;

SELECT is(
  (
    SELECT COUNT(*)::text
    FROM public.workspace_handoff_notifications
    WHERE deal_id = 'd14b0000-0000-4000-8000-000000000005'::uuid
      AND recipient_user_id = 'a14b0000-0000-4000-8000-0000000000a2'::uuid
      AND kind = 'handoff_to_tc'
  ),
  '1',
  '10.14B: assignee receives workspace_handoff_notifications row on handoff'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a14b0000-0000-4000-8000-0000000000a1","role":"authenticated","tenant_id":"b14b0000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (
    public.handoff_to_tc_v1(
      'd14b0000-0000-4000-8000-000000000007'::uuid,
      'a14b0000-0000-4000-8000-000000000099'::uuid
    )::json
  )->>'code',
  'VALIDATION_ERROR',
  '10.14B: handoff_to_tc_v1 rejects assignee not in workspace'
);

SELECT is(
  (
    public.return_to_acq_v1('d14b0000-0000-4000-8000-000000000006'::uuid)::json
  )->>'ok',
  'true',
  '10.14B: return_to_acq_v1 succeeds from dispo'
);

SET LOCAL ROLE postgres;

SELECT is(
  (SELECT stage FROM public.deals WHERE id = 'd14b0000-0000-4000-8000-000000000006'::uuid),
  'under_contract',
  '10.14B: return_to_acq_v1 persists under_contract'
);

SELECT is(
  (
    SELECT COUNT(*)::text
    FROM public.deal_activity_log
    WHERE deal_id = 'd14b0000-0000-4000-8000-000000000006'::uuid
      AND tenant_id = 'b14b0000-0000-4000-8000-000000000001'::uuid
      AND activity_type = 'handoff'
      AND content = 'Deal returned to Acq from Dispo'
  ),
  '1',
  '10.14B: return_to_acq_v1 writes governed activity log row'
);

SELECT finish();
ROLLBACK;
