-- 10.12C4: Intake Backend — Submission Review Outcomes
-- Columns review_status / review_outcome; mark_submission_reviewed_v1;
-- list_intake_submissions_v1 unreviewed-only + review fields in payload;
-- get_lead_intake_kpis_v1: new_submissions, new_leads (exclude rejected_*), rejected_count, etc.;
-- Promotion review fields: AFTER UPDATE trigger on draft_deals.promoted_deal_id (no promote_draft_deal_v1 body in this file — authority remains 20260505000001_10_12C1).

-- ============================================================
-- intake_submissions: review columns + integrity
-- ============================================================
ALTER TABLE public.intake_submissions
  ADD COLUMN IF NOT EXISTS review_status text NOT NULL DEFAULT 'unreviewed',
  ADD COLUMN IF NOT EXISTS review_outcome text NULL;

ALTER TABLE public.intake_submissions
  DROP CONSTRAINT IF EXISTS intake_submissions_review_status_check;
ALTER TABLE public.intake_submissions
  ADD CONSTRAINT intake_submissions_review_status_check
  CHECK (review_status IN ('unreviewed', 'reviewed'));

ALTER TABLE public.intake_submissions
  DROP CONSTRAINT IF EXISTS intake_submissions_review_outcome_check;
ALTER TABLE public.intake_submissions
  ADD CONSTRAINT intake_submissions_review_outcome_check
  CHECK (
    review_outcome IS NULL
    OR review_outcome IN (
      'promoted',
      'dismissed_not_interested',
      'dismissed_wrong_number',
      'dismissed_duplicate',
      'dismissed_not_a_fit',
      'rejected_spam',
      'rejected_test',
      'rejected_invalid'
    )
  );

-- Legacy backfill: prior to 10.12C4, `reviewed_at` was only set by the successful
-- `promote_draft_deal_v1` path (no dismiss/other review RPCs). Map those rows to
-- `review_status = reviewed` / `review_outcome = promoted` for KPI + inbox semantics.
UPDATE public.intake_submissions
SET review_status = 'reviewed',
    review_outcome = 'promoted'
WHERE reviewed_at IS NOT NULL
  AND review_status = 'unreviewed';

-- ============================================================
-- RPC: mark_submission_reviewed_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_submission_reviewed_v1(
  p_submission_id uuid,
  p_outcome       text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
  v_row    public.intake_submissions%ROWTYPE;
  v_allowed text[] := ARRAY[
    'dismissed_not_interested',
    'dismissed_wrong_number',
    'dismissed_duplicate',
    'dismissed_not_a_fit',
    'rejected_spam',
    'rejected_test',
    'rejected_invalid'
  ];
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'Not authorized', 'fields', '{}'::jsonb)
      );
  END;

  -- Resolve tenant before workspace lock so missing JWT tenant maps to NOT_AUTHORIZED,
  -- not WORKSPACE_NOT_WRITABLE (check_workspace_write_allowed_v1() is boolean; see 10.8.11N).
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'WORKSPACE_NOT_WRITABLE', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Workspace is not active', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_submission_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_submission_id is required', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_outcome IS NULL OR trim(p_outcome) = '' THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_outcome is required', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_outcome = 'promoted' THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'promoted is set only via promote_draft_deal_v1', 'fields', '{}'::jsonb)
    );
  END IF;

  IF NOT (p_outcome = ANY (v_allowed)) THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'invalid p_outcome', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT * INTO v_row
  FROM public.intake_submissions
  WHERE id = p_submission_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Submission not found', 'fields', '{}'::jsonb)
    );
  END IF;

  IF v_row.tenant_id <> v_tenant THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Submission not found', 'fields', '{}'::jsonb)
    );
  END IF;

  IF v_row.form_type = 'buyer' THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'buyer submissions are not reviewed via Lead Intake', 'fields', '{}'::jsonb)
    );
  END IF;

  IF v_row.review_status = 'reviewed' THEN
    IF v_row.review_outcome IS NOT DISTINCT FROM p_outcome THEN
      RETURN jsonb_build_object(
        'ok', true, 'code', 'OK',
        'data', jsonb_build_object('submission_id', p_submission_id),
        'error', null
      );
    END IF;
    RETURN jsonb_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Submission already reviewed with a different outcome', 'fields', '{}'::jsonb)
    );
  END IF;

  UPDATE public.intake_submissions
  SET reviewed_at    = now(),
      review_status  = 'reviewed',
      review_outcome = p_outcome
  WHERE id = p_submission_id AND tenant_id = v_tenant;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object('submission_id', p_submission_id),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.mark_submission_reviewed_v1(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.mark_submission_reviewed_v1(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_submission_reviewed_v1(uuid, text) TO authenticated;

-- ============================================================
-- RPC: get_lead_intake_kpis_v1 (10.12C2 + 10.12C4 semantics)
-- ============================================================
DROP FUNCTION IF EXISTS public.get_lead_intake_kpis_v1(timestamptz, timestamptz);

CREATE FUNCTION public.get_lead_intake_kpis_v1(
  p_date_from timestamptz DEFAULT NULL,
  p_date_to   timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant          uuid;
  v_from            timestamptz;
  v_to              timestamptz;
  v_new_submissions bigint;
  v_new_leads       bigint;
  v_denom           bigint;
  v_num             bigint;
  v_submission_to_deal_pct integer;
  v_avg_review_h    numeric;
  v_unreviewed      bigint;
  v_rejected_count  bigint;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'Not authorized', 'fields', '{}'::jsonb)
      );
  END;

  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  v_from := COALESCE(p_date_from, now() - interval '30 days');
  v_to := COALESCE(p_date_to, now());

  IF v_to < v_from THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'effective date window is invalid (end before start)',
        'fields', '{}'::jsonb
      )
    );
  END IF;

  SELECT COUNT(*) INTO v_new_submissions
  FROM public.intake_submissions
  WHERE tenant_id = v_tenant
    AND form_type IN ('seller', 'birddog')
    AND submitted_at >= v_from
    AND submitted_at <= v_to;

  SELECT COUNT(*) INTO v_new_leads
  FROM public.intake_submissions
  WHERE tenant_id = v_tenant
    AND form_type IN ('seller', 'birddog')
    AND submitted_at >= v_from
    AND submitted_at <= v_to
    AND (
      review_outcome IS NULL
      OR review_outcome NOT IN ('rejected_spam', 'rejected_test', 'rejected_invalid')
    );

  v_denom := v_new_leads;

  SELECT COUNT(*) INTO v_num
  FROM public.intake_submissions s
  WHERE s.tenant_id = v_tenant
    AND s.form_type IN ('seller', 'birddog')
    AND s.submitted_at >= v_from
    AND s.submitted_at <= v_to
    AND (
      s.review_outcome IS NULL
      OR s.review_outcome NOT IN ('rejected_spam', 'rejected_test', 'rejected_invalid')
    )
    AND (
      s.review_outcome = 'promoted'
      OR (
        s.draft_deals_id IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM public.draft_deals d
          WHERE d.id = s.draft_deals_id
            AND d.tenant_id = v_tenant
            AND d.promoted_deal_id IS NOT NULL
        )
      )
    );

  IF v_denom = 0 THEN
    v_submission_to_deal_pct := 0;
  ELSE
    v_submission_to_deal_pct := ROUND((v_num::numeric * 100.0 / v_denom::numeric), 0)::integer;
  END IF;

  SELECT COALESCE(
    ROUND(
      AVG(EXTRACT(EPOCH FROM (reviewed_at - submitted_at)) / 3600.0)::numeric,
      1
    ),
    0
  ) INTO v_avg_review_h
  FROM public.intake_submissions
  WHERE tenant_id = v_tenant
    AND review_status = 'reviewed'
    AND reviewed_at IS NOT NULL
    AND submitted_at >= v_from
    AND submitted_at <= v_to;

  SELECT COUNT(*) INTO v_unreviewed
  FROM public.intake_submissions
  WHERE tenant_id = v_tenant
    AND review_status = 'unreviewed';

  SELECT COUNT(*) INTO v_rejected_count
  FROM public.intake_submissions
  WHERE tenant_id = v_tenant
    AND form_type IN ('seller', 'birddog')
    AND submitted_at >= v_from
    AND submitted_at <= v_to
    AND review_outcome IN ('rejected_spam', 'rejected_test', 'rejected_invalid');

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object(
      'new_submissions',          v_new_submissions,
      'new_leads',                v_new_leads,
      'submission_to_deal_pct',   v_submission_to_deal_pct,
      'avg_review_time_hours',    v_avg_review_h,
      'unreviewed_count',         v_unreviewed,
      'rejected_count',           v_rejected_count,
      'date_from',                v_from,
      'date_to',                  v_to
    ),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.get_lead_intake_kpis_v1(timestamptz, timestamptz) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.get_lead_intake_kpis_v1(timestamptz, timestamptz) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_lead_intake_kpis_v1(timestamptz, timestamptz) TO authenticated;

-- ============================================================
-- RPC: list_intake_submissions_v1 (unreviewed seller/birddog only)
-- ============================================================
DROP FUNCTION IF EXISTS public.list_intake_submissions_v1(int);

CREATE FUNCTION public.list_intake_submissions_v1(
  p_limit int DEFAULT 25
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant_id uuid;
  v_limit     int;
  v_items     jsonb;
BEGIN
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context.', 'fields', '{}'::jsonb)
    );
  END IF;

  v_limit := COALESCE(p_limit, 25);
  IF v_limit < 1 OR v_limit > 100 THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_limit must be between 1 and 100.',
        'fields', jsonb_build_object('p_limit', 'Out of range.'))
    );
  END IF;

  SELECT jsonb_agg(r)
  INTO v_items
  FROM (
    SELECT jsonb_build_object(
      'id',               id,
      'form_type',        form_type,
      'payload',          payload,
      'source',           source,
      'submitted_at',     submitted_at,
      'reviewed_at',      reviewed_at,
      'draft_deals_id',   draft_deals_id,
      'review_status',    review_status,
      'review_outcome',   review_outcome
    ) AS r
    FROM public.intake_submissions
    WHERE tenant_id = v_tenant_id
      AND form_type IN ('seller', 'birddog')
      AND review_status = 'unreviewed'
    ORDER BY submitted_at DESC, id DESC
    LIMIT v_limit
  ) sub;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object('items', COALESCE(v_items, '[]'::jsonb)),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.list_intake_submissions_v1(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_intake_submissions_v1(int) TO authenticated;

-- ============================================================
-- Trigger: when draft_deals.promoted_deal_id is set, sync intake review columns
-- promote_draft_deal_v1 authority: 20260505000001_10_12C1 (single source of truth).
-- C1 promote also runs UPDATE intake_submissions SET reviewed_at (redundant with COALESCE here).
-- ============================================================
CREATE OR REPLACE FUNCTION public.trg_draft_deals_promoted_sync_intake_review_v1()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.promoted_deal_id IS NOT NULL
     AND OLD.promoted_deal_id IS DISTINCT FROM NEW.promoted_deal_id
  THEN
    UPDATE public.intake_submissions s
    SET reviewed_at    = COALESCE(s.reviewed_at, now()),
        review_status  = 'reviewed',
        review_outcome = 'promoted'
    WHERE s.tenant_id = NEW.tenant_id
      AND s.draft_deals_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$fn$;

ALTER FUNCTION public.trg_draft_deals_promoted_sync_intake_review_v1() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.trg_draft_deals_promoted_sync_intake_review_v1() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_draft_deals_promoted_sync_intake_review ON public.draft_deals;
CREATE TRIGGER trg_draft_deals_promoted_sync_intake_review
  AFTER UPDATE OF promoted_deal_id ON public.draft_deals
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_draft_deals_promoted_sync_intake_review_v1();
