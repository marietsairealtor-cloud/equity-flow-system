-- 10.12C8: Intake Backend — mark_submission_reviewed_v1 Draft ID Support
-- Canonical signature (PostgreSQL-valid defaults): p_outcome first, then optional IDs.
-- Legacy overload (uuid, text) forwards for existing callers / pgTAP positional calls.
-- Authority prior behavior: 20260507000001_10_12C4_submission_review_outcomes.sql

DROP FUNCTION IF EXISTS public.mark_submission_reviewed_v1(uuid, text);

CREATE OR REPLACE FUNCTION public.mark_submission_reviewed_v1(
  p_outcome       text,
  p_submission_id uuid DEFAULT NULL,
  p_draft_id      uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant        uuid;
  v_row           public.intake_submissions%ROWTYPE;
  v_effective     uuid;
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

  IF p_submission_id IS NULL AND p_draft_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'p_submission_id or p_draft_id is required',
        'fields', '{}'::jsonb)
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

  IF p_submission_id IS NOT NULL THEN
    v_effective := p_submission_id;
  ELSE
    SELECT s.id INTO v_effective
    FROM public.intake_submissions s
    WHERE s.draft_deals_id = p_draft_id
      AND s.tenant_id = v_tenant;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'Submission not found', 'fields', '{}'::jsonb)
      );
    END IF;
  END IF;

  SELECT * INTO v_row
  FROM public.intake_submissions
  WHERE id = v_effective
    AND tenant_id = v_tenant;

  IF NOT FOUND THEN
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
        'data', jsonb_build_object('submission_id', v_effective),
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
  WHERE id = v_effective AND tenant_id = v_tenant;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object('submission_id', v_effective),
    'error', null
  );
END;
$fn$;

CREATE OR REPLACE FUNCTION public.mark_submission_reviewed_v1(
  p_submission_id uuid,
  p_outcome       text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $legacy$
BEGIN
  PERFORM public.current_tenant_id();
  RETURN public.mark_submission_reviewed_v1(p_outcome, p_submission_id, NULL::uuid);
END;
$legacy$;

ALTER FUNCTION public.mark_submission_reviewed_v1(text, uuid, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.mark_submission_reviewed_v1(text, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_submission_reviewed_v1(text, uuid, uuid) TO authenticated;

ALTER FUNCTION public.mark_submission_reviewed_v1(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.mark_submission_reviewed_v1(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_submission_reviewed_v1(uuid, text) TO authenticated;
