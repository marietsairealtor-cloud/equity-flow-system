-- 10.12C5: get_lead_intake_kpis_v1 — unreviewed_count excludes buyer submissions
BEGIN;

SELECT plan(5);

SELECT public.create_active_workspace_seed_v1(
  'bc552255-d555-4555-a555-a55555550001'::uuid,
  'ac552255-d555-4555-a555-a55555550001'::uuid,
  'member'
);

SELECT public.create_active_workspace_seed_v1(
  'bc552255-d555-4555-a555-a55555550002'::uuid,
  'ac552255-d555-4555-a555-a55555550002'::uuid,
  'member'
);

SET LOCAL ROLE postgres;

INSERT INTO public.intake_submissions (
  id, tenant_id, form_type, payload, source, submitted_at, reviewed_at
)
VALUES
  (
    'cc552255-d555-4555-a555-a55555550101'::uuid,
    'bc552255-d555-4555-a555-a55555550001'::uuid,
    'seller',
    '{}'::jsonb,
    'test',
    '2026-05-01 12:00:00+00',
    NULL
  ),
  (
    'cc552255-d555-4555-a555-a55555550102'::uuid,
    'bc552255-d555-4555-a555-a55555550001'::uuid,
    'seller',
    '{}'::jsonb,
    'test',
    '2026-05-02 12:00:00+00',
    NULL
  ),
  (
    'cc552255-d555-4555-a555-a55555550103'::uuid,
    'bc552255-d555-4555-a555-a55555550001'::uuid,
    'birddog',
    '{}'::jsonb,
    'test',
    '2026-05-03 12:00:00+00',
    NULL
  ),
  (
    'cc552255-d555-4555-a555-a55555550104'::uuid,
    'bc552255-d555-4555-a555-a55555550001'::uuid,
    'buyer',
    '{}'::jsonb,
    'test',
    '2026-05-04 12:00:00+00',
    NULL
  ),
  (
    'cc552255-d555-4555-a555-a55555550105'::uuid,
    'bc552255-d555-4555-a555-a55555550001'::uuid,
    'buyer',
    '{}'::jsonb,
    'test',
    '2026-05-05 12:00:00+00',
    NULL
  ),
  (
    'cc552255-d555-4555-a555-a55555550106'::uuid,
    'bc552255-d555-4555-a555-a55555550001'::uuid,
    'buyer',
    '{}'::jsonb,
    'test',
    '2026-05-06 12:00:00+00',
    NULL
  ),
  (
    'cc552255-d555-4555-a555-a55555550201'::uuid,
    'bc552255-d555-4555-a555-a55555550002'::uuid,
    'seller',
    '{}'::jsonb,
    'test',
    '2026-05-01 12:00:00+00',
    NULL
  );

-- six unreviewed rows on tenant A (two seller, one birddog, three buyer); C5 queue counts three.
UPDATE public.intake_submissions
SET review_status = 'unreviewed',
    review_outcome = NULL
WHERE id IN (
  'cc552255-d555-4555-a555-a55555550101'::uuid,
  'cc552255-d555-4555-a555-a55555550102'::uuid,
  'cc552255-d555-4555-a555-a55555550103'::uuid,
  'cc552255-d555-4555-a555-a55555550104'::uuid,
  'cc552255-d555-4555-a555-a55555550105'::uuid,
  'cc552255-d555-4555-a555-a55555550106'::uuid,
  'cc552255-d555-4555-a555-a55555550201'::uuid
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"ac552255-d555-4555-a555-a55555550001","role":"authenticated","tenant_id":"bc552255-d555-4555-a555-a55555550001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.get_lead_intake_kpis_v1())->>'code',
  'OK',
  '10.12C5: KPI RPC returns OK'
);

SELECT is(
  (public.get_lead_intake_kpis_v1()->'data'->>'unreviewed_count'),
  '3',
  '10.12C5: unreviewed_count is two seller + one birddog (three buyer unreviewed excluded)'
);

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '1980-06-01 00:00:00+00'::timestamptz,
      '1980-06-30 23:59:59+00'::timestamptz
    )->'data'->>'unreviewed_count'
  ),
  '3',
  '10.12C5: unreviewed_count ignores reporting window'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"ac552255-d555-4555-a555-a55555550002","role":"authenticated","tenant_id":"bc552255-d555-4555-a555-a55555550002"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.get_lead_intake_kpis_v1()->'data'->>'unreviewed_count'),
  '1',
  '10.12C5: tenant B sees only its unreviewed seller (tenant isolation)'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"ac552255-d555-4555-a555-a55555550001","role":"authenticated","tenant_id":"bc552255-d555-4555-a555-a55555550001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.get_lead_intake_kpis_v1()->'data'->>'unreviewed_count'),
  '3',
  '10.12C5: back on tenant A, queue count still seller/birddog only'
);

SELECT finish();
ROLLBACK;
