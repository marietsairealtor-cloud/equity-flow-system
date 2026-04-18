-- 10.9: MAO Calculator -- create_deal_v1 server-computed MAO tests
BEGIN;

SELECT plan(12);

-- ===================================================================
-- Seed workspace and owner
-- ===================================================================
SELECT public.create_active_workspace_seed_v1(
  'b1000000-0000-0000-0000-000000000001'::uuid,
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'owner'
);

SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1000000-0000-0000-0000-000000000001"}';
SET LOCAL ROLE authenticated;

-- Test 1: valid inputs compute MAO correctly server-side (response)
-- ARV=250000, multiplier=0.70, repair=40000, profit=15000
-- MAO = ROUND(250000 * 0.70 - 40000 - 15000) = 120000
SELECT is(
  (public.create_deal_v1(
    'c1000000-0000-0000-0000-000000000001'::uuid,
    1,
    '{"arv":250000,"repair_estimate":40000,"desired_profit":15000,"multiplier":0.70,"calc_version":"mao_v1","address":""}'::jsonb
  )::json)->'data'->>'mao',
  '120000',
  'create_deal_v1: MAO computed correctly server-side in response'
);

-- Test 2: backend-computed MAO persisted in deal_inputs.assumptions
RESET ROLE;
SELECT is(
  (SELECT (assumptions->>'mao')::numeric
   FROM public.deal_inputs
   WHERE deal_id = 'c1000000-0000-0000-0000-000000000001'),
  120000::numeric,
  'create_deal_v1: backend-computed MAO persisted in deal_inputs.assumptions'
);
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1000000-0000-0000-0000-000000000001"}';

-- Test 3: frontend-supplied mao overwritten in response
SELECT is(
  (public.create_deal_v1(
    'c1000000-0000-0000-0000-000000000002'::uuid,
    1,
    '{"arv":100000,"repair_estimate":10000,"desired_profit":5000,"multiplier":0.75,"calc_version":"mao_v1","mao":999999}'::jsonb
  )::json)->'data'->>'mao',
  '60000',
  'create_deal_v1: frontend-supplied mao overwritten by backend in response'
);

-- Test 4: frontend-supplied mao overwritten in persisted assumptions
RESET ROLE;
SELECT is(
  (SELECT (assumptions->>'mao')::numeric
   FROM public.deal_inputs
   WHERE deal_id = 'c1000000-0000-0000-0000-000000000002'),
  60000::numeric,
  'create_deal_v1: frontend-supplied mao overwritten in persisted deal_inputs.assumptions'
);
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1000000-0000-0000-0000-000000000001"}';

-- Test 5: missing arv returns VALIDATION_ERROR
SELECT is(
  (public.create_deal_v1(
    'c1000000-0000-0000-0000-000000000003'::uuid,
    1,
    '{"repair_estimate":40000,"desired_profit":15000,"multiplier":0.70}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'create_deal_v1: missing arv returns VALIDATION_ERROR'
);

-- Test 6: missing repair_estimate returns VALIDATION_ERROR
SELECT is(
  (public.create_deal_v1(
    'c1000000-0000-0000-0000-000000000004'::uuid,
    1,
    '{"arv":250000,"desired_profit":15000,"multiplier":0.70}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'create_deal_v1: missing repair_estimate returns VALIDATION_ERROR'
);

-- Test 7: missing desired_profit returns VALIDATION_ERROR
SELECT is(
  (public.create_deal_v1(
    'c1000000-0000-0000-0000-000000000005'::uuid,
    1,
    '{"arv":250000,"repair_estimate":40000,"multiplier":0.70}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'create_deal_v1: missing desired_profit returns VALIDATION_ERROR'
);

-- Test 8: missing multiplier returns VALIDATION_ERROR
SELECT is(
  (public.create_deal_v1(
    'c1000000-0000-0000-0000-000000000006'::uuid,
    1,
    '{"arv":250000,"repair_estimate":40000,"desired_profit":15000}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'create_deal_v1: missing multiplier returns VALIDATION_ERROR'
);

-- Test 9: multiplier > 1 returns VALIDATION_ERROR
SELECT is(
  (public.create_deal_v1(
    'c1000000-0000-0000-0000-000000000007'::uuid,
    1,
    '{"arv":250000,"repair_estimate":40000,"desired_profit":15000,"multiplier":1.5}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'create_deal_v1: multiplier > 1 returns VALIDATION_ERROR'
);

-- Test 10: null p_id returns VALIDATION_ERROR
SELECT is(
  (public.create_deal_v1(
    NULL::uuid,
    1,
    '{"arv":250000,"repair_estimate":40000,"desired_profit":15000,"multiplier":0.70}'::jsonb
  )::json)->>'code',
  'VALIDATION_ERROR',
  'create_deal_v1: null p_id returns VALIDATION_ERROR'
);

-- Test 11: authenticated role with no JWT claims returns NOT_AUTHORIZED
RESET "request.jwt.claims";
SET LOCAL ROLE authenticated;

SELECT is(
  (public.create_deal_v1(
    'c1000000-0000-0000-0000-000000000009'::uuid,
    1,
    '{"arv":250000,"repair_estimate":40000,"desired_profit":15000,"multiplier":0.70}'::jsonb
  )::json)->>'code',
  'NOT_AUTHORIZED',
  'create_deal_v1: authenticated role with no JWT claims returns NOT_AUTHORIZED'
);

-- Test 12: duplicate deal id returns CONFLICT
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated","tenant_id":"b1000000-0000-0000-0000-000000000001"}';
SET LOCAL ROLE authenticated;

SELECT is(
  (public.create_deal_v1(
    'c1000000-0000-0000-0000-000000000001'::uuid,
    1,
    '{"arv":250000,"repair_estimate":40000,"desired_profit":15000,"multiplier":0.70}'::jsonb
  )::json)->>'code',
  'CONFLICT',
  'create_deal_v1: duplicate deal id returns CONFLICT'
);

SELECT finish();
ROLLBACK;