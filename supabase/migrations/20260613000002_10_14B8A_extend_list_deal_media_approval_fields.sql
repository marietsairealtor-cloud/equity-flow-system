-- 10.14B8A -- Dispo Dashboard Packet + Media Approval Read Extension
-- Migration 2 of 2: Extend list_deal_media_v1 to return
-- is_dispo_approved, dispo_approved_at, dispo_approved_by per media item.
-- No schema changes. No privilege changes. No public surface changes.

CREATE OR REPLACE FUNCTION public.list_deal_media_v1(p_deal_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
    );
  END;

  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
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
              'id',                m.id,
              'storage_path',      m.storage_path,
              'media_type',        m.media_type,
              'sort_order',        m.sort_order,
              'uploaded_at',       m.uploaded_at,
              'uploaded_by',       m.uploaded_by,
              'is_dispo_approved', m.is_dispo_approved,
              'dispo_approved_at', m.dispo_approved_at,
              'dispo_approved_by', m.dispo_approved_by
            )
            ORDER BY m.sort_order ASC, m.uploaded_at ASC
          )
          FROM public.deal_media m
          WHERE m.deal_id = p_deal_id AND m.tenant_id = v_tenant
        ),
        '[]'::json
      )
    ),
    'error', null
  );
END;
$fn$;
