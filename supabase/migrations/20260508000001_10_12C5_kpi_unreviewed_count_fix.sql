-- 10.12C5 — Intake Backend — KPI Queue Count Correction
-- unreviewed_count: seller/birddog + review_status = 'unreviewed' only (buyer excluded)

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
    AND review_status = 'unreviewed'
    AND form_type IN ('seller', 'birddog');

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
