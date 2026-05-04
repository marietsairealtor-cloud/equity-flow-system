-- 10.12C: Intake Backend -- Submission Outcomes + MAO Pre-fill tests
BEGIN;

SELECT plan(22);

-- ============================================================
-- Seed tenant 1 (active)
-- ============================================================
SELECT public.create_active_workspace_seed_v1(
  'b1120000-0000-0000-0000-000000000011'::uuid,
  'a1120000-0000-0000-0000-000000000011'::uuid,
  'owner'
);

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES ('b1120000-0000-0000-0000-000000000011', 'test-outcome-01')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 1. draft_deals.address column exists
-- ============================================================
SELECT has_column('public', 'draft_deals', 'address',
  'draft_deals.address column exists');

-- ============================================================
-- 2. seller submission creates draft deal with address
-- ============================================================
SELECT public.submit_form_v1(
  'test-outcome-01', 'seller',
  '{"spam_token":"tok1","address":"789 Seller St","name":"Jane Doe","phone":"555-1111","email":"jane@example.com"}'::jsonb
);

SET LOCAL ROLE postgres;
SELECT is(
  (SELECT address FROM public.draft_deals
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND form_type = 'seller'
   ORDER BY created_at DESC LIMIT 1),
  '789 Seller St',
  'seller submission: draft_deals.address stored correctly'
);

-- ============================================================
-- 3. seller payload persists address for MAO prefill read path
-- ============================================================
SELECT is(
  (SELECT payload->>'address' FROM public.draft_deals
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND form_type = 'seller'
   ORDER BY created_at ASC LIMIT 1),
  '789 Seller St',
  'seller draft_deals.payload preserves address for MAO prefill'
);

-- ============================================================
-- 4. seller submission: asking_price is NULL (not from public intake)
-- ============================================================
SELECT is(
  (SELECT asking_price FROM public.draft_deals
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND form_type = 'seller'
   ORDER BY created_at DESC LIMIT 1),
  NULL::numeric,
  'seller submission: asking_price is NULL (governed paths only)'
);

-- ============================================================
-- 5. seller submission: repair_estimate is NULL (not from public intake)
-- ============================================================
SELECT is(
  (SELECT repair_estimate FROM public.draft_deals
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND form_type = 'seller'
   ORDER BY created_at DESC LIMIT 1),
  NULL::numeric,
  'seller submission: repair_estimate is NULL (governed paths only)'
);

-- ============================================================
-- 6. buyer submission creates intake_buyers record
-- ============================================================
SELECT public.submit_form_v1(
  'test-outcome-01', 'buyer',
  '{"spam_token":"tok2","name":"Alice Buyer","email":"alice@buyer.com","phone":"555-2222","areas_of_interest":"Downtown","budget_range":"200000-300000"}'::jsonb
);

SET LOCAL ROLE postgres;
SELECT is(
  (SELECT count(*)::int FROM public.intake_buyers
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND lower(email) = 'alice@buyer.com'),
  1,
  'buyer submission: intake_buyers record created'
);

-- ============================================================
-- 7. buyer submission: buyer fields stored correctly
-- ============================================================
SELECT is(
  (SELECT name FROM public.intake_buyers
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND lower(email) = 'alice@buyer.com'),
  'Alice Buyer',
  'buyer submission: name stored correctly'
);

-- ============================================================
-- 8. buyer dedupe: same email resubmit updates existing record
-- ============================================================
SELECT public.submit_form_v1(
  'test-outcome-01', 'buyer',
  '{"spam_token":"tok3","name":"Alice Updated","email":"alice@buyer.com","phone":"555-2222","budget_range":"300000-400000"}'::jsonb
);

SET LOCAL ROLE postgres;
SELECT is(
  (SELECT count(*)::int FROM public.intake_buyers
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND lower(email) = 'alice@buyer.com'),
  1,
  'buyer dedupe: same email resubmit updates record, not inserts new'
);

-- ============================================================
-- 9. buyer dedupe: updated fields reflect latest submission
-- ============================================================
SELECT is(
  (SELECT budget_range FROM public.intake_buyers
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND lower(email) = 'alice@buyer.com'),
  '300000-400000',
  'buyer dedupe: budget_range updated on resubmit'
);

-- ============================================================
-- 10. buyer dedupe: email present + no email match = new record (no phone merge)
-- ============================================================
SELECT public.submit_form_v1(
  'test-outcome-01', 'buyer',
  '{"spam_token":"tok4","name":"Bob Different","email":"bob@different.com","phone":"555-2222"}'::jsonb
);

SET LOCAL ROLE postgres;
SELECT is(
  (SELECT count(*)::int FROM public.intake_buyers
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND lower(email) = 'bob@different.com'),
  1,
  'buyer dedupe: new buyer created for bob@different.com'
);

SELECT is(
  (SELECT count(*)::int FROM public.intake_buyers
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND lower(email) = 'alice@buyer.com'),
  1,
  'buyer dedupe: Alice row remains singleton after Bob added'
);

-- ============================================================
-- 11. buyer dedupe: phone fallback only when email absent
--     (matches upsert_buyer_from_intake_v1 ORDER BY created_at DESC, id DESC —
--      assert observable outcome: one merged row renamed, sibling row unchanged.)
-- ============================================================
SELECT public.submit_form_v1(
  'test-outcome-01', 'buyer',
  '{"spam_token":"tok5","name":"Phone Only","phone":"555-2222"}'::jsonb
);

SET LOCAL ROLE postgres;
SELECT is(
  (SELECT sum((ib.name = 'Phone Only')::int)::int FROM public.intake_buyers ib
   WHERE ib.tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND ib.phone = '555-2222'),
  1,
  'buyer dedupe: exactly one shared-phone buyer row renamed on phone fallback merge'
);

SELECT is(
  (SELECT sum((ib.name IN ('Alice Updated','Bob Different'))::int)::int FROM public.intake_buyers ib
   WHERE ib.tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND ib.phone = '555-2222'),
  1,
  'buyer dedupe: sibling shared-phone buyer row left unchanged during phone merge'
);

-- ============================================================
-- 12. buyer dedupe: email case-insensitive match
-- ============================================================
SELECT public.submit_form_v1(
  'test-outcome-01', 'buyer',
  '{"spam_token":"tok6","name":"Alice Caps","email":"ALICE@BUYER.COM","phone":"555-2222"}'::jsonb
);

SET LOCAL ROLE postgres;
SELECT is(
  (SELECT count(*)::int FROM public.intake_buyers
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND lower(email) = 'alice@buyer.com'),
  1,
  'buyer dedupe: email match is case-insensitive'
);

-- ============================================================
-- 13. birddog submission: no buyer record created
-- ============================================================
SELECT public.submit_form_v1(
  'test-outcome-01', 'birddog',
  '{"spam_token":"tok7","address":"111 Bird St","name":"Carl Birddog","phone":"555-3333","email":"carl@birddog.com"}'::jsonb
);

SET LOCAL ROLE postgres;
SELECT is(
  (SELECT count(*)::int FROM public.intake_buyers
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND lower(email) = 'carl@birddog.com'),
  0,
  'birddog submission: no intake_buyers record created'
);

-- ============================================================
-- 14. birddog submission: intake_submissions record created
-- ============================================================
SELECT is(
  (SELECT count(*)::int FROM public.intake_submissions
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND form_type = 'birddog'),
  1,
  'birddog submission: intake_submissions record persisted'
);

-- ============================================================
-- 15. birddog submission: no draft deal pricing side effects
-- ============================================================
SELECT is(
  (SELECT asking_price FROM public.draft_deals
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND form_type = 'birddog'
   ORDER BY created_at DESC LIMIT 1),
  NULL::numeric,
  'birddog submission: asking_price is NULL on draft deal'
);

-- ============================================================
-- 16. submit_form_v1 returns draft_id on seller success
-- ============================================================
SELECT isnt(
  (public.submit_form_v1(
    'test-outcome-01', 'seller',
    '{"spam_token":"tok8","address":"999 Return St","name":"Test","phone":"555-0000","email":"test@test.com"}'::jsonb
  )->'data'->>'draft_id'),
  NULL,
  'submit_form_v1: returns draft_id on seller success'
);

-- ============================================================
-- 19–20. submit_form_v1 buyer_id matches intake_buyers (create + resubmit)
-- ============================================================
SET LOCAL ROLE postgres;
CREATE TEMP TABLE _12c_return_buyer_submit_a AS
SELECT public.submit_form_v1(
  'test-outcome-01', 'buyer',
  '{"spam_token":"tok9","name":"Return Buyer","email":"return@buyer.com","phone":"555-9999"}'::jsonb
) AS resp;

SELECT is(
  (SELECT resp->'data'->>'buyer_id' FROM _12c_return_buyer_submit_a),
  (SELECT ib.id::text FROM public.intake_buyers ib
   WHERE ib.tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND lower(ib.email) = 'return@buyer.com'
   LIMIT 1),
  'submit_form_v1: buyer_id matches newly created intake_buyers row'
);

CREATE TEMP TABLE _12c_return_buyer_submit_b AS
SELECT public.submit_form_v1(
  'test-outcome-01', 'buyer',
  '{"spam_token":"tok9b","name":"Return Buyer Two","email":"return@buyer.com","phone":"555-9999"}'::jsonb
) AS resp;

SELECT is(
  (SELECT resp->'data'->>'buyer_id' FROM _12c_return_buyer_submit_b),
  (SELECT ib.id::text FROM public.intake_buyers ib
   WHERE ib.tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND lower(ib.email) = 'return@buyer.com'
   LIMIT 1),
  'submit_form_v1: resubmit same email returns same buyer_id as deduped row'
);

-- ============================================================
-- 21. upsert_buyer_from_intake_v1 not callable from authenticated
-- ============================================================
SELECT set_config('request.jwt.claims',
  '{"sub":"a1120000-0000-0000-0000-000000000011","role":"authenticated","tenant_id":"b1120000-0000-0000-0000-000000000011"}',
  true);
SET LOCAL ROLE authenticated;

SELECT throws_ok(
  $$SELECT public.upsert_buyer_from_intake_v1('b1120000-0000-0000-0000-000000000011'::uuid, '{}'::jsonb)$$,
  '42501',
  NULL,
  'upsert_buyer_from_intake_v1: not callable from authenticated role'
);

-- ============================================================
-- 22. draft_deals: seller address is NULL for buyer submission
-- ============================================================
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT address FROM public.draft_deals
   WHERE tenant_id = 'b1120000-0000-0000-0000-000000000011'
     AND form_type = 'buyer'
   ORDER BY created_at DESC LIMIT 1),
  NULL::text,
  'buyer submission: draft_deals.address is NULL (address only for seller)'
);

SELECT finish();
ROLLBACK;
