-- 10.13A: Offer Backend -- get_offer_payload_v1 + refresh_deal_soft_offer_v1 + deal_soft_offers
BEGIN;

SELECT plan(14);

SELECT public.create_active_workspace_seed_v1(
  'b13a0000-0000-4000-8000-000000000001'::uuid,
  'a13a0000-0000-4000-8000-0000000000a1'::uuid,
  'member'::public.tenant_role
);

SELECT public.create_active_workspace_seed_v1(
  'b13a0000-0000-4000-8000-000000000002'::uuid,
  'a13a0000-0000-4000-8000-0000000000b2'::uuid,
  'member'::public.tenant_role
);

-- Tenant A: valid snapshot + MAO
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, seller_name, updated_at, created_at)
VALUES (
  'd13a0000-0000-4000-8000-000000000001',
  'b13a0000-0000-4000-8000-000000000001',
  1, 1, 'analyzing', '100 Offer Ln', 'Pat Seller', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e13a0000-0000-4000-8000-000000000001',
  'b13a0000-0000-4000-8000-000000000001',
  'd13a0000-0000-4000-8000-000000000001',
  1,
  '{"arv":300000,"repair_estimate":30000,"multiplier":0.70,"mao":180000,"assignment_fee":0}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e13a0000-0000-4000-8000-000000000001'
WHERE id = 'd13a0000-0000-4000-8000-000000000001';

-- Tenant A: invalid mao string on snapshot
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd13a0000-0000-4000-8000-000000000002',
  'b13a0000-0000-4000-8000-000000000001',
  1, 1, 'analyzing', '200 Bad Mao Rd', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e13a0000-0000-4000-8000-000000000002',
  'b13a0000-0000-4000-8000-000000000001',
  'd13a0000-0000-4000-8000-000000000002',
  1,
  '{"arv":300000,"repair_estimate":30000,"multiplier":0.70,"mao":"not-a-number","assignment_fee":0}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e13a0000-0000-4000-8000-000000000002'
WHERE id = 'd13a0000-0000-4000-8000-000000000002';

-- Tenant B: cross-tenant isolation target
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at)
VALUES (
  'd13a0000-0000-4000-8000-000000000003',
  'b13a0000-0000-4000-8000-000000000002',
  1, 1, 'analyzing', '999 Other Tenant', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e13a0000-0000-4000-8000-000000000003',
  'b13a0000-0000-4000-8000-000000000002',
  'd13a0000-0000-4000-8000-000000000003',
  1,
  '{"arv":200000,"repair_estimate":10000,"multiplier":0.70,"mao":130000}'::jsonb,
  now()
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e13a0000-0000-4000-8000-000000000003'
WHERE id = 'd13a0000-0000-4000-8000-000000000003';

-- 1–2. SECURITY DEFINER
SET LOCAL ROLE postgres;

SELECT is(
  (SELECT p.prosecdef
   FROM pg_proc p
   JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname = 'get_offer_payload_v1'
     AND pg_get_function_identity_arguments(p.oid) = 'p_deal_id uuid'),
  true,
  '10.13A: get_offer_payload_v1 is SECURITY DEFINER'
);

SELECT is(
  (SELECT p.prosecdef
   FROM pg_proc p
   JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname = 'refresh_deal_soft_offer_v1'
     AND pg_get_function_identity_arguments(p.oid) = 'p_deal_id uuid, p_idempotency_key text'),
  true,
  '10.13A: refresh_deal_soft_offer_v1 is SECURITY DEFINER'
);

-- Caller context: tenant A, user A
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a13a0000-0000-4000-8000-0000000000a1","role":"authenticated","tenant_id":"b13a0000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

-- 3. get_offer_payload_v1 OK + deterministic mao display
SELECT is(
  (public.get_offer_payload_v1('d13a0000-0000-4000-8000-000000000001'::uuid)->>'code'),
  'OK',
  '10.13A: get_offer_payload_v1 returns OK for valid deal'
);

SELECT is(
  (
    public.get_offer_payload_v1('d13a0000-0000-4000-8000-000000000001'::uuid)
      ->'data'->'pricing'->>'mao'
  ),
  '180000',
  '10.13A: get_offer_payload_v1 pricing.mao matches authoritative snapshot'
);

-- 4. invalid mao on snapshot
SELECT is(
  (public.get_offer_payload_v1('d13a0000-0000-4000-8000-000000000002'::uuid)->>'code'),
  'VALIDATION_ERROR',
  '10.13A: invalid mao text => VALIDATION_ERROR'
);

-- 5. cross-tenant deal => NOT_FOUND
SELECT is(
  (public.get_offer_payload_v1('d13a0000-0000-4000-8000-000000000003'::uuid)->>'code'),
  'NOT_FOUND',
  '10.13A: get_offer_payload_v1 cross-tenant => NOT_FOUND'
);

-- 6. refresh missing idempotency key
SELECT is(
  (public.refresh_deal_soft_offer_v1('d13a0000-0000-4000-8000-000000000001'::uuid, '')::jsonb->>'code'),
  'VALIDATION_ERROR',
  '10.13A: refresh empty idempotency key => VALIDATION_ERROR'
);

-- 7. refresh first call succeeds (authenticated RPC)
SELECT is(
  (public.refresh_deal_soft_offer_v1(
    'd13a0000-0000-4000-8000-000000000001'::uuid,
    'idem-soft-offer-1'
  )->>'ok'),
  'true',
  '10.13A: refresh_deal_soft_offer_v1 first call ok=true'
);

-- Table has no grants to authenticated — inspect as superuser
SET LOCAL ROLE postgres;

-- 8. both soft-offer outputs generated from payload + expiration in copy_text, copy_email, expiration_clause
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.deal_soft_offers so
    WHERE so.deal_id = 'd13a0000-0000-4000-8000-000000000001'::uuid
      AND so.tenant_id = 'b13a0000-0000-4000-8000-000000000001'::uuid
      AND so.copy_text LIKE '%100 Offer Ln%'
      AND so.copy_text LIKE '%Maximum Allowable Offer (MAO): $180000%'
      AND so.copy_text LIKE '%Multiplier: 0.70%'
      AND so.copy_text LIKE '%Assignment fee: $0%'
      AND so.copy_text LIKE '%48 hours%'
      AND so.copy_email LIKE '%Subject: Soft offer - 100 Offer Ln%'
      AND so.copy_email LIKE '%Maximum Allowable Offer (MAO): $180000%'
      AND so.copy_email LIKE '%Multiplier: 0.70%'
      AND so.copy_email LIKE '%Assignment fee: $0%'
      AND so.copy_email LIKE '%48 hours%'
      AND so.expiration_clause LIKE '%48 hours%'
  ),
  '10.13A: copy_text and copy_email are generated from offer payload and include expiration clause'
);

-- 9–10. idempotent replay (authenticated RPC)
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a13a0000-0000-4000-8000-0000000000a1","role":"authenticated","tenant_id":"b13a0000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT ok(
  public.refresh_deal_soft_offer_v1(
    'd13a0000-0000-4000-8000-000000000001'::uuid,
    'idem-soft-offer-1'
  )
  =
  public.refresh_deal_soft_offer_v1(
    'd13a0000-0000-4000-8000-000000000001'::uuid,
    'idem-soft-offer-1'
  ),
  '10.13A: duplicate idempotency key returns verbatim jsonb'
);

SET LOCAL ROLE postgres;

SELECT is(
  (SELECT COUNT(*)::int FROM public.deal_soft_offers
   WHERE deal_id = 'd13a0000-0000-4000-8000-000000000001'::uuid),
  1,
  '10.13A: one deal_soft_offers row after idempotent refresh'
);

-- 11. no orphaned soft-offer rows (FK to deals)
SELECT is(
  (SELECT COUNT(*)::int
   FROM public.deal_soft_offers so
   LEFT JOIN public.deals d ON d.id = so.deal_id
   WHERE d.id IS NULL),
  0,
  '10.13A: zero orphaned deal_soft_offers (parent deal missing)'
);

-- 12–13. EXECUTE: authenticated only
SELECT ok(
  has_function_privilege('authenticated', 'public.get_offer_payload_v1(uuid)', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'public.get_offer_payload_v1(uuid)', 'EXECUTE'),
  '10.13A: get_offer_payload_v1 EXECUTE authenticated only (not anon)'
);

SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.refresh_deal_soft_offer_v1(uuid, text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.refresh_deal_soft_offer_v1(uuid, text)',
    'EXECUTE'
  ),
  '10.13A: refresh_deal_soft_offer_v1 EXECUTE authenticated only (not anon)'
);

SELECT finish();
ROLLBACK;
