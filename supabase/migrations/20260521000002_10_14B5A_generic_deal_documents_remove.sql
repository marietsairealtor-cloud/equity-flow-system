-- 10.14B5A: Generic Deal Document Vault + Remove Path
-- Extends deal_documents: adds soft-delete columns, allows document_type = 'general',
-- adds delete_deal_document_v1, updates list_deal_documents_v1 to exclude deleted rows,
-- removes APS hard gate from handoff_to_dispo_v1.
-- All existing behavior preserved. Return types unchanged (json).

-- 1. Add soft-delete columns to deal_documents
ALTER TABLE public.deal_documents
  ADD COLUMN deleted_at timestamptz NULL,
  ADD COLUMN deleted_by uuid         NULL;

COMMENT ON COLUMN public.deal_documents.deleted_at IS
  '10.14B5A: Soft-delete timestamp. NULL = active. Set by delete_deal_document_v1.';
COMMENT ON COLUMN public.deal_documents.deleted_by IS
  '10.14B5A: auth.uid() of operator who soft-deleted the row.';
COMMENT ON COLUMN public.deal_documents.document_type IS
  '10.14B5A: Allowed values: signed_purchase_agreement, general';

-- 2. attach_deal_document_v1: allow document_type = general
-- Signature, return type, guard order, and path validation unchanged from B5.
CREATE OR REPLACE FUNCTION public.attach_deal_document_v1(
  p_deal_id       uuid,
  p_document_type text,
  p_storage_path  text,
  p_file_name     text,
  p_mime_type     text,
  p_file_size     bigint
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant      uuid;
  v_user        uuid;
  v_doc_id      uuid;
  v_allowed_types text[] := ARRAY['signed_purchase_agreement', 'general'];
  v_expected_prefix text;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::json,
      'error', json_build_object('message', 'No tenant or user context', 'fields', '{}'::json)
    );
  END IF;

  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::json,
      'error', json_build_object('message', 'Not authorized', 'fields', '{}'::json)
    );
  END;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'WORKSPACE_NOT_WRITABLE', 'data', '{}'::json,
      'error', json_build_object('message', 'Workspace is not active', 'fields', '{}'::json)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
      'error', json_build_object('message', 'p_deal_id is required', 'fields', '{}'::json)
    );
  END IF;

  IF p_document_type IS NULL OR NOT (p_document_type = ANY(v_allowed_types)) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
      'error', json_build_object('message', 'Invalid document_type. Allowed: signed_purchase_agreement, general', 'fields', '{}'::json)
    );
  END IF;

  IF p_file_name IS NULL OR trim(p_file_name) = '' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
      'error', json_build_object('message', 'p_file_name is required', 'fields', '{}'::json)
    );
  END IF;

  IF p_mime_type IS NULL OR trim(p_mime_type) = '' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
      'error', json_build_object('message', 'p_mime_type is required', 'fields', '{}'::json)
    );
  END IF;

  IF p_file_size IS NULL OR p_file_size <= 0 THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
      'error', json_build_object('message', 'p_file_size must be a positive integer', 'fields', '{}'::json)
    );
  END IF;

  v_expected_prefix := v_tenant::text || '/' || p_deal_id::text || '/documents/' || p_document_type || '/';
  IF p_storage_path IS NULL
    OR NOT starts_with(p_storage_path, v_expected_prefix)
    OR length(p_storage_path) <= length(v_expected_prefix)
    OR p_storage_path LIKE '/%'
    OR p_storage_path LIKE '%//%'
    OR p_storage_path LIKE '%..%'
    OR length(trim(p_storage_path)) = 0
  THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
      'error', json_build_object('message', 'storage_path must follow convention: {tenant_id}/{deal_id}/documents/{document_type}/{filename} with no unsafe segments', 'fields', '{}'::json)
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.deals
    WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL
  ) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', '{}'::json,
      'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
    );
  END IF;

  INSERT INTO public.deal_documents (
    tenant_id, deal_id, document_type, storage_path,
    file_name, mime_type, file_size, uploaded_by, uploaded_at, created_at
  )
  VALUES (
    v_tenant, p_deal_id, p_document_type, p_storage_path,
    trim(p_file_name), trim(p_mime_type), p_file_size, v_user, now(), now()
  )
  RETURNING id INTO v_doc_id;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('document_id', v_doc_id, 'deal_id', p_deal_id),
    'error', null
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.attach_deal_document_v1(uuid, text, text, text, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.attach_deal_document_v1(uuid, text, text, text, text, bigint) TO authenticated;

-- 3. list_deal_documents_v1: exclude soft-deleted rows
-- Signature, return type, and guard order unchanged from B5.
CREATE OR REPLACE FUNCTION public.list_deal_documents_v1(p_deal_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
BEGIN
  v_tenant := public.current_tenant_id();

  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
    );
  END;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'p_deal_id is required', 'fields', json_build_object())
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.deals
    WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL
  ) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object(
      'items', COALESCE(
        (
          SELECT json_agg(
            json_build_object(
              'id',            dd.id,
              'document_type', dd.document_type,
              'storage_path',  dd.storage_path,
              'file_name',     dd.file_name,
              'mime_type',     dd.mime_type,
              'file_size',     dd.file_size,
              'uploaded_by',   dd.uploaded_by,
              'uploaded_at',   dd.uploaded_at,
              'created_at',    dd.created_at
            )
            ORDER BY dd.created_at DESC
          )
          FROM public.deal_documents dd
          WHERE dd.deal_id = p_deal_id
            AND dd.tenant_id = v_tenant
            AND dd.deleted_at IS NULL
        ),
        '[]'::json
      )
    ),
    'error', null
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.list_deal_documents_v1(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_deal_documents_v1(uuid) TO authenticated;

-- 4. delete_deal_document_v1: soft-delete only
-- Storage file deletion is out of scope.
CREATE OR REPLACE FUNCTION public.delete_deal_document_v1(
  p_document_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
  v_user   uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant or user context', 'fields', json_build_object())
    );
  END IF;

  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
    );
  END;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'WORKSPACE_NOT_WRITABLE', 'data', json_build_object(),
      'error', json_build_object('message', 'Workspace is not active', 'fields', json_build_object())
    );
  END IF;

  IF p_document_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'p_document_id is required', 'fields', json_build_object())
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.deal_documents
    WHERE id = p_document_id AND tenant_id = v_tenant AND deleted_at IS NULL
  ) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Document not found', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deal_documents
  SET deleted_at = now(),
      deleted_by = v_user
  WHERE id = p_document_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('document_id', p_document_id),
    'error', null
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.delete_deal_document_v1(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_deal_document_v1(uuid) TO authenticated;

-- 5. handoff_to_dispo_v1: remove APS hard gate only
-- All other behavior preserved exactly from B5: guard order, assignee membership check,
-- stage check, activity log, return shape, row_version increment.
CREATE OR REPLACE FUNCTION public.handoff_to_dispo_v1(
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
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant or user context', 'fields', json_build_object())
    );
  END IF;

  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
    );
  END;

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

  -- APS hard gate removed (10.14B5A). Send to Dispo modal shows reminder copy only.

  UPDATE public.deals SET
    stage            = 'dispo',
    assignee_user_id = p_assignee_user_id,
    updated_at       = now(),
    row_version      = row_version + 1
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

REVOKE EXECUTE ON FUNCTION public.handoff_to_dispo_v1(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handoff_to_dispo_v1(uuid, uuid) TO authenticated;
