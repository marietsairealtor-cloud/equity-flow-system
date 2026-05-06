-- 10.12C3: Lead Intake list filter (list_intake_submissions_v1 seller/birddog only)
BEGIN;

SELECT plan(6);

SELECT public.create_active_workspace_seed_v1(
  'bd112233-c333-4333-a333-a33333330001'::uuid,
  'ad112233-c333-4333-a333-a33333330001'::uuid,
  'member'
);

SELECT public.create_active_workspace_seed_v1(
  'bd112233-c333-4333-a333-a33333330002'::uuid,
  'ad112233-c333-4333-a333-a33333330002'::uuid,
  'member'
);

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES
  ('bd112233-c333-4333-a333-a33333330001', 'c3-intake-a'),
  ('bd112233-c333-4333-a333-a33333330002', 'c3-intake-b')
ON CONFLICT DO NOTHING;

SELECT public.submit_form_v1(
  'c3-intake-a', 'seller',
  '{"spam_token":"c3s","address":"333 Oak","name":"S","phone":"111","email":"s@example.com"}'::jsonb
);
SELECT public.submit_form_v1(
  'c3-intake-a', 'birddog',
  '{"spam_token":"c3bg","address":"444 Pine","name":"B","phone":"222","email":"b@example.com","condition_notes":"","asking_price":"1"}'::jsonb
);
SELECT public.submit_form_v1(
  'c3-intake-a', 'buyer',
  '{"spam_token":"c3by","name":"Buy","email":"buyer@example.com","phone":"","areas_of_interest":"","budget_range":""}'::jsonb
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"ad112233-c333-4333-a333-a33333330001","role":"authenticated","tenant_id":"bd112233-c333-4333-a333-a33333330001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT ok(
  (public.list_intake_submissions_v1(100))->>'code' = 'OK',
  '10.12C3: returns OK envelope'
);

SELECT is(
  jsonb_array_length((public.list_intake_submissions_v1(100))->'data'->'items'),
  2::int,
  '10.12C3: tenant A sees seller + birddog only (buyer omitted)'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(
      (public.list_intake_submissions_v1(100))->'data'->'items'
    ) AS elem
    WHERE elem->>'form_type' = 'buyer'
  ),
  '10.12C3: no buyer rows in items array'
);

SELECT ok(
  (SELECT coalesce(bool_and(
    elem ? 'draft_deals_id'
    AND (elem->>'draft_deals_id') IS NOT NULL
  ), true)
  FROM jsonb_array_elements((public.list_intake_submissions_v1(100))->'data'->'items') AS elem),
  '10.12C3: every item exposes non-null draft_deals_id'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"ad112233-c333-4333-a333-a33333330002","role":"authenticated","tenant_id":"bd112233-c333-4333-a333-a33333330002"}',
  true
);

SELECT ok(
  jsonb_array_length((public.list_intake_submissions_v1())->'data'->'items') = 0,
  '10.12C3: tenant B isolation (zero rows)'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"ad112233-c333-4333-a333-a33333330001","role":"authenticated","tenant_id":"bd112233-c333-4333-a333-a33333330001"}',
  true
);

SELECT is(
  (public.list_intake_submissions_v1(101))->>'code',
  'VALIDATION_ERROR',
  '10.12C3: p_limit above 100 returns VALIDATION_ERROR'
);

SELECT finish();
ROLLBACK;
