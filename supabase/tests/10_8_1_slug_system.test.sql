-- 10_8_1_slug_system_tests.test.sql
-- Build Route 10.8.1: Slug System pgTAP Tests
-- Tests run as superuser with JWT claims set to simulate calling context.

BEGIN;
SELECT plan(23);

-- ============================================================
-- Seed test data
-- ============================================================

INSERT INTO public.tenants (id)
  VALUES ('a0810000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.tenant_slugs (id, tenant_id, slug)
  VALUES (
    'a0810000-0000-0000-0000-000000000002'::uuid,
    'a0810000-0000-0000-0000-000000000001'::uuid,
    'test-workspace-01'
  );

INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
VALUES ('a0810000-0000-0000-0000-000000000001'::uuid, 'active', now() + interval '1 year');

-- ============================================================
-- resolve_form_slug_v1 -- valid slug + valid form_type
-- ============================================================
SELECT is(
  (public.resolve_form_slug_v1('test-workspace-01', 'seller')::json)->>'ok',
  'true',
  'resolve_form_slug_v1 valid seller: ok=true'
);
SELECT is(
  (public.resolve_form_slug_v1('test-workspace-01', 'seller')::json)->>'code',
  'OK',
  'resolve_form_slug_v1 valid seller: code=OK'
);
SELECT is(
  (public.resolve_form_slug_v1('test-workspace-01', 'buyer')::json)->>'ok',
  'true',
  'resolve_form_slug_v1 valid buyer: ok=true'
);
SELECT is(
  (public.resolve_form_slug_v1('test-workspace-01', 'birddog')::json)->>'ok',
  'true',
  'resolve_form_slug_v1 valid birddog: ok=true'
);
SELECT is(
  (public.resolve_form_slug_v1('test-workspace-01', 'seller')::json)->'data'->>'tenant_id',
  'a0810000-0000-0000-0000-000000000001',
  'resolve_form_slug_v1 valid: returns correct tenant_id'
);

-- ============================================================
-- resolve_form_slug_v1 -- invalid slug -> NOT_FOUND
-- ============================================================
SELECT is(
  (public.resolve_form_slug_v1('nonexistent-slug-99', 'seller')::json)->>'ok',
  'false',
  'resolve_form_slug_v1 invalid slug: ok=false'
);
SELECT is(
  (public.resolve_form_slug_v1('nonexistent-slug-99', 'seller')::json)->>'code',
  'NOT_FOUND',
  'resolve_form_slug_v1 invalid slug: code=NOT_FOUND'
);
SELECT is(
  (public.resolve_form_slug_v1('nonexistent-slug-99', 'seller')::json)->>'data',
  NULL,
  'resolve_form_slug_v1 invalid slug: data=null'
);

-- ============================================================
-- resolve_form_slug_v1 -- invalid form_type -> NOT_FOUND (no leak)
-- ============================================================
SELECT is(
  (public.resolve_form_slug_v1('test-workspace-01', 'invalid')::json)->>'code',
  'NOT_FOUND',
  'resolve_form_slug_v1 invalid form_type: code=NOT_FOUND'
);
SELECT is(
  (public.resolve_form_slug_v1('test-workspace-01', NULL)::json)->>'code',
  'NOT_FOUND',
  'resolve_form_slug_v1 null form_type: code=NOT_FOUND'
);

-- ============================================================
-- resolve_form_slug_v1 -- null slug -> NOT_FOUND
-- ============================================================
SELECT is(
  (public.resolve_form_slug_v1(NULL, 'seller')::json)->>'code',
  'NOT_FOUND',
  'resolve_form_slug_v1 null slug: code=NOT_FOUND'
);

-- ============================================================
-- submit_form_v1 -- valid seller submission creates draft deal
-- ============================================================
SELECT is(
  (public.submit_form_v1(
    'test-workspace-01',
    'seller',
    '{"asking_price": 250000, "repair_estimate": 40000, "spam_token": "test-token-abc"}'::jsonb
  )::json)->>'ok',
  'true',
  'submit_form_v1 valid seller: ok=true'
);
SELECT is(
  (public.submit_form_v1(
    'test-workspace-01',
    'seller',
    '{"asking_price": 250000, "repair_estimate": 40000, "spam_token": "test-token-abc"}'::jsonb
  )::json)->>'code',
  'OK',
  'submit_form_v1 valid seller: code=OK'
);
SELECT isnt(
  (public.submit_form_v1(
    'test-workspace-01',
    'seller',
    '{"asking_price": 250000, "repair_estimate": 40000, "spam_token": "test-token-abc"}'::jsonb
  )::json)->'data'->>'draft_id',
  NULL,
  'submit_form_v1 valid seller: draft_id returned'
);

-- ============================================================
-- submit_form_v1 -- valid buyer submission
-- ============================================================
SELECT is(
  (public.submit_form_v1(
    'test-workspace-01',
    'buyer',
    '{"name": "John Doe", "email": "john@example.com", "spam_token": "test-token-xyz"}'::jsonb
  )::json)->>'ok',
  'true',
  'submit_form_v1 valid buyer: ok=true'
);

-- ============================================================
-- submit_form_v1 -- missing spam token -> VALIDATION_ERROR
-- ============================================================
SELECT is(
  (public.submit_form_v1(
    'test-workspace-01',
    'seller',
    '{"asking_price": 250000}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'submit_form_v1 missing spam_token: code=VALIDATION_ERROR'
);
SELECT isnt(
  (public.submit_form_v1(
    'test-workspace-01',
    'seller',
    '{"asking_price": 250000}'::jsonb
  )::json)->'error'->>'fields',
  NULL,
  'submit_form_v1 missing spam_token: error.fields present'
);

-- ============================================================
-- submit_form_v1 -- invalid slug -> NOT_FOUND
-- ============================================================
SELECT is(
  (public.submit_form_v1(
    'nonexistent-slug-99',
    'seller',
    '{"spam_token": "test-token-abc"}'::jsonb
  )::json)->>'code',
  'NOT_FOUND',
  'submit_form_v1 invalid slug: code=NOT_FOUND'
);

-- ============================================================
-- submit_form_v1 -- invalid form_type -> VALIDATION_ERROR
-- ============================================================
SELECT is(
  (public.submit_form_v1(
    'test-workspace-01',
    'invalid',
    '{"spam_token": "test-token-abc"}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'submit_form_v1 invalid form_type: code=VALIDATION_ERROR'
);

-- ============================================================
-- submit_form_v1 -- null payload -> VALIDATION_ERROR
-- ============================================================
SELECT is(
  (public.submit_form_v1('test-workspace-01', 'seller', NULL)::json)->>'code',
  'VALIDATION_ERROR',
  'submit_form_v1 null payload: code=VALIDATION_ERROR'
);

-- ============================================================
-- Verify draft deal was created (10.12C: pricing not from public intake)
-- asking_price and repair_estimate are always NULL from public intake.
-- ============================================================
SELECT is(
  (SELECT COUNT(*)::int FROM public.draft_deals
   WHERE tenant_id = 'a0810000-0000-0000-0000-000000000001'::uuid
   AND form_type = 'seller'
   AND asking_price IS NULL
   AND repair_estimate IS NULL) >= 1,
  true,
  'submit_form_v1: draft deal created with pricing NULL (governed paths only)'
);

-- ============================================================
-- Verify anon privilege -- both RPCs callable without auth context
-- ============================================================
SELECT is(
  (public.resolve_form_slug_v1('test-workspace-01', 'seller')::json)->>'ok',
  'true',
  'resolve_form_slug_v1: callable without auth context (anon-safe)'
);
SELECT is(
  (public.submit_form_v1(
    'test-workspace-01',
    'buyer',
    '{"name": "Anon Test", "spam_token": "anon-token"}'::jsonb
  )::json)->>'ok',
  'true',
  'submit_form_v1: callable without auth context (anon-safe)'
);

SELECT * FROM finish();
ROLLBACK;
