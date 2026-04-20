-- 10.11A1: Acquisition Backend - Notes/Log Write Path and Activity Log Read Path
-- Creates deal_notes and deal_activity_log tables and four RPCs:
--   create_deal_note_v1, list_deal_notes_v1, list_deal_activity_v1
-- Retrofits mark_deal_dead_v1 to write system activity row on stage change.
-- deal_notes is append-only: updated_at exists per DoD, no row_version, no edit RPC.
-- Stream separation: user notes -> deal_notes only. System events -> deal_activity_log only.

-- ============================================================
-- TABLE: deal_notes
-- ============================================================
CREATE TABLE public.deal_notes (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid        NOT NULL REFERENCES public.tenants(id),
  deal_id      uuid        NOT NULL REFERENCES public.deals(id),
  note_type    text        NOT NULL,
  content      text        NOT NULL,
  created_by   uuid        NOT NULL REFERENCES auth.users(id),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT deal_notes_note_type_check CHECK (note_type IN ('note', 'call_log'))
);

ALTER TABLE public.deal_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY deal_notes_tenant_isolation ON public.deal_notes
  USING (tenant_id = public.current_tenant_id());

REVOKE ALL ON public.deal_notes FROM anon, authenticated;

-- ============================================================
-- TABLE: deal_activity_log
-- ============================================================
CREATE TABLE public.deal_activity_log (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid        NOT NULL REFERENCES public.tenants(id),
  deal_id       uuid        NOT NULL REFERENCES public.deals(id),
  activity_type text        NOT NULL,
  content       text        NOT NULL,
  created_by    uuid        REFERENCES auth.users(id),
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.deal_activity_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY deal_activity_log_tenant_isolation ON public.deal_activity_log
  USING (tenant_id = public.current_tenant_id());

REVOKE ALL ON public.deal_activity_log FROM anon, authenticated;

-- ============================================================
-- RPC: create_deal_note_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_deal_note_v1(
  p_deal_id   uuid,
  p_note_type text,
  p_content   text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant  uuid;
  v_user    uuid;
  v_deal    uuid;
  v_note_id uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No tenant or user context', 'fields', '{}'::json)
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'WORKSPACE_NOT_WRITABLE',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Workspace is not active', 'fields', '{}'::json)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_deal_id is required', 'fields', '{}'::json)
    );
  END IF;

  IF p_note_type IS NULL OR p_note_type NOT IN ('note', 'call_log') THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_note_type must be note or call_log', 'fields', '{}'::json)
    );
  END IF;

  IF p_content IS NULL OR trim(p_content) = '' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_content is required', 'fields', '{}'::json)
    );
  END IF;

  SELECT id INTO v_deal
  FROM public.deals
  WHERE id        = p_deal_id
    AND tenant_id = v_tenant
    AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
    );
  END IF;

  INSERT INTO public.deal_notes (tenant_id, deal_id, note_type, content, created_by)
  VALUES (v_tenant, p_deal_id, p_note_type, trim(p_content), v_user)
  RETURNING id INTO v_note_id;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('note_id', v_note_id),
    'error', null
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.create_deal_note_v1(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_deal_note_v1(uuid, text, text) TO authenticated;

-- ============================================================
-- RPC: list_deal_notes_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_deal_notes_v1(
  p_deal_id uuid
)
RETURNS json
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
  v_user   uuid;
  v_deal   uuid;
  v_result json;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No tenant or user context', 'fields', '{}'::json)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_deal_id is required', 'fields', '{}'::json)
    );
  END IF;

  SELECT id INTO v_deal
  FROM public.deals
  WHERE id        = p_deal_id
    AND tenant_id = v_tenant
    AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
    );
  END IF;

  SELECT json_agg(
    json_build_object(
      'note_id',        dn.id,
      'deal_id',        dn.deal_id,
      'note_type',      dn.note_type,
      'content',        dn.content,
      'created_by',     dn.created_by,
      'created_by_name', COALESCE(up.display_name, ''),
      'created_at',     dn.created_at,
      'updated_at',     dn.updated_at
    ) ORDER BY dn.created_at DESC
  )
  INTO v_result
  FROM public.deal_notes dn
  LEFT JOIN public.user_profiles up ON up.id = dn.created_by
  WHERE dn.deal_id   = p_deal_id
    AND dn.tenant_id = v_tenant;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('notes', COALESCE(v_result, '[]'::json)),
    'error', null
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.list_deal_notes_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_deal_notes_v1(uuid) TO authenticated;

-- ============================================================
-- RPC: list_deal_activity_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_deal_activity_v1(
  p_deal_id uuid
)
RETURNS json
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
  v_user   uuid;
  v_deal   uuid;
  v_result json;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No tenant or user context', 'fields', '{}'::json)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_deal_id is required', 'fields', '{}'::json)
    );
  END IF;

  SELECT id INTO v_deal
  FROM public.deals
  WHERE id        = p_deal_id
    AND tenant_id = v_tenant
    AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
    );
  END IF;

  SELECT json_agg(
    json_build_object(
      'activity_id',    fa.id,
      'deal_id',        fa.deal_id,
      'activity_type',  fa.activity_type,
      'content',        fa.content,
      'created_by',     fa.created_by,
      'created_by_name', COALESCE(up.display_name, ''),
      'created_at',     fa.created_at
    ) ORDER BY fa.created_at DESC
  )
  INTO v_result
  FROM public.deal_activity_log fa
  LEFT JOIN public.user_profiles up ON up.id = fa.created_by
  WHERE fa.deal_id   = p_deal_id
    AND fa.tenant_id = v_tenant;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('activity', COALESCE(v_result, '[]'::json)),
    'error', null
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.list_deal_activity_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_deal_activity_v1(uuid) TO authenticated;

-- ============================================================
-- RETROFIT: mark_deal_dead_v1
-- Adds deal_activity_log insert after stage update.
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_deal_dead_v1(p_deal_id uuid, p_dead_reason text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
  v_stage  text;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
    );
  END IF;

  IF p_dead_reason IS NULL OR trim(p_dead_reason) = '' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Dead reason is required', 'fields', json_build_object('dead_reason', 'required'))
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

  IF v_stage IN ('closed', 'dead') THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal is already in a terminal stage', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    stage       = 'dead',
    dead_reason = p_dead_reason,
    updated_at  = now(),
    row_version = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  INSERT INTO public.deal_activity_log (tenant_id, deal_id, activity_type, content, created_by)
  VALUES (v_tenant, p_deal_id, 'marked_dead', 'Deal marked dead', auth.uid());

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'dead'),
    'error', null
  );
END;
$fn$;