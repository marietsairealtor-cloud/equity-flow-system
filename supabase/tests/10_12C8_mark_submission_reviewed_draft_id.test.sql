-- 10.12C8: mark_submission_reviewed_v1 — p_outcome-first signature + p_draft_id resolution
BEGIN;

SELECT plan(15);

SELECT public.create_active_workspace_seed_v1(
  'c12c8000-0000-4000-8000-000000000001'::uuid,
  'c12c8000-0000-4000-8000-0000000000b1'::uuid,
  'member'
);

SELECT public.create_active_workspace_seed_v1(
  'c12c8000-0000-4000-8000-000000000002'::uuid,
  'c12c8000-0000-4000-8000-0000000000b2'::uuid,
  'member'
);

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES
  ('c12c8000-0000-4000-8000-000000000001', 'test-12c8-a'),
  ('c12c8000-0000-4000-8000-000000000002', 'test-12c8-b')
ON CONFLICT DO NOTHING;

SELECT public.submit_form_v1(
  'test-12c8-a', 'seller',
  '{"spam_token":"c8one","address":"100 One St","name":"O","phone":"1","email":"one@example.com"}'::jsonb
);
SELECT public.submit_form_v1(
  'test-12c8-a', 'seller',
  '{"spam_token":"c8two","address":"200 Two St","name":"T","phone":"2","email":"two@example.com"}'::jsonb
);
SELECT public.submit_form_v1(
  'test-12c8-a', 'seller',
  '{"spam_token":"c8thr","address":"300 Three St","name":"H","phone":"3","email":"thr@example.com"}'::jsonb
);
SELECT public.submit_form_v1(
  'test-12c8-a', 'seller',
  '{"spam_token":"c8four","address":"400 Four St","name":"F","phone":"4","email":"four@example.com"}'::jsonb
);
SELECT public.submit_form_v1(
  'test-12c8-b', 'seller',
  '{"spam_token":"c8bx","address":"900 Other Tenant","name":"X","phone":"9","email":"x@other.com"}'::jsonb
);

SET LOCAL ROLE postgres;
DROP TABLE IF EXISTS _12c8_ref;
CREATE TEMP TABLE _12c8_ref (
  label    text PRIMARY KEY,
  sid      uuid NOT NULL,
  draft_id uuid NOT NULL
);
INSERT INTO _12c8_ref (label, sid, draft_id)
SELECT 'one', id, draft_deals_id
FROM public.intake_submissions
WHERE tenant_id = 'c12c8000-0000-4000-8000-000000000001'
  AND form_type = 'seller'
  AND payload->>'address' = '100 One St'
LIMIT 1;
INSERT INTO _12c8_ref (label, sid, draft_id)
SELECT 'two', id, draft_deals_id
FROM public.intake_submissions
WHERE tenant_id = 'c12c8000-0000-4000-8000-000000000001'
  AND form_type = 'seller'
  AND payload->>'address' = '200 Two St'
LIMIT 1;
INSERT INTO _12c8_ref (label, sid, draft_id)
SELECT 'three', id, draft_deals_id
FROM public.intake_submissions
WHERE tenant_id = 'c12c8000-0000-4000-8000-000000000001'
  AND form_type = 'seller'
  AND payload->>'address' = '300 Three St'
LIMIT 1;
INSERT INTO _12c8_ref (label, sid, draft_id)
SELECT 'four', id, draft_deals_id
FROM public.intake_submissions
WHERE tenant_id = 'c12c8000-0000-4000-8000-000000000001'
  AND form_type = 'seller'
  AND payload->>'address' = '400 Four St'
LIMIT 1;
INSERT INTO _12c8_ref (label, sid, draft_id)
SELECT 'b_cross', id, draft_deals_id
FROM public.intake_submissions
WHERE tenant_id = 'c12c8000-0000-4000-8000-000000000002'
  AND form_type = 'seller'
  AND payload->>'address' = '900 Other Tenant'
LIMIT 1;
GRANT SELECT ON TABLE _12c8_ref TO authenticated;

RESET ROLE;
SELECT public.submit_form_v1(
  'test-12c8-a', 'seller',
  '{"spam_token":"c8exp","address":"500 Expire St","name":"E","phone":"5","email":"exp@example.com"}'::jsonb
);

SET LOCAL ROLE postgres;
DROP TABLE IF EXISTS _12c8_expire;
CREATE TEMP TABLE _12c8_expire (sid uuid PRIMARY KEY);
INSERT INTO _12c8_expire (sid)
SELECT id FROM public.intake_submissions
WHERE tenant_id = 'c12c8000-0000-4000-8000-000000000001'
  AND payload->>'address' = '500 Expire St'
LIMIT 1;
GRANT SELECT ON TABLE _12c8_expire TO authenticated;

RESET ROLE;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"c12c8000-0000-4000-8000-0000000000b1","role":"authenticated","tenant_id":"c12c8000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (public.mark_submission_reviewed_v1(
    'rejected_spam'::text,
    NULL::uuid,
    NULL::uuid
  )->>'code'),
  'VALIDATION_ERROR',
  '10.12C8: neither p_submission_id nor p_draft_id → VALIDATION_ERROR'
);

SELECT is(
  (
    public.mark_submission_reviewed_v1(
      'rejected_spam'::text,
      NULL::uuid,
      'a0000000-0000-4000-8000-000000000099'::uuid
    )->>'code'
  ),
  'NOT_FOUND',
  '10.12C8: unknown p_draft_id (no linked submission) → NOT_FOUND'
);

SELECT is(
  (
    public.mark_submission_reviewed_v1(
      'rejected_spam'::text,
      NULL::uuid,
      (SELECT draft_id FROM _12c8_ref WHERE label = 'b_cross')
    )->>'code'
  ),
  'NOT_FOUND',
  '10.12C8: cross-tenant p_draft_id → NOT_FOUND'
);

SELECT is(
  (
    public.mark_submission_reviewed_v1(
      'dismissed_not_interested'::text,
      NULL::uuid,
      (SELECT draft_id FROM _12c8_ref WHERE label = 'one')
    )->>'code'
  ),
  'OK',
  '10.12C8: dismiss via p_draft_id → OK'
);

RESET ROLE;

SELECT is(
  (
    SELECT review_status FROM public.intake_submissions
    WHERE id = (SELECT sid FROM _12c8_ref WHERE label = 'one')
  ),
  'reviewed',
  '10.12C8: dismiss via p_draft_id sets review_status reviewed'
);

SELECT is(
  (
    SELECT review_outcome FROM public.intake_submissions
    WHERE id = (SELECT sid FROM _12c8_ref WHERE label = 'one')
  ),
  'dismissed_not_interested',
  '10.12C8: dismiss via p_draft_id sets review_outcome'
);

SELECT ok(
  (
    SELECT reviewed_at IS NOT NULL FROM public.intake_submissions
    WHERE id = (SELECT sid FROM _12c8_ref WHERE label = 'one')
  ),
  '10.12C8: dismiss via p_draft_id sets reviewed_at'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"c12c8000-0000-4000-8000-0000000000b1","role":"authenticated","tenant_id":"c12c8000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (
    public.mark_submission_reviewed_v1(
      (SELECT sid FROM _12c8_ref WHERE label = 'two'),
      'dismissed_wrong_number'::text
    )->>'code'
  ),
  'OK',
  '10.12C8: dismiss via legacy (p_submission_id, p_outcome) → OK'
);

SELECT is(
  (
    public.mark_submission_reviewed_v1(
      'dismissed_duplicate'::text,
      (SELECT sid FROM _12c8_ref WHERE label = 'four'),
      (SELECT draft_id FROM _12c8_ref WHERE label = 'three')
    )->>'code'
  ),
  'OK',
  '10.12C8: both ids supplied → OK (p_submission_id wins)'
);

RESET ROLE;

SELECT is(
  (
    SELECT review_outcome FROM public.intake_submissions
    WHERE id = (SELECT sid FROM _12c8_ref WHERE label = 'four')
  ),
  'dismissed_duplicate',
  '10.12C8: submission wins — targeted row gets outcome'
);

SELECT is(
  (
    SELECT review_status FROM public.intake_submissions
    WHERE id = (SELECT sid FROM _12c8_ref WHERE label = 'three')
  ),
  'unreviewed',
  '10.12C8: submission wins — other draft''s row stays unreviewed'
);

UPDATE public.tenant_subscriptions
SET current_period_end = now() - interval '1 day'
WHERE tenant_id = 'c12c8000-0000-4000-8000-000000000001'::uuid;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"c12c8000-0000-4000-8000-0000000000b1","role":"authenticated","tenant_id":"c12c8000-0000-4000-8000-000000000001"}',
  true
);
SET LOCAL ROLE authenticated;

SELECT is(
  (
    public.mark_submission_reviewed_v1(
      (SELECT sid FROM _12c8_expire),
      'rejected_spam'::text
    )->>'code'
  ),
  'WORKSPACE_NOT_WRITABLE',
  '10.12C8: expired workspace → WORKSPACE_NOT_WRITABLE'
);

RESET ROLE;

UPDATE public.tenant_subscriptions
SET current_period_end = now() + interval '365 days'
WHERE tenant_id = 'c12c8000-0000-4000-8000-000000000001'::uuid;

RESET "request.jwt.claims";

SET LOCAL ROLE authenticated;

SELECT is(
  (public.mark_submission_reviewed_v1(
    'rejected_spam'::text,
    NULL::uuid,
    NULL::uuid
  )->>'code'),
  'NOT_AUTHORIZED',
  '10.12C8: no JWT auth context → NOT_AUTHORIZED'
);

RESET ROLE;

SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.mark_submission_reviewed_v1(text, uuid, uuid)',
    'EXECUTE'
  ),
  '10.12C8: canonical signature EXECUTE granted to authenticated'
);

SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.mark_submission_reviewed_v1(text, uuid, uuid)',
    'EXECUTE'
  ),
  '10.12C8: canonical signature not executable by anon'
);

SELECT finish();
ROLLBACK;
