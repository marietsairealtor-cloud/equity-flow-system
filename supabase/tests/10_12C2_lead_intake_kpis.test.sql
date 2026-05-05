-- 10.12C2: Lead Intake KPI read path (get_lead_intake_kpis_v1)
BEGIN;

SELECT plan(12);

SELECT public.create_active_workspace_seed_v1(
  'ba112222-a222-4222-a222-a22222220001'::uuid,
  'aa112222-a222-4222-a222-a22222220001'::uuid,
  'member'
);

SELECT public.create_active_workspace_seed_v1(
  'ba112222-a222-4222-a222-a22222220002'::uuid,
  'aa112222-a222-4222-a222-a22222220002'::uuid,
  'member'
);

SET LOCAL ROLE postgres;

INSERT INTO public.deals (id, tenant_id, row_version, calc_version, stage, updated_at, created_at)
VALUES (
  'da112222-a222-4222-a222-a22222220001'::uuid,
  'ba112222-a222-4222-a222-a22222220001'::uuid,
  1,
  1,
  'new',
  now(),
  now()
);

INSERT INTO public.draft_deals (id, tenant_id, slug, form_type, payload, promoted_deal_id)
VALUES
  (
    'fa112222-a222-4222-a222-a22222220001'::uuid,
    'ba112222-a222-4222-a222-a22222220001'::uuid,
    'seed-slug-a',
    'seller',
    '{}'::jsonb,
    'da112222-a222-4222-a222-a22222220001'::uuid
  ),
  (
    'fa112222-a222-4222-a222-a22222220002'::uuid,
    'ba112222-a222-4222-a222-a22222220001'::uuid,
    'seed-slug-b',
    'seller',
    '{}'::jsonb,
    NULL
  );

INSERT INTO public.intake_submissions (
  id, tenant_id, form_type, payload, source, submitted_at, reviewed_at, draft_deals_id
)
VALUES
  (
    'ea112222-a222-4222-a222-a22222220101'::uuid,
    'ba112222-a222-4222-a222-a22222220001'::uuid,
    'seller',
    '{}'::jsonb,
    'test',
    '2026-05-03 10:00:00+00',
    NULL,
    'fa112222-a222-4222-a222-a22222220001'::uuid
  ),
  (
    'ea112222-a222-4222-a222-a22222220102'::uuid,
    'ba112222-a222-4222-a222-a22222220001'::uuid,
    'seller',
    '{}'::jsonb,
    'test',
    '2026-05-04 10:00:00+00',
    NULL,
    'fa112222-a222-4222-a222-a22222220002'::uuid
  ),
  (
    'ea112222-a222-4222-a222-a22222220103'::uuid,
    'ba112222-a222-4222-a222-a22222220001'::uuid,
    'buyer',
    '{}'::jsonb,
    'test',
    '2026-05-05 10:00:00+00',
    NULL,
    NULL
  ),
  (
    'ea112222-a222-4222-a222-a22222220104'::uuid,
    'ba112222-a222-4222-a222-a22222220001'::uuid,
    'birddog',
    '{}'::jsonb,
    'test',
    '2026-01-01 10:00:00+00',
    NULL,
    NULL
  ),
  (
    'ea112222-a222-4222-a222-a22222220105'::uuid,
    'ba112222-a222-4222-a222-a22222220001'::uuid,
    'seller',
    '{}'::jsonb,
    'test',
    '2026-05-06 09:00:00+00',
    '2026-05-06 11:00:00+00',
    NULL
  ),
  (
    'ea112222-a222-4222-a222-a22222220106'::uuid,
    'ba112222-a222-4222-a222-a22222220001'::uuid,
    'seller',
    '{}'::jsonb,
    'test',
    '2026-06-01 10:00:00+00',
    NULL,
    NULL
  ),
  (
    'ea112222-a222-4222-a222-a22222220107'::uuid,
    'ba112222-a222-4222-a222-a22222220001'::uuid,
    'buyer',
    '{}'::jsonb,
    'test',
    '2026-05-07 12:00:00+00',
    NULL,
    NULL
  );

INSERT INTO public.intake_submissions (id, tenant_id, form_type, payload, source, submitted_at, reviewed_at)
VALUES
  (
    'ec112222-a222-4222-a222-a22222990099'::uuid,
    'ba112222-a222-4222-a222-a22222220001'::uuid,
    'seller',
    '{}'::jsonb,
    'test',
    now() - interval '5 days',
    NULL
  );

INSERT INTO public.intake_submissions (id, tenant_id, form_type, payload, source, submitted_at, reviewed_at)
VALUES
  (
    'eb112222-a222-4222-a222-a2222222b001'::uuid,
    'ba112222-a222-4222-a222-a22222220002'::uuid,
    'seller',
    '{}'::jsonb,
    'test',
    '2026-05-03 10:00:00+00',
    NULL
  ),
  (
    'eb112222-a222-4222-a222-a2222222b002'::uuid,
    'ba112222-a222-4222-a222-a22222220002'::uuid,
    'seller',
    '{}'::jsonb,
    'test',
    '2026-05-04 10:00:00+00',
    NULL
  );

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"aa112222-a222-4222-a222-a22222220001","role":"authenticated","tenant_id":"ba112222-a222-4222-a222-a22222220001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.get_lead_intake_kpis_v1())->>'code',
  'OK',
  '10.12C2: default window returns OK'
);

SELECT ok(
  (public.get_lead_intake_kpis_v1()->'data'->>'new_leads')::bigint >= 1,
  '10.12C2: default 30-day window includes row submitted 5 days ago'
);

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      timestamptz '2026-05-10 00:00:00+00',
      timestamptz '2026-05-01 00:00:00+00'
    )->>'code'
  ),
  'VALIDATION_ERROR',
  '10.12C2: invalid range (date_to < date_from) returns VALIDATION_ERROR'
);

SELECT is(
  (public.get_lead_intake_kpis_v1('1900-01-01 00:00:00+00'::timestamptz, NULL)->>'code'),
  'OK',
  '10.12C2: p_date_from only (p_date_to defaults to now) returns OK'
);

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-05-02 00:00:00+00'::timestamptz,
      '2026-05-05 23:59:59+00'::timestamptz
    )->'data'->>'new_leads'
  ),
  '3',
  '10.12C2: custom window May 2–5 counts three submissions (two sellers + buyer)'
);

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-05-02 00:00:00+00'::timestamptz,
      '2026-05-05 23:59:59+00'::timestamptz
    )->'data'->>'submission_to_deal_pct'
  ),
  '50',
  '10.12C2: submission_to_deal_pct 50 (1 promoted of 2 seller rows; buyer excluded from denominator)'
);

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-05-01 00:00:00+00'::timestamptz,
      '2026-05-31 23:59:59+00'::timestamptz
    )->'data'->>'new_leads'
  ),
  '5',
  '10.12C2: May 2026 month window counts five tenant-A rows (excludes Jan/Jun and other tenant)'
);

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-05-07 00:00:00+00'::timestamptz,
      '2026-05-07 23:59:59+00'::timestamptz
    )->'data'->>'submission_to_deal_pct'
  ),
  '0',
  '10.12C2: zero address-based denominator returns 0 (buyer-only day)'
);

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-05-06 00:00:00+00'::timestamptz,
      '2026-05-06 23:59:59+00'::timestamptz
    )->'data'->>'avg_review_time_hours'
  ),
  '2.0',
  '10.12C2: avg_review_time_hours is 2.0 for 2h review lag'
);

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-05-07 00:00:00+00'::timestamptz,
      '2026-05-07 23:59:59+00'::timestamptz
    )->'data'->>'avg_review_time_hours'
  ),
  '0',
  '10.12C2: no reviewed submissions in window yields 0 avg_review_time_hours'
);

SELECT is(
  (
    public.get_lead_intake_kpis_v1(
      '2026-06-01 00:00:00+00'::timestamptz,
      '2026-06-01 23:59:59+00'::timestamptz
    )->'data'->>'unreviewed_count'
  ),
  '7',
  '10.12C2: unreviewed_count ignores reporting window (seven unreviewed rows on tenant A)'
);

SET LOCAL ROLE postgres;
UPDATE public.user_profiles
SET current_tenant_id = NULL
WHERE id = 'aa112222-a222-4222-a222-a22222220001'::uuid;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"aa112222-a222-4222-a222-a22222220001","role":"authenticated"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  public.get_lead_intake_kpis_v1()->>'code',
  'NOT_AUTHORIZED',
  '10.12C2: no tenant context returns NOT_AUTHORIZED'
);

SELECT finish();
ROLLBACK;
