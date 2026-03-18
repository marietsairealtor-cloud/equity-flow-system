-- 20260318000001_10_8_3_reminder_engine.sql
-- Build Route 10.8.3: Reminder Engine
-- deal_reminders table + list_reminders_v1, create_reminder_v1, complete_reminder_v1

-- ============================================================
-- 1) deal_reminders table
-- ============================================================

CREATE TABLE public.deal_reminders (
  id            uuid        NOT NULL DEFAULT gen_random_uuid(),
  deal_id       uuid        NOT NULL,
  tenant_id     uuid        NOT NULL,
  reminder_date timestamptz NOT NULL,
  reminder_type text        NOT NULL,
  completed_at  timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT deal_reminders_pkey PRIMARY KEY (id),
  CONSTRAINT deal_reminders_deal_id_fkey FOREIGN KEY (deal_id)
    REFERENCES public.deals (id) ON DELETE CASCADE,
  CONSTRAINT deal_reminders_tenant_id_fkey FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id) ON DELETE CASCADE
);

-- RLS ON -- default deny per GUARDRAILS §11
ALTER TABLE public.deal_reminders ENABLE ROW LEVEL SECURITY;

-- CONTRACTS §12 -- no direct access
REVOKE ALL ON TABLE public.deal_reminders FROM anon, authenticated;

-- ============================================================
-- 2) list_reminders_v1
-- ============================================================

CREATE FUNCTION public.list_reminders_v1()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
  v_user   uuid;
  v_items  json;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'No tenant or user context', 'fields', json_build_object())
    );
  END IF;

  -- Verify tenant membership
  IF NOT EXISTS (
    SELECT 1 FROM public.tenant_memberships tm
    WHERE tm.tenant_id = v_tenant AND tm.user_id = v_user
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'Not a member of this tenant', 'fields', json_build_object())
    );
  END IF;

  SELECT json_agg(
    json_build_object(
      'id',            dr.id,
      'deal_id',       dr.deal_id,
      'tenant_id',     dr.tenant_id,
      'reminder_date', dr.reminder_date,
      'reminder_type', dr.reminder_type,
      'completed_at',  dr.completed_at,
      'created_at',    dr.created_at,
      'overdue',       (dr.reminder_date < now() AND dr.completed_at IS NULL)
    )
    ORDER BY dr.reminder_date ASC
  )
  INTO v_items
  FROM public.deal_reminders dr
  WHERE dr.tenant_id = v_tenant
    AND dr.completed_at IS NULL;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('items', COALESCE(v_items, '[]'::json)),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.list_reminders_v1() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.list_reminders_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_reminders_v1() TO authenticated;

-- ============================================================
-- 3) create_reminder_v1
-- ============================================================

CREATE FUNCTION public.create_reminder_v1(
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
  -- Role enforcement first (CONTRACTS §8, Build Route 7.8)
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

  -- Validate inputs
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

  -- Verify deal belongs to tenant
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

ALTER FUNCTION public.create_reminder_v1(uuid, timestamptz, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.create_reminder_v1(uuid, timestamptz, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_reminder_v1(uuid, timestamptz, text) TO authenticated;

-- ============================================================
-- 4) complete_reminder_v1
-- ============================================================

CREATE FUNCTION public.complete_reminder_v1(
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
  -- Role enforcement first (CONTRACTS §8, Build Route 7.8)
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

  -- Idempotent update -- only update if belongs to tenant and not already completed
  UPDATE public.deal_reminders
  SET completed_at = now()
  WHERE id = p_reminder_id
    AND tenant_id = v_tenant
    AND completed_at IS NULL;

  -- Silently succeed whether or not row was updated (idempotent)
  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('id', p_reminder_id),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.complete_reminder_v1(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.complete_reminder_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_reminder_v1(uuid) TO authenticated;
