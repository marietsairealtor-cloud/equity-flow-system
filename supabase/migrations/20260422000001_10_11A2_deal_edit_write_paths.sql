-- 10.11A2: Acquisition Backend -- Seller / Property Edit Write Paths
-- Adds update_deal_seller_v1 and update_deal_property_v1
-- Uses jsonb payload to distinguish omitted fields from intentional NULL clears.
-- Rejects empty payload, unknown keys, invalid jsonb shape, invalid timestamps.
-- Rejects same-value no-op submissions via IS DISTINCT FROM guard.
-- No schema changes. No new tables. No changes to update_deal_v1.

-- ============================================================
-- RPC: update_deal_seller_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_deal_seller_v1(
  p_deal_id uuid,
  p_fields  jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant        uuid;
  v_user          uuid;
  v_rows_updated  int;
  v_deal_exists   boolean;
  v_allowed_keys  text[] := ARRAY[
    'seller_name','seller_phone','seller_email',
    'seller_pain','seller_timeline','seller_notes'
  ];
  v_unknown_keys  text[];
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

  IF p_fields IS NULL OR jsonb_typeof(p_fields) <> 'object' OR p_fields = '{}'::jsonb THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_fields must be a non-empty JSON object', 'fields', '{}'::json)
    );
  END IF;

  -- Reject unknown keys
  SELECT ARRAY(
    SELECT jsonb_object_keys(p_fields)
    EXCEPT
    SELECT unnest(v_allowed_keys)
  ) INTO v_unknown_keys;

  IF array_length(v_unknown_keys, 1) > 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Unknown fields: ' || array_to_string(v_unknown_keys, ', '), 'fields', '{}'::json)
    );
  END IF;

  -- UPDATE only if at least one provided field IS DISTINCT FROM current value
  UPDATE public.deals
  SET
    seller_name     = CASE WHEN p_fields ? 'seller_name'     THEN (p_fields->>'seller_name')     ELSE seller_name     END,
    seller_phone    = CASE WHEN p_fields ? 'seller_phone'    THEN (p_fields->>'seller_phone')    ELSE seller_phone    END,
    seller_email    = CASE WHEN p_fields ? 'seller_email'    THEN (p_fields->>'seller_email')    ELSE seller_email    END,
    seller_pain     = CASE WHEN p_fields ? 'seller_pain'     THEN (p_fields->>'seller_pain')     ELSE seller_pain     END,
    seller_timeline = CASE WHEN p_fields ? 'seller_timeline' THEN (p_fields->>'seller_timeline') ELSE seller_timeline END,
    seller_notes    = CASE WHEN p_fields ? 'seller_notes'    THEN (p_fields->>'seller_notes')    ELSE seller_notes    END,
    updated_at      = now(),
    row_version     = row_version + 1
  WHERE id        = p_deal_id
    AND tenant_id = v_tenant
    AND deleted_at IS NULL
    AND (
      (p_fields ? 'seller_name'     AND (p_fields->>'seller_name')     IS DISTINCT FROM seller_name)     OR
      (p_fields ? 'seller_phone'    AND (p_fields->>'seller_phone')    IS DISTINCT FROM seller_phone)    OR
      (p_fields ? 'seller_email'    AND (p_fields->>'seller_email')    IS DISTINCT FROM seller_email)    OR
      (p_fields ? 'seller_pain'     AND (p_fields->>'seller_pain')     IS DISTINCT FROM seller_pain)     OR
      (p_fields ? 'seller_timeline' AND (p_fields->>'seller_timeline') IS DISTINCT FROM seller_timeline) OR
      (p_fields ? 'seller_notes'    AND (p_fields->>'seller_notes')    IS DISTINCT FROM seller_notes)
    );

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    -- Disambiguate: not found vs no actual changes
    SELECT EXISTS (
      SELECT 1 FROM public.deals
      WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL
    ) INTO v_deal_exists;

    IF NOT v_deal_exists THEN
      RETURN json_build_object(
        'ok',    false,
        'code',  'NOT_FOUND',
        'data',  '{}'::json,
        'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
      );
    ELSE
      RETURN json_build_object(
        'ok',    false,
        'code',  'VALIDATION_ERROR',
        'data',  '{}'::json,
        'error', json_build_object('message', 'No actual changes provided', 'fields', '{}'::json)
      );
    END IF;
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id),
    'error', null
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.update_deal_seller_v1(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_deal_seller_v1(uuid, jsonb) TO authenticated;

-- ============================================================
-- RPC: update_deal_property_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_deal_property_v1(
  p_deal_id uuid,
  p_fields  jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant        uuid;
  v_user          uuid;
  v_rows_updated  int;
  v_deal_exists   boolean;
  v_allowed_keys  text[] := ARRAY['address','next_action','next_action_due'];
  v_unknown_keys  text[];
  v_next_action_due timestamptz;
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

  IF p_fields IS NULL OR jsonb_typeof(p_fields) <> 'object' OR p_fields = '{}'::jsonb THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_fields must be a non-empty JSON object', 'fields', '{}'::json)
    );
  END IF;

  -- Reject unknown keys
  SELECT ARRAY(
    SELECT jsonb_object_keys(p_fields)
    EXCEPT
    SELECT unnest(v_allowed_keys)
  ) INTO v_unknown_keys;

  IF array_length(v_unknown_keys, 1) > 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Unknown fields: ' || array_to_string(v_unknown_keys, ', '), 'fields', '{}'::json)
    );
  END IF;

  -- Validate next_action_due format if provided and not null
  IF p_fields ? 'next_action_due' AND p_fields->>'next_action_due' IS NOT NULL THEN
    BEGIN
      v_next_action_due := (p_fields->>'next_action_due')::timestamptz;
    EXCEPTION WHEN others THEN
      RETURN json_build_object(
        'ok',    false,
        'code',  'VALIDATION_ERROR',
        'data',  '{}'::json,
        'error', json_build_object('message', 'next_action_due is not a valid timestamp', 'fields', '{}'::json)
      );
    END;
  END IF;

  -- UPDATE only if at least one provided field IS DISTINCT FROM current value
  UPDATE public.deals
  SET
    address         = CASE WHEN p_fields ? 'address'         THEN (p_fields->>'address')          ELSE address         END,
    next_action     = CASE WHEN p_fields ? 'next_action'     THEN (p_fields->>'next_action')      ELSE next_action     END,
    next_action_due = CASE WHEN p_fields ? 'next_action_due' THEN v_next_action_due               ELSE next_action_due END,
    updated_at      = now(),
    row_version     = row_version + 1
  WHERE id        = p_deal_id
    AND tenant_id = v_tenant
    AND deleted_at IS NULL
    AND (
      (p_fields ? 'address'         AND (p_fields->>'address')     IS DISTINCT FROM address)         OR
      (p_fields ? 'next_action'     AND (p_fields->>'next_action') IS DISTINCT FROM next_action)     OR
      (p_fields ? 'next_action_due' AND v_next_action_due          IS DISTINCT FROM next_action_due)
    );

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    -- Disambiguate: not found vs no actual changes
    SELECT EXISTS (
      SELECT 1 FROM public.deals
      WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL
    ) INTO v_deal_exists;

    IF NOT v_deal_exists THEN
      RETURN json_build_object(
        'ok',    false,
        'code',  'NOT_FOUND',
        'data',  '{}'::json,
        'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
      );
    ELSE
      RETURN json_build_object(
        'ok',    false,
        'code',  'VALIDATION_ERROR',
        'data',  '{}'::json,
        'error', json_build_object('message', 'No actual changes provided', 'fields', '{}'::json)
      );
    END IF;
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id),
    'error', null
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.update_deal_property_v1(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_deal_property_v1(uuid, jsonb) TO authenticated;