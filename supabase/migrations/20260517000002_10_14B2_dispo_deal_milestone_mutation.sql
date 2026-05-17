-- 10.14B2: Dispo Backend -- Deal Milestone Timestamp Mutation
-- set_dispo_deal_milestone_v1(p_deal_id uuid, p_milestone text, p_is_complete boolean)
-- Sets or clears assignment_agreement_signed_at / earnest_money_received_at on dispo deals.
-- Writes deal_activity_log on every successful mutation.
-- Forward-only plain SQL. No DO blocks.

CREATE FUNCTION public.set_dispo_deal_milestone_v1(
  p_deal_id    uuid,
  p_milestone  text,
  p_is_complete boolean
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant    uuid;
  v_user      uuid;
  v_stage     text;
  v_activity  text;
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
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant or user context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only.', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_deal_id is required', 'fields', jsonb_build_object('p_deal_id', 'required'))
    );
  END IF;

  IF p_milestone IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_milestone is required', 'fields', jsonb_build_object('p_milestone', 'required'))
    );
  END IF;

  IF p_is_complete IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_is_complete is required', 'fields', jsonb_build_object('p_is_complete', 'required'))
    );
  END IF;

  IF p_milestone NOT IN ('assignment_agreement_signed', 'earnest_money_received') THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid milestone. Allowed: assignment_agreement_signed, earnest_money_received', 'fields', jsonb_build_object('p_milestone', 'invalid'))
    );
  END IF;

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Deal not found', 'fields', '{}'::jsonb)
    );
  END IF;

  IF v_stage <> 'dispo' THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Milestone mutation is only allowed for deals in Dispo stage', 'fields', jsonb_build_object('stage', v_stage))
    );
  END IF;

  IF p_milestone = 'assignment_agreement_signed' THEN
    UPDATE public.deals
    SET assignment_agreement_signed_at = CASE WHEN p_is_complete THEN now() ELSE NULL END,
        updated_at  = now(),
        row_version = row_version + 1
    WHERE id = p_deal_id AND tenant_id = v_tenant;
    v_activity := CASE WHEN p_is_complete
      THEN 'Assignment agreement marked signed'
      ELSE 'Assignment agreement marked unsigned'
    END;
  ELSE
    UPDATE public.deals
    SET earnest_money_received_at = CASE WHEN p_is_complete THEN now() ELSE NULL END,
        updated_at  = now(),
        row_version = row_version + 1
    WHERE id = p_deal_id AND tenant_id = v_tenant;
    v_activity := CASE WHEN p_is_complete
      THEN 'Earnest money marked received'
      ELSE 'Earnest money marked not received'
    END;
  END IF;

  INSERT INTO public.deal_activity_log (
    tenant_id, deal_id, activity_type, content, created_by, created_at
  ) VALUES (
    v_tenant, p_deal_id, 'milestone', v_activity, v_user, now()
  );

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'deal_id',    p_deal_id,
      'milestone',  p_milestone,
      'is_complete', p_is_complete
    ),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.set_dispo_deal_milestone_v1(uuid, text, boolean) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.set_dispo_deal_milestone_v1(uuid, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_dispo_deal_milestone_v1(uuid, text, boolean) TO authenticated;