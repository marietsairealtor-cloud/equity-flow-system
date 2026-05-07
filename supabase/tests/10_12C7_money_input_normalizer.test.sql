-- 10.12C7: Money input normalizer (_parse_money_input_v1, canonicalize on intake/pricing RPCs)
BEGIN;

SELECT plan(17);

-- ============================================================
-- Tenant + slug (intake + authenticated RPCs)
-- ============================================================
SELECT public.create_active_workspace_seed_v1(
  'c12c7000-0000-4000-8000-000000000001'::uuid,
  'c12c7000-0000-4000-8000-0000000000b1'::uuid,
  'member'::public.tenant_role
);

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES ('c12c7000-0000-4000-8000-000000000001', 'test-12c7-a')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 1–4. Internal parsers (superuser only)
-- ============================================================
SET LOCAL ROLE postgres;

SELECT is(
  public._parse_money_input_v1('$1,200'),
  1200::numeric,
  'C7: _parse_money_input_v1 strips $ and comma groups'
);

SELECT is(
  public._parse_money_input_v1('15k'),
  15000::numeric,
  'C7: _parse_money_input_v1 accepts k suffix'
);

SELECT ok(
  public._parse_money_input_v1(NULL::text) IS NULL,
  'C7: _parse_money_input_v1(NULL) is NULL'
);

SELECT ok(
  public._intake_canonicalize_pricing_assumptions_v1('{"multiplier":"100"}'::jsonb) IS NULL,
  'C7: canonicalize rejects multiplier that normalizes to >= 1'
);

-- ============================================================
-- 5–7. create_deal_from_intake_v1: formatted assumptions + invalid
-- ============================================================
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"c12c7000-0000-4000-8000-0000000000b1","role":"authenticated","tenant_id":"c12c7000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

-- mao = ROUND(250000 * 0.65 - 10000 - 1000) = 151500
SELECT is(
  (public.create_deal_from_intake_v1(
    jsonb_build_object(
      'address', '700 Money Norm Rd',
      'seller_name', 'Money Tester',
      'assumptions', jsonb_build_object(
        'arv', '$250,000',
        'repair_estimate', '10k',
        'multiplier', '65%',
        'assignment_fee', '$1,000'
      )
    )
  )->>'code'),
  'OK',
  'C7: create_deal_from_intake_v1 accepts formatted money strings'
);

SET LOCAL ROLE postgres;
SELECT is(
  (
    SELECT ROUND((di.assumptions->>'mao')::numeric)
    FROM public.deal_inputs di
    JOIN public.deals d ON d.assumptions_snapshot_id = di.id
    WHERE d.tenant_id = 'c12c7000-0000-4000-8000-000000000001'
      AND d.address = '700 Money Norm Rd'
  ),
  151500::numeric,
  'C7: create_deal_from_intake_v1 MAO matches parsed assumptions'
);

SET LOCAL ROLE authenticated;
SELECT is(
  (public.create_deal_from_intake_v1(
    '{"address":"701 Bad Money","assumptions":{"arv":"$25o00"}}'::jsonb
  )->>'code'),
  'VALIDATION_ERROR',
  'C7: create_deal_from_intake_v1 invalid monetary text → VALIDATION_ERROR'
);

-- ============================================================
-- 8–13. update_deal_pricing_v1: formatted arv, percent multiplier, clear via ""
-- ============================================================
SET LOCAL ROLE postgres;
INSERT INTO public.deals (
  id, tenant_id, row_version, calc_version, stage, address, updated_at, created_at
)
VALUES (
  'd12c7000-0000-4000-8000-000000000001',
  'c12c7000-0000-4000-8000-000000000001',
  1, 1, 'new', '800 Pricing Norm St', now(), now()
);

INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
VALUES (
  'e12c7000-0000-4000-8000-000000000001',
  'c12c7000-0000-4000-8000-000000000001',
  'd12c7000-0000-4000-8000-000000000001',
  1,
  '{"arv":400000,"repair_estimate":20000,"multiplier":0.70,"assignment_fee":0,"mao":260000}'::jsonb,
  now() - interval '1 hour'
);

UPDATE public.deals
SET assumptions_snapshot_id = 'e12c7000-0000-4000-8000-000000000001'
WHERE id = 'd12c7000-0000-4000-8000-000000000001';

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"c12c7000-0000-4000-8000-0000000000b1","role":"authenticated","tenant_id":"c12c7000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.update_deal_pricing_v1(
    'd12c7000-0000-4000-8000-000000000001',
    '{"arv":"$320,000"}'::jsonb
  )::json)->>'ok',
  'true',
  'C7: update_deal_pricing_v1 accepts formatted arv'
);

SET LOCAL ROLE postgres;
SELECT is(
  (
    SELECT (di.assumptions->>'arv')::numeric
    FROM public.deals d
    JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
    WHERE d.id = 'd12c7000-0000-4000-8000-000000000001'
  ),
  320000::numeric,
  'C7: update_deal_pricing_v1 persisted parsed arv'
);

SET LOCAL ROLE authenticated;
SELECT is(
  (public.update_deal_pricing_v1(
    'd12c7000-0000-4000-8000-000000000001',
    '{"multiplier":"68%"}'::jsonb
  )::json)->>'ok',
  'true',
  'C7: update_deal_pricing_v1 accepts multiplier with %'
);

SET LOCAL ROLE postgres;
SELECT is(
  (
    SELECT (di.assumptions->>'multiplier')::numeric
    FROM public.deals d
    JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
    WHERE d.id = 'd12c7000-0000-4000-8000-000000000001'
  ),
  0.68::numeric,
  'C7: update_deal_pricing_v1 stored multiplier as fraction'
);

SET LOCAL ROLE authenticated;
SELECT is(
  (public.update_deal_pricing_v1(
    'd12c7000-0000-4000-8000-000000000001',
    '{"repair_estimate":""}'::jsonb
  )::json)->>'ok',
  'true',
  'C7: update_deal_pricing_v1 empty string clears repair_estimate'
);

SET LOCAL ROLE postgres;
SELECT ok(
  NOT (
    SELECT (di.assumptions ? 'repair_estimate')
    FROM public.deals d
    JOIN public.deal_inputs di ON di.id = d.assumptions_snapshot_id
    WHERE d.id = 'd12c7000-0000-4000-8000-000000000001'
  ),
  'C7: repair_estimate key removed after clear'
);

-- ============================================================
-- 14–15. promote_draft_deal_v1: birddog payload asking_price string normalized
-- ============================================================
RESET ROLE;
SELECT public.submit_form_v1(
  'test-12c7-a',
  'birddog',
  '{"spam_token":"c7bd","address":"900 Bird Money Ln","name":"B Money","phone":"555-7001","email":"bm@example.com","asking_price":"$ 88,000.50"}'::jsonb
);

SET LOCAL ROLE postgres;
DROP TABLE IF EXISTS _12c7_birddog_draft;
CREATE TEMP TABLE _12c7_birddog_draft (id uuid PRIMARY KEY);
INSERT INTO _12c7_birddog_draft (id)
SELECT id FROM public.draft_deals
WHERE tenant_id = 'c12c7000-0000-4000-8000-000000000001'
  AND payload->>'address' = '900 Bird Money Ln'
ORDER BY created_at DESC
LIMIT 1;
GRANT SELECT ON TABLE _12c7_birddog_draft TO authenticated;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"c12c7000-0000-4000-8000-0000000000b1","role":"authenticated","tenant_id":"c12c7000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (
    public.promote_draft_deal_v1(
      (SELECT id FROM _12c7_birddog_draft),
      '{"assumptions":{"arv":"200000","repair_estimate":"5000","multiplier":"0.70","assignment_fee":"0"}}'::jsonb
    )->>'code'
  ),
  'OK',
  'C7: promote_draft_deal_v1 succeeds with formatted birddog asking_price'
);

SET LOCAL ROLE postgres;
SELECT is(
  (
    SELECT (di.assumptions->>'ask_price')::numeric
    FROM public.deal_inputs di
    JOIN public.deals d ON d.assumptions_snapshot_id = di.id
    WHERE d.tenant_id = 'c12c7000-0000-4000-8000-000000000001'
      AND d.address = '900 Bird Money Ln'
  ),
  88000.50::numeric,
  'C7: promoted deal ask_price parsed from birddog payload'
);

-- ============================================================
-- 16–17. EXECUTE: helpers locked down; public RPCs unchanged
-- ============================================================
SET LOCAL ROLE postgres;
SELECT ok(
  NOT has_function_privilege('authenticated', 'public._parse_money_input_v1(text)', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'public._parse_money_input_v1(text)', 'EXECUTE'),
  'C7: _parse_money_input_v1 not granted to authenticated or anon'
);

SELECT ok(
  has_function_privilege('authenticated', 'public.create_deal_from_intake_v1(jsonb)', 'EXECUTE')
  AND has_function_privilege('authenticated', 'public.update_deal_pricing_v1(uuid, jsonb)', 'EXECUTE'),
  'C7: create_deal_from_intake_v1 and update_deal_pricing_v1 still executable by authenticated'
);

SELECT finish();
ROLLBACK;
