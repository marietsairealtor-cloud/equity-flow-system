-- 20260318000002_10_8_3_fix_comment_encoding.sql
-- Fix: replace section sign with ASCII in create_reminder_v1 and complete_reminder_v1 comments
-- Internal comment change only -- interface identical (no DROP required per CONTRACTS §2)

CREATE OR REPLACE FUNCTION public.create_reminder_v1(
  p_deal_id       uuid,
  p_reminder_date timestamptz,
  p_reminder_type text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant      uuid;
  v_reminder_id uuid;
BEGIN
  -- Role enforcement first (CONTRACTS S8, Build Route 7.8)
  -- Caught and returned as JSON envelope per RPC contract
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
    );
  END;

  v_tenant := public.current_tenant_id();

  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  null,
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('deal_id', 'Required'))
    );
  END IF;

  IF p_reminder_date IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  null,
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('reminder_date', 'Required'))
    );
  END IF;

  IF p_reminder_type IS NULL OR trim(p_reminder_type) = '' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  null,
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('reminder_type', 'Required'))
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = p_deal_id AND d.tenant_id = v_tenant
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  null,
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  INSERT INTO public.deal_reminders (deal_id, tenant_id, reminder_date, reminder_type)
  VALUES (p_deal_id, v_tenant, p_reminder_date, p_reminder_type)
  RETURNING id INTO v_reminder_id;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('id', v_reminder_id),
    'error', null
  );
END;
$fn$;

CREATE OR REPLACE FUNCTION public.complete_reminder_v1(
  p_reminder_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
BEGIN
  -- Role enforcement first (CONTRACTS S8, Build Route 7.8)
  -- Caught and returned as JSON envelope per RPC contract
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
    );
  END;

  v_tenant := public.current_tenant_id();

  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF p_reminder_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  null,
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('reminder_id', 'Required'))
    );
  END IF;

  UPDATE public.deal_reminders
  SET completed_at = now()
  WHERE id = p_reminder_id
    AND tenant_id = v_tenant
    AND completed_at IS NULL;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('id', p_reminder_id),
    'error', null
  );
END;
$fn$;