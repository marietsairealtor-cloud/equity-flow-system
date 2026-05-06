-- 10.12C3: Intake Backend -- Lead Intake Submission List Filter
-- list_intake_submissions_v1: seller + birddog rows only for Lead Intake (buyers excluded).

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
      'id',              id,
      'form_type',       form_type,
      'payload',         payload,
      'source',          source,
      'submitted_at',    submitted_at,
      'reviewed_at',     reviewed_at,
      'draft_deals_id',  draft_deals_id
    ) AS r
    FROM public.intake_submissions
    WHERE tenant_id = v_tenant_id
      AND form_type IN ('seller', 'birddog')
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
