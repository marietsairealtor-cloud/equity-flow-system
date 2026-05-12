-- 10.13B1: Offer Backend -- Activity log copy correction for send_offer_v1
BEGIN;

SELECT plan(6);

SELECT public.create_active_workspace_seed_v1(
  'b13c0000-0000-4000-8000-000000000001'::uuid,
  'a13c0000-0000-4000-8000-0000000000a1'::uuid,
  'member'::public.tenant_role
);

-- Tenant A: analyzing deal with assumptions snapshot
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, seller_name, updated_at, created_at)
VALUES (
  'd13c0000-0000-4000-8000-000000000001',
  'b13c0000-0000-4000-8000-000000000001',
  1, 1, 'analyzing', '800 Copy Fix Ave', 'Casey Seller', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e13c0000-0000-4000-8000-000000000001',
  'b13c0000-0000-4000-8000-000000000001',
  'd13c0000-0000-4000-8000-000000000001',
  1,
  '{"arv":310000,"repair_estimate":35000,"multiplier":0.70,"mao":181000,"assignment_fee":0}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e13c0000-0000-4000-8000-000000000001'
WHERE id = 'd13c0000-0000-4000-8000-000000000001';

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a13c0000-0000-4000-8000-0000000000a1","role":"authenticated","tenant_id":"b13c0000-0000-4000-8000-000000000001"}',
  true
);

-- Soft offer prerequisite for send_offer_v1
SELECT public.refresh_deal_soft_offer_v1(
  'd13c0000-0000-4000-8000-000000000001'::uuid,
  'idem-soft-offer-13b1-1'
);

-- 1. governed send succeeds
SELECT is(
  (public.send_offer_v1(
    'd13c0000-0000-4000-8000-000000000001'::uuid,
    'idem-send-offer-13b1-1'
  )->>'ok'),
  'true',
  '10.13B1: send_offer_v1 first call ok=true'
);

SET LOCAL ROLE postgres;

-- 2. corrected user-facing activity content exists
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.deal_activity_log al
    WHERE al.deal_id = 'd13c0000-0000-4000-8000-000000000001'::uuid
      AND al.tenant_id = 'b13c0000-0000-4000-8000-000000000001'::uuid
      AND al.activity_type = 'stage_change'
      AND al.content = 'Offer sent to seller'
      AND al.created_by = 'a13c0000-0000-4000-8000-0000000000a1'::uuid
  ),
  '10.13B1: stage_change activity uses corrected copy'
);

-- 3. legacy 10.13B backend-implementation copy must not appear (predicate only — NOT desired text)
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.deal_activity_log al
    WHERE al.deal_id = 'd13c0000-0000-4000-8000-000000000001'::uuid
      AND al.tenant_id = 'b13c0000-0000-4000-8000-000000000001'::uuid
      AND al.content = 'Offer sent (governed send_offer_v1); follow-up reminder scheduled'
  ),
  '10.13B1: legacy governed-copy activity content absent'
);

SET LOCAL ROLE authenticated;

-- 4. idempotent replay returns verbatim jsonb
SELECT ok(
  public.send_offer_v1(
    'd13c0000-0000-4000-8000-000000000001'::uuid,
    'idem-send-offer-13b1-1'
  )
  =
  public.send_offer_v1(
    'd13c0000-0000-4000-8000-000000000001'::uuid,
    'idem-send-offer-13b1-1'
  ),
  '10.13B1: duplicate idempotency key returns verbatim jsonb'
);

SET LOCAL ROLE postgres;

-- 5. idempotent replay does not duplicate reminder rows
SELECT is(
  (SELECT COUNT(*)::int
   FROM public.deal_reminders r
   WHERE r.deal_id = 'd13c0000-0000-4000-8000-000000000001'::uuid
     AND r.reminder_type = 'offer_follow_up'),
  1,
  '10.13B1: one offer_follow_up reminder after idempotent replay'
);

-- 6. idempotent replay does not duplicate stage_change activity rows
SELECT is(
  (SELECT COUNT(*)::int
   FROM public.deal_activity_log al
   WHERE al.deal_id = 'd13c0000-0000-4000-8000-000000000001'::uuid
     AND al.tenant_id = 'b13c0000-0000-4000-8000-000000000001'::uuid
     AND al.activity_type = 'stage_change'
     AND al.content = 'Offer sent to seller'),
  1,
  '10.13B1: one corrected stage_change activity row after idempotent replay'
);

SELECT finish();
ROLLBACK;
