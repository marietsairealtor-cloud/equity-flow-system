-- 10.14B: Dispo Backend — Share Link + Handoff Control (schema + governed handoffs)
-- - deals: timestamps required before Send to TC (Build Route 10.14B DoD).
-- - handoff_to_tc_v1: gate on both timestamps; persist assignee handoff notification row.
-- - return_to_acq_v1: auth user guard + deal_activity_log (governed return path).
-- Share-token create/revoke/lookup contracts remain prior migrations (8.x / 9.x / 10.8.11N).

-- ============================================================
-- deals: Dispo → TC prerequisite timestamps
-- ============================================================
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS assignment_agreement_signed_at timestamptz NULL,
  ADD COLUMN IF NOT EXISTS earnest_money_received_at     timestamptz NULL;

COMMENT ON COLUMN public.deals.assignment_agreement_signed_at IS
  '10.14B: assignment agreement signed — required with earnest_money_received_at before handoff_to_tc_v1.';
COMMENT ON COLUMN public.deals.earnest_money_received_at IS
  '10.14B: earnest money / deposit received — required with assignment_agreement_signed_at before handoff_to_tc_v1.';

-- ============================================================
-- workspace_handoff_notifications — append-only recipient signals (no client table access)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.workspace_handoff_notifications (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid        NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  recipient_user_id   uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  deal_id             uuid        NOT NULL REFERENCES public.deals(id) ON DELETE CASCADE,
  kind                text        NOT NULL DEFAULT 'handoff_to_tc',
  created_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT workspace_handoff_notifications_kind_check CHECK (kind = 'handoff_to_tc')
);

CREATE INDEX IF NOT EXISTS workspace_handoff_notifications_recipient_created_idx
  ON public.workspace_handoff_notifications (recipient_user_id, created_at DESC);

ALTER TABLE public.workspace_handoff_notifications OWNER TO postgres;

ALTER TABLE public.workspace_handoff_notifications ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.workspace_handoff_notifications FROM PUBLIC;
REVOKE ALL ON TABLE public.workspace_handoff_notifications FROM anon;
REVOKE ALL ON TABLE public.workspace_handoff_notifications FROM authenticated;

-- ============================================================
-- handoff_to_tc_v1 — prerequisites + assignee notification row
-- ============================================================
CREATE OR REPLACE FUNCTION public.handoff_to_tc_v1(
  p_deal_id          uuid,
  p_assignee_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
  v_user   uuid;
  v_stage  text;
  v_aa     timestamptz;
  v_em     timestamptz;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN json_build_object(
        'ok', false,
        'code', 'NOT_AUTHORIZED',
        'data', json_build_object(),
        'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
      );
  END;

  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant or user context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
    );
  END IF;

  SELECT stage, assignment_agreement_signed_at, earnest_money_received_at
  INTO v_stage, v_aa, v_em
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  IF v_stage <> 'dispo' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Handoff to TC is only allowed from Dispo stage', 'fields', json_build_object())
    );
  END IF;

  IF v_aa IS NULL OR v_em IS NULL THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'CONFLICT',
      'data', json_build_object(),
      'error', json_build_object(
        'message',
        'Send to TC requires assignment agreement signed and earnest money received timestamps.',
        'fields',
        json_build_object(
          'assignment_agreement_signed_at', CASE WHEN v_aa IS NULL THEN json_build_array('required') ELSE json_build_array() END,
          'earnest_money_received_at', CASE WHEN v_em IS NULL THEN json_build_array('required') ELSE json_build_array() END
        )
      )
    );
  END IF;

  IF p_assignee_user_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.tenant_memberships
    WHERE tenant_id = v_tenant AND user_id = p_assignee_user_id
  ) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Assignee is not a member of this workspace', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    stage            = 'tc',
    assignee_user_id = p_assignee_user_id,
    updated_at       = now(),
    row_version      = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  INSERT INTO public.deal_activity_log (
    tenant_id, deal_id, activity_type, content, created_by, created_at
  ) VALUES (
    v_tenant, p_deal_id, 'handoff', 'Deal handed off to TC', v_user, now()
  );

  IF p_assignee_user_id IS NOT NULL THEN
    INSERT INTO public.workspace_handoff_notifications (
      tenant_id, recipient_user_id, deal_id, kind, created_at
    ) VALUES (
      v_tenant, p_assignee_user_id, p_deal_id, 'handoff_to_tc', now()
    );
  END IF;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'tc', 'assignee_user_id', p_assignee_user_id),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.handoff_to_tc_v1(uuid, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.handoff_to_tc_v1(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.handoff_to_tc_v1(uuid, uuid) TO authenticated;

-- ============================================================
-- return_to_acq_v1 — user context + activity log
-- ============================================================
CREATE OR REPLACE FUNCTION public.return_to_acq_v1(
  p_deal_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
  v_user   uuid;
  v_stage  text;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN json_build_object(
        'ok', false,
        'code', 'NOT_AUTHORIZED',
        'data', json_build_object(),
        'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
      );
  END;

  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant or user context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
    );
  END IF;

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  IF v_stage <> 'dispo' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Return to Acq is only allowed from Dispo stage', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    stage       = 'under_contract',
    updated_at  = now(),
    row_version = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  INSERT INTO public.deal_activity_log (
    tenant_id, deal_id, activity_type, content, created_by, created_at
  ) VALUES (
    v_tenant, p_deal_id, 'handoff', 'Deal returned to Acq from Dispo', v_user, now()
  );

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'under_contract'),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.return_to_acq_v1(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.return_to_acq_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.return_to_acq_v1(uuid) TO authenticated;
