-- 10.14B2: Dispo Backend -- Deal Milestone Timestamp Mutation
BEGIN;

SELECT plan(19);

SELECT public.create_active_workspace_seed_v1(
  'b14b2000-0000-4000-8000-000000000001'::uuid,
  'a14b2000-0000-4000-8000-0000000000a1'::uuid,
  'member'::public.tenant_role
);

SELECT public.create_active_workspace_seed_v1(
  'b14b2000-0000-4000-8000-000000000002'::uuid,
  'a14b2000-0000-4000-8000-0000000000b2'::uuid,
  'member'::public.tenant_role
);

INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES (
  'a14b2000-0000-4000-8000-000000000099'::uuid,
  'seed_10_14b2_nomember@test.local',
  now(), now(), '{}', '{}', 'authenticated', 'authenticated'
) ON CONFLICT DO NOTHING;

SET LOCAL ROLE postgres;

INSERT INTO public.deals (
  id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at,
  assignment_agreement_signed_at, earnest_money_received_at
) VALUES
  (
    'd14b2000-0000-4000-8000-000000000001'::uuid,
    'b14b2000-0000-4000-8000-000000000001'::uuid,
    1, 1, 'dispo', '10.14B2 Dispo Deal', now(), now(), NULL, NULL
  ),
  (
    'd14b2000-0000-4000-8000-000000000002'::uuid,
    'b14b2000-0000-4000-8000-000000000001'::uuid,
    1, 1, 'analyzing', '10.14B2 Wrong Stage Deal', now(), now(), NULL, NULL
  ),
  (
    'd14b2000-0000-4000-8000-000000000003'::uuid,
    'b14b2000-0000-4000-8000-000000000002'::uuid,
    1, 1, 'dispo', '10.14B2 Cross Tenant Deal', now(), now(), NULL, NULL
  );

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e14b2000-0000-4000-8000-000000000001'::uuid,
  'b14b2000-0000-4000-8000-000000000001'::uuid,
  'd14b2000-0000-4000-8000-000000000001'::uuid,
  1,
  '{"arv":300000,"repair_estimate":30000,"multiplier":0.70,"mao":180000}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e14b2000-0000-4000-8000-000000000001'::uuid
WHERE id = 'd14b2000-0000-4000-8000-000000000001'::uuid;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a14b2000-0000-4000-8000-0000000000a1","role":"authenticated","tenant_id":"b14b2000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

-- 1. null p_deal_id
SELECT is(
  (public.set_dispo_deal_milestone_v1(NULL::uuid, 'assignment_agreement_signed', true)::jsonb->>'code'),
  'VALIDATION_ERROR',
  '10.14B2: null p_deal_id returns VALIDATION_ERROR'
);

-- 2. null p_milestone
SELECT is(
  (public.set_dispo_deal_milestone_v1('d14b2000-0000-4000-8000-000000000001'::uuid, NULL::text, true)::jsonb->>'code'),
  'VALIDATION_ERROR',
  '10.14B2: null p_milestone returns VALIDATION_ERROR'
);

-- 3. null p_is_complete
SELECT is(
  (public.set_dispo_deal_milestone_v1('d14b2000-0000-4000-8000-000000000001'::uuid, 'assignment_agreement_signed', NULL::boolean)::jsonb->>'code'),
  'VALIDATION_ERROR',
  '10.14B2: null p_is_complete returns VALIDATION_ERROR'
);

-- 4. invalid milestone
SELECT is(
  (public.set_dispo_deal_milestone_v1('d14b2000-0000-4000-8000-000000000001'::uuid, 'bad_milestone', true)::jsonb->>'code'),
  'VALIDATION_ERROR',
  '10.14B2: invalid milestone returns VALIDATION_ERROR'
);

-- 5. non-dispo stage returns CONFLICT
SELECT is(
  (public.set_dispo_deal_milestone_v1('d14b2000-0000-4000-8000-000000000002'::uuid, 'assignment_agreement_signed', true)::jsonb->>'code'),
  'CONFLICT',
  '10.14B2: non-dispo deal returns CONFLICT'
);

-- 6. cross-tenant returns NOT_FOUND
SELECT is(
  (public.set_dispo_deal_milestone_v1('d14b2000-0000-4000-8000-000000000003'::uuid, 'assignment_agreement_signed', true)::jsonb->>'code'),
  'NOT_FOUND',
  '10.14B2: cross-tenant deal returns NOT_FOUND'
);

-- 7. set assignment_agreement_signed succeeds
SELECT is(
  (public.set_dispo_deal_milestone_v1('d14b2000-0000-4000-8000-000000000001'::uuid, 'assignment_agreement_signed', true)::jsonb->>'ok'),
  'true',
  '10.14B2: setting assignment_agreement_signed returns ok=true'
);

SET LOCAL ROLE postgres;

-- 8. assignment_agreement_signed_at is set
SELECT ok(
  (SELECT assignment_agreement_signed_at IS NOT NULL FROM public.deals WHERE id = 'd14b2000-0000-4000-8000-000000000001'::uuid),
  '10.14B2: assignment_agreement_signed_at is set'
);

SET LOCAL ROLE authenticated;

-- 9. clear assignment_agreement_signed
SELECT is(
  (public.set_dispo_deal_milestone_v1('d14b2000-0000-4000-8000-000000000001'::uuid, 'assignment_agreement_signed', false)::jsonb->>'ok'),
  'true',
  '10.14B2: clearing assignment_agreement_signed returns ok=true'
);

SET LOCAL ROLE postgres;

-- 10. assignment_agreement_signed_at is NULL after clear
SELECT ok(
  (SELECT assignment_agreement_signed_at IS NULL FROM public.deals WHERE id = 'd14b2000-0000-4000-8000-000000000001'::uuid),
  '10.14B2: assignment_agreement_signed_at is NULL after clear'
);

SET LOCAL ROLE authenticated;

-- 11. set earnest_money_received succeeds
SELECT is(
  (public.set_dispo_deal_milestone_v1('d14b2000-0000-4000-8000-000000000001'::uuid, 'earnest_money_received', true)::jsonb->>'ok'),
  'true',
  '10.14B2: setting earnest_money_received returns ok=true'
);

SET LOCAL ROLE postgres;

-- 12. earnest_money_received_at is set
SELECT ok(
  (SELECT earnest_money_received_at IS NOT NULL FROM public.deals WHERE id = 'd14b2000-0000-4000-8000-000000000001'::uuid),
  '10.14B2: earnest_money_received_at is set'
);

SET LOCAL ROLE authenticated;

-- 13. clear earnest_money_received
SELECT is(
  (public.set_dispo_deal_milestone_v1('d14b2000-0000-4000-8000-000000000001'::uuid, 'earnest_money_received', false)::jsonb->>'ok'),
  'true',
  '10.14B2: clearing earnest_money_received returns ok=true'
);

SET LOCAL ROLE postgres;

-- 14. earnest_money_received_at is NULL after clear
SELECT ok(
  (SELECT earnest_money_received_at IS NULL FROM public.deals WHERE id = 'd14b2000-0000-4000-8000-000000000001'::uuid),
  '10.14B2: earnest_money_received_at is NULL after clear'
);

-- 15. activity log row written
SELECT ok(
  EXISTS (
    SELECT 1 FROM public.deal_activity_log
    WHERE deal_id = 'd14b2000-0000-4000-8000-000000000001'::uuid
      AND tenant_id = 'b14b2000-0000-4000-8000-000000000001'::uuid
      AND activity_type = 'milestone'
  ),
  '10.14B2: activity log row written on milestone mutation'
);

SET LOCAL ROLE authenticated;

-- 16. set both milestones again for TC handoff unlock test
SELECT is(
  (public.set_dispo_deal_milestone_v1('d14b2000-0000-4000-8000-000000000001'::uuid, 'assignment_agreement_signed', true)::jsonb->>'ok'),
  'true',
  '10.14B2: assignment agreement can be set before TC handoff'
);

SELECT is(
  (public.set_dispo_deal_milestone_v1('d14b2000-0000-4000-8000-000000000001'::uuid, 'earnest_money_received', true)::jsonb->>'ok'),
  'true',
  '10.14B2: earnest money can be set before TC handoff'
);

-- 18. handoff_to_tc_v1 succeeds after both milestones set
SELECT is(
  (public.handoff_to_tc_v1('d14b2000-0000-4000-8000-000000000001'::uuid, NULL::uuid)::json->>'ok'),
  'true',
  '10.14B2: handoff_to_tc_v1 succeeds after both milestones are set'
);

-- 19. non-member cannot set milestone
SET LOCAL ROLE postgres;
UPDATE public.user_profiles
SET current_tenant_id = NULL
WHERE id = 'a14b2000-0000-4000-8000-0000000000a1'::uuid;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a14b2000-0000-4000-8000-000000000099","role":"authenticated","tenant_id":"b14b2000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.set_dispo_deal_milestone_v1('d14b2000-0000-4000-8000-000000000001'::uuid, 'assignment_agreement_signed', true)::jsonb->>'code'),
  'NOT_AUTHORIZED',
  '10.14B2: non-member returns NOT_AUTHORIZED'
);

SELECT finish();
ROLLBACK;