-- 10.13B: Offer Backend -- send_offer_v1 (governed send path + reminder + activity + idempotency)
BEGIN;

SELECT plan(14);

SELECT public.create_active_workspace_seed_v1(
  'b13b0000-0000-4000-8000-000000000001'::uuid,
  'a13b0000-0000-4000-8000-0000000000a1'::uuid,
  'member'::public.tenant_role
);

SELECT public.create_active_workspace_seed_v1(
  'b13b0000-0000-4000-8000-000000000002'::uuid,
  'a13b0000-0000-4000-8000-0000000000b2'::uuid,
  'member'::public.tenant_role
);

-- Tenant A: analyzing deal + snapshot (happy path + idempotent replay)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, seller_name, updated_at, created_at)
VALUES (
  'd13b0000-0000-4000-8000-000000000001',
  'b13b0000-0000-4000-8000-000000000001',
  1, 1, 'analyzing', '700 Send Offer Rd', 'Sam Seller', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e13b0000-0000-4000-8000-000000000001',
  'b13b0000-0000-4000-8000-000000000001',
  'd13b0000-0000-4000-8000-000000000001',
  1,
  '{"arv":300000,"repair_estimate":30000,"multiplier":0.70,"mao":180000,"assignment_fee":0}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e13b0000-0000-4000-8000-000000000001'
WHERE id = 'd13b0000-0000-4000-8000-000000000001';

-- Tenant A: analyzing but no deal_soft_offers row (send blocked)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, seller_name, updated_at, created_at)
VALUES (
  'd13b0000-0000-4000-8000-000000000002',
  'b13b0000-0000-4000-8000-000000000001',
  1, 1, 'analyzing', '701 No Soft Offer Ln', 'Alex Seller', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e13b0000-0000-4000-8000-000000000002',
  'b13b0000-0000-4000-8000-000000000001',
  'd13b0000-0000-4000-8000-000000000002',
  1,
  '{"arv":300000,"repair_estimate":30000,"multiplier":0.70,"mao":180000}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e13b0000-0000-4000-8000-000000000002'
WHERE id = 'd13b0000-0000-4000-8000-000000000002';

-- Tenant A: wrong stage (new)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd13b0000-0000-4000-8000-000000000003',
  'b13b0000-0000-4000-8000-000000000001',
  1, 1, 'new', '702 Wrong Stage Ct', now(), now()
);

-- Tenant B: cross-tenant isolation target
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd13b0000-0000-4000-8000-000000000004',
  'b13b0000-0000-4000-8000-000000000002',
  1, 1, 'analyzing', '999 Other Tenant', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e13b0000-0000-4000-8000-000000000004',
  'b13b0000-0000-4000-8000-000000000002',
  'd13b0000-0000-4000-8000-000000000004',
  1,
  '{"arv":200000,"repair_estimate":10000,"multiplier":0.70,"mao":130000}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e13b0000-0000-4000-8000-000000000004'
WHERE id = 'd13b0000-0000-4000-8000-000000000004';

-- 1. SECURITY DEFINER
SET LOCAL ROLE postgres;

SELECT is(
  (SELECT p.prosecdef
   FROM pg_proc p
   JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname = 'send_offer_v1'
     AND pg_get_function_identity_arguments(p.oid) = 'p_deal_id uuid, p_idempotency_key text'),
  true,
  '10.13B: send_offer_v1 is SECURITY DEFINER'
);

-- Caller: tenant A member
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a13b0000-0000-4000-8000-0000000000a1","role":"authenticated","tenant_id":"b13b0000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT public.refresh_deal_soft_offer_v1(
  'd13b0000-0000-4000-8000-000000000001'::uuid,
  'idem-soft-offer-13b-1'
);

-- 2. empty idempotency key
SELECT is(
  (public.send_offer_v1('d13b0000-0000-4000-8000-000000000001'::uuid, '')::jsonb->>'code'),
  'VALIDATION_ERROR',
  '10.13B: empty idempotency key => VALIDATION_ERROR'
);

-- 3. NULL deal id
SELECT is(
  (public.send_offer_v1(NULL::uuid, 'idem-send-null-deal')::jsonb->>'code'),
  'VALIDATION_ERROR',
  '10.13B: NULL p_deal_id => VALIDATION_ERROR'
);

-- 4. persisted soft offer missing
SELECT is(
  (public.send_offer_v1('d13b0000-0000-4000-8000-000000000002'::uuid, 'idem-send-no-soft')::jsonb->>'code'),
  'VALIDATION_ERROR',
  '10.13B: analyzing without deal_soft_offers => VALIDATION_ERROR'
);

-- 5. wrong stage
SELECT is(
  (public.send_offer_v1('d13b0000-0000-4000-8000-000000000003'::uuid, 'idem-send-wrong-stage')::jsonb->>'code'),
  'CONFLICT',
  '10.13B: stage not analyzing => CONFLICT'
);

-- 6. cross-tenant deal => NOT_FOUND
SELECT is(
  (public.send_offer_v1('d13b0000-0000-4000-8000-000000000004'::uuid, 'idem-send-cross')::jsonb->>'code'),
  'NOT_FOUND',
  '10.13B: send_offer_v1 cross-tenant => NOT_FOUND'
);

-- 7. first governed send succeeds
SELECT is(
  (public.send_offer_v1(
    'd13b0000-0000-4000-8000-000000000001'::uuid,
    'idem-send-offer-1'
  )->>'ok'),
  'true',
  '10.13B: send_offer_v1 first call ok=true'
);

SET LOCAL ROLE postgres;

-- 8. deal stage advanced
SELECT is(
  (SELECT stage FROM public.deals WHERE id = 'd13b0000-0000-4000-8000-000000000001'::uuid),
  'offer_sent',
  '10.13B: send_offer_v1 advances stage to offer_sent'
);

-- 9. follow-up reminder row
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.deal_reminders r
    WHERE r.deal_id = 'd13b0000-0000-4000-8000-000000000001'::uuid
      AND r.tenant_id = 'b13b0000-0000-4000-8000-000000000001'::uuid
      AND r.reminder_type = 'offer_follow_up'
      AND r.completed_at IS NULL
  ),
  '10.13B: offer_follow_up reminder inserted'
);

-- 10. activity log (stage_change)
-- Full chain: 000005 has already redefined send_offer_v1, so the row matches 10.13B1 copy.
-- Legacy governed wording is asserted absent in 10_13B1_offer_activity_log_copy_correction.test.sql.
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.deal_activity_log al
    WHERE al.deal_id = 'd13b0000-0000-4000-8000-000000000001'::uuid
      AND al.tenant_id = 'b13b0000-0000-4000-8000-000000000001'::uuid
      AND al.activity_type = 'stage_change'
      AND al.content = 'Offer sent to seller'
      AND al.created_by = 'a13b0000-0000-4000-8000-0000000000a1'::uuid
  ),
  '10.13B: stage_change activity row for governed send'
);

SET LOCAL ROLE authenticated;

-- 11. idempotent replay returns verbatim jsonb
SELECT ok(
  public.send_offer_v1(
    'd13b0000-0000-4000-8000-000000000001'::uuid,
    'idem-send-offer-1'
  )
  =
  public.send_offer_v1(
    'd13b0000-0000-4000-8000-000000000001'::uuid,
    'idem-send-offer-1'
  ),
  '10.13B: duplicate idempotency key returns verbatim jsonb'
);

SET LOCAL ROLE postgres;

-- 12. single reminder for deal after replay
SELECT is(
  (SELECT COUNT(*)::int
   FROM public.deal_reminders r
   WHERE r.deal_id = 'd13b0000-0000-4000-8000-000000000001'::uuid
     AND r.reminder_type = 'offer_follow_up'),
  1,
  '10.13B: one offer_follow_up reminder after idempotent replay'
);

SET LOCAL ROLE authenticated;

-- 13. new idempotency key after send => CONFLICT (already sent)
SELECT is(
  (public.send_offer_v1(
    'd13b0000-0000-4000-8000-000000000001'::uuid,
    'idem-send-offer-2'
  )->>'code'),
  'CONFLICT',
  '10.13B: second send with new key after offer_sent => CONFLICT'
);

SET LOCAL ROLE postgres;

-- 14. EXECUTE: authenticated only
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.send_offer_v1(uuid, text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.send_offer_v1(uuid, text)',
    'EXECUTE'
  ),
  '10.13B: send_offer_v1 EXECUTE authenticated only (not anon)'
);

SELECT finish();
ROLLBACK;
