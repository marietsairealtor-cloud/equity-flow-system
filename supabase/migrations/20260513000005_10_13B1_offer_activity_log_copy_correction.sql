-- 10.13B1: Offer Backend -- Activity Log Copy Correction
-- Redefines send_offer_v1 to update user-facing deal_activity_log content only.
-- No behavior change to stage transition, idempotency, reminder creation, auth, signature, or return envelope.

DROP FUNCTION IF EXISTS public.send_offer_v1(uuid, text);

CREATE FUNCTION public.send_offer_v1(p_deal_id uuid, p_idempotency_key text)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant           uuid;
  v_user             uuid;
  v_claimed          boolean;
  v_stored           jsonb;
  v_stage            text;
  v_soft_offer_id    uuid;
  v_reminder_id      uuid;
  v_reminder_at      timestamptz;
  v_result           jsonb;
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

  v_user := auth.uid();

  IF v_user IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant or user context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_idempotency_key IS NULL OR length(trim(p_idempotency_key)) = 0 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'p_idempotency_key is required.',
        'fields', jsonb_build_object('p_idempotency_key', 'required')
      )
    );
  END IF;

  SELECT result_json INTO v_stored
  FROM public.rpc_idempotency_log
  WHERE user_id = v_user
    AND idempotency_key = trim(p_idempotency_key)
    AND rpc_name = 'send_offer_v1';

  IF FOUND THEN
    RETURN v_stored;
  END IF;

  v_tenant := public.current_tenant_id();

  IF v_tenant IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
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
      'error', jsonb_build_object('message', 'p_deal_id is required', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT d.stage INTO v_stage
  FROM public.deals d
  WHERE d.id = p_deal_id
    AND d.tenant_id = v_tenant
    AND d.deleted_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Deal not found', 'fields', '{}'::jsonb)
    );
  END IF;

  IF v_stage = 'offer_sent' THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Offer already sent for this deal', 'fields', '{}'::jsonb)
    );
  END IF;

  IF v_stage <> 'analyzing' THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'send_offer_v1 requires deal stage analyzing',
        'fields', jsonb_build_object('stage', v_stage)
      )
    );
  END IF;

  SELECT dso.id INTO v_soft_offer_id
  FROM public.deal_soft_offers dso
  WHERE dso.tenant_id = v_tenant
    AND dso.deal_id = p_deal_id
  ORDER BY dso.created_at DESC
  LIMIT 1;

  IF v_soft_offer_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'Persisted soft offer required before send (refresh_deal_soft_offer_v1)',
        'fields', jsonb_build_object('deal_soft_offer', 'missing')
      )
    );
  END IF;

  v_reminder_id := gen_random_uuid();
  v_reminder_at := clock_timestamp() + interval '3 days';

  v_result := jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'deal_id', p_deal_id,
      'stage', 'offer_sent',
      'deal_soft_offer_id', v_soft_offer_id,
      'reminder_id', v_reminder_id,
      'reminder_date', to_char(v_reminder_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    ),
    'error', null
  );

  INSERT INTO public.rpc_idempotency_log
    (user_id, idempotency_key, rpc_name, result_json)
  VALUES
    (v_user, trim(p_idempotency_key), 'send_offer_v1', v_result)
  ON CONFLICT (user_id, idempotency_key, rpc_name)
    DO UPDATE SET result_json = public.rpc_idempotency_log.result_json
  RETURNING (xmax = 0) INTO v_claimed;

  IF NOT v_claimed THEN
    SELECT result_json INTO v_result
    FROM public.rpc_idempotency_log
    WHERE user_id = v_user
      AND idempotency_key = trim(p_idempotency_key)
      AND rpc_name = 'send_offer_v1';
    RETURN v_result;
  END IF;

  UPDATE public.deals
  SET
    stage       = 'offer_sent',
    updated_at  = now(),
    row_version = row_version + 1
  WHERE id = p_deal_id
    AND tenant_id = v_tenant;

  INSERT INTO public.deal_reminders (
    id, deal_id, tenant_id, reminder_date, reminder_type
  ) VALUES (
    v_reminder_id, p_deal_id, v_tenant, v_reminder_at, 'offer_follow_up'
  );

  INSERT INTO public.deal_activity_log (
    tenant_id, deal_id, activity_type, content, created_by, created_at
  ) VALUES (
    v_tenant, p_deal_id, 'stage_change',
    'Offer sent to seller',
    v_user, now()
  );

  RETURN v_result;
END;
$fn$;

ALTER FUNCTION public.send_offer_v1(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.send_offer_v1(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_offer_v1(uuid, text) TO authenticated;
