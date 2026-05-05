-- 10.12C2: Intake Backend — Lead Intake KPI Read Path
-- RPC: get_lead_intake_kpis_v1 — server-computed KPIs + unreviewed queue count

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
  v_tenant                 uuid;
  v_from                   timestamptz;
  v_to                     timestamptz;
  v_new_leads              bigint;
  v_denom                  bigint;
  v_num                    bigint;
  v_submission_to_deal_pct integer;
  v_avg_review_h           numeric;
  v_unreviewed             bigint;
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

  SELECT COUNT(*) INTO v_new_leads
  FROM public.intake_submissions
  WHERE tenant_id = v_tenant
    AND submitted_at >= v_from
    AND submitted_at <= v_to;

  SELECT COUNT(*) INTO v_denom
  FROM public.intake_submissions
  WHERE tenant_id = v_tenant
    AND form_type IN ('seller', 'birddog')
    AND submitted_at >= v_from
    AND submitted_at <= v_to;

  SELECT COUNT(*) INTO v_num
  FROM public.intake_submissions s
  WHERE s.tenant_id = v_tenant
    AND s.form_type IN ('seller', 'birddog')
    AND s.submitted_at >= v_from
    AND s.submitted_at <= v_to
    AND s.draft_deals_id IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.draft_deals d
      WHERE d.id = s.draft_deals_id
        AND d.tenant_id = v_tenant
        AND d.promoted_deal_id IS NOT NULL
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
    AND reviewed_at IS NOT NULL
    AND submitted_at >= v_from
    AND submitted_at <= v_to;

  SELECT COUNT(*) INTO v_unreviewed
  FROM public.intake_submissions
  WHERE tenant_id = v_tenant
    AND reviewed_at IS NULL;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object(
      'new_leads',               v_new_leads,
      'submission_to_deal_pct', v_submission_to_deal_pct,
      'avg_review_time_hours',  v_avg_review_h,
      'unreviewed_count',       v_unreviewed,
      'date_from',              v_from,
      'date_to',                v_to
    ),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.get_lead_intake_kpis_v1(timestamptz, timestamptz) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.get_lead_intake_kpis_v1(timestamptz, timestamptz) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_lead_intake_kpis_v1(timestamptz, timestamptz) TO authenticated;
