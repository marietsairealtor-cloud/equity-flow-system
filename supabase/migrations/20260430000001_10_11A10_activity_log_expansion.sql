-- 10.11A10: Acquisition Backend -- Activity Log Expansion
-- Adds activity log writes to governed state-changing RPCs
-- advance_deal_stage_v1: logs stage transition
-- handoff_to_dispo_v1: logs handoff event
-- complete_reminder_v1: logs reminder completion (idempotent -- only first completion logged)
-- mark_deal_dead_v1: already logs -- no change
-- create_deal_note_v1: does NOT log -- notes stream is separate
-- deal_activity_log remains system-events only

-- 1. advance_deal_stage_v1 -- add activity log write + user context guard
CREATE OR REPLACE FUNCTION public.advance_deal_stage_v1(p_deal_id uuid, p_action text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant    uuid;
  v_user      uuid;
  v_stage     text;
  v_new_stage text;
  v_content   text;
BEGIN
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

  IF p_action = 'start_analysis' AND v_stage = 'new' THEN
    v_new_stage := 'analyzing';
    v_content   := 'Stage advanced to Analyzing';
  ELSIF p_action = 'send_offer' AND v_stage = 'analyzing' THEN
    v_new_stage := 'offer_sent';
    v_content   := 'Stage advanced to Offer Sent';
  ELSIF p_action = 'mark_contract_signed' AND v_stage = 'offer_sent' THEN
    v_new_stage := 'under_contract';
    v_content   := 'Stage advanced to Under Contract';
  ELSE
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid stage transition for current deal state', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    stage       = v_new_stage,
    updated_at  = now(),
    row_version = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  INSERT INTO public.deal_activity_log (tenant_id, deal_id, activity_type, content, created_by, created_at)
  VALUES (v_tenant, p_deal_id, 'stage_change', v_content, v_user, now());

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', v_new_stage),
    'error', null
  );
END;
$fn$;

-- 2. handoff_to_dispo_v1 -- add activity log write + user context guard
CREATE OR REPLACE FUNCTION public.handoff_to_dispo_v1(p_deal_id uuid, p_assignee_user_id uuid)
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

  IF v_stage <> 'under_contract' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Handoff to Dispo is only allowed from Under Contract stage', 'fields', json_build_object())
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
    stage              = 'dispo',
    assignee_user_id   = p_assignee_user_id,
    updated_at         = now(),
    row_version        = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  INSERT INTO public.deal_activity_log (tenant_id, deal_id, activity_type, content, created_by, created_at)
  VALUES (v_tenant, p_deal_id, 'handoff', 'Deal handed off to Dispo', v_user, now());

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'dispo', 'assignee_user_id', p_assignee_user_id),
    'error', null
  );
END;
$fn$;

-- 3. complete_reminder_v1 -- add already-completed guard + activity log write
CREATE OR REPLACE FUNCTION public.complete_reminder_v1(p_reminder_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant   uuid;
  v_user     uuid;
  v_reminder record;
BEGIN
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
      'ok', false, 'code', 'WORKSPACE_NOT_WRITABLE', 'data', json_build_object(),
      'error', json_build_object('message', 'Workspace is not active', 'fields', json_build_object())
    );
  END IF;

  SELECT * INTO v_reminder
  FROM public.deal_reminders
  WHERE id = p_reminder_id AND tenant_id = v_tenant;

  -- Not found or cross-tenant: silent no-op (preserves idempotency contract)
  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', true, 'code', 'OK',
      'data', json_build_object('reminder_id', p_reminder_id),
      'error', null
    );
  END IF;

  -- Already completed: silent no-op -- no DB change, no activity row
  IF v_reminder.completed_at IS NOT NULL THEN
    RETURN json_build_object(
      'ok', true, 'code', 'OK',
      'data', json_build_object('reminder_id', p_reminder_id),
      'error', null
    );
  END IF;

  UPDATE public.deal_reminders
  SET completed_at = now()
  WHERE id = p_reminder_id AND tenant_id = v_tenant;

  INSERT INTO public.deal_activity_log (tenant_id, deal_id, activity_type, content, created_by, created_at)
  VALUES (v_tenant, v_reminder.deal_id, 'reminder_completed',
    'Reminder completed: ' || v_reminder.reminder_type, v_user, now());

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('reminder_id', p_reminder_id),
    'error', null
  );
END;
$fn$;