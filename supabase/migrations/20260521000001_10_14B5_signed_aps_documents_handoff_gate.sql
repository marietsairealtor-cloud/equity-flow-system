-- 10.14B5: Acquisition Backend -- Signed APS Documents + Handoff Gate
-- Creates deal_documents table for document metadata storage.
-- Client uploads files directly to Supabase Storage.
-- attach_deal_document_v1: governed metadata record after upload.
-- list_deal_documents_v1: governed metadata read.
-- handoff_to_dispo_v1: extended to require signed_purchase_agreement before handoff.
-- create_deal_document_upload_v1 is explicitly out of scope.
-- No base64 document storage in DB.

-- deal_documents table
CREATE TABLE public.deal_documents (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid        NOT NULL REFERENCES public.tenants(id),
  deal_id       uuid        NOT NULL REFERENCES public.deals(id),
  document_type text        NOT NULL,
  storage_path  text        NOT NULL,
  file_name     text        NOT NULL,
  mime_type     text        NOT NULL,
  file_size     bigint      NOT NULL,
  uploaded_by   uuid        NOT NULL REFERENCES auth.users(id),
  uploaded_at   timestamptz NOT NULL DEFAULT now(),
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Tenant-scoped index
CREATE INDEX deal_documents_tenant_deal_idx ON public.deal_documents (tenant_id, deal_id);
CREATE INDEX deal_documents_document_type_idx ON public.deal_documents (tenant_id, deal_id, document_type);

-- RLS enabled but all access via RPCs (SECURITY DEFINER)
ALTER TABLE public.deal_documents ENABLE ROW LEVEL SECURITY;

-- Revoke direct table access
REVOKE ALL ON public.deal_documents FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.deal_documents IS
  '10.14B5: Governed document metadata. Files stored in Supabase Storage. No file content in DB.';
COMMENT ON COLUMN public.deal_documents.storage_path IS
  '10.14B5: Tenant/deal-scoped path convention: {tenant_id}/{deal_id}/documents/{document_type}/{filename}';
COMMENT ON COLUMN public.deal_documents.document_type IS
  '10.14B5: Allowed values: signed_purchase_agreement';

-- attach_deal_document_v1
-- Records governed document metadata after client uploads file to Supabase Storage.
-- storage_path validated against tenant/deal-scoped convention.
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
  v_allowed_types text[] := ARRAY['signed_purchase_agreement'];
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
      'error', json_build_object('message', 'Invalid document_type. Allowed: signed_purchase_agreement', 'fields', '{}'::json)
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

  -- Validate storage_path against full tenant/deal/document_type-scoped convention
  -- Expected prefix: {tenant_id}/{deal_id}/documents/{document_type}/
  -- Reject: null, leading slash, double slash, path traversal (..)
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

  -- Verify deal belongs to current tenant
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

-- list_deal_documents_v1
-- Returns document metadata for a deal. No file contents returned.
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
          WHERE dd.deal_id = p_deal_id AND dd.tenant_id = v_tenant
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

-- handoff_to_dispo_v1: extend with signed APS gate
-- New handoff attempts blocked unless signed_purchase_agreement exists.
-- Existing dispo deals grandfathered -- gate only applies at handoff time.
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

  -- Signed APS gate: block handoff if no signed_purchase_agreement document exists
  IF NOT EXISTS (
    SELECT 1 FROM public.deal_documents
    WHERE deal_id      = p_deal_id
      AND tenant_id    = v_tenant
      AND document_type = 'signed_purchase_agreement'
  ) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'A signed purchase agreement must be attached before handoff to Dispo', 'fields', json_build_object())
    );
  END IF;

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