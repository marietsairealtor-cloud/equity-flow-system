-- 10.14B4C: ACQ Backend Cleanup -- Remove Unused Call Log Surface
-- create_deal_note_v1: rejects new note_type = 'call_log' with VALIDATION_ERROR
-- get_acq_deal_v1: removes last_contacted_at from output (no UI reads it)
-- Existing historical call_log rows in deal_notes are not deleted.
-- list_deal_notes_v1 unchanged -- existing notes remain readable.
-- No schema changes. No new tables. No new RPCs. No signature changes.

-- create_deal_note_v1: reject call_log note type
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

  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Not authorized', 'fields', '{}'::json)
    );
  END;

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

  -- call_log rejected: no governed UI writes call logs (10.14B4C)
  IF p_note_type IS NULL OR p_note_type NOT IN ('note') THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_note_type must be note', 'fields', '{}'::json)
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

REVOKE EXECUTE ON FUNCTION public.create_deal_note_v1(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_deal_note_v1(uuid, text, text) TO authenticated;

-- get_acq_deal_v1: remove last_contacted_at from output
-- All other logic identical to live body. Signature unchanged.
CREATE OR REPLACE FUNCTION public.get_acq_deal_v1(p_deal_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant  uuid;
  v_deal    record;
  v_props   record;
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

  SELECT * INTO v_deal
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  SELECT * INTO v_props
  FROM public.deal_properties
  WHERE deal_id = p_deal_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object(
      'id',                v_deal.id,
      'stage',             v_deal.stage,
      'address',           v_deal.address,
      'assignee_user_id',  v_deal.assignee_user_id,
      'seller_name',       v_deal.seller_name,
      'seller_phone',      v_deal.seller_phone,
      'seller_email',      v_deal.seller_email,
      'seller_pain',       v_deal.seller_pain,
      'seller_timeline',   v_deal.seller_timeline,
      'seller_notes',      v_deal.seller_notes,
      'dead_reason',       v_deal.dead_reason,
      'farm_area_id',      v_deal.farm_area_id,
      'created_at',        v_deal.created_at,
      'updated_at',        v_deal.updated_at,
      'health_color',      public.get_deal_health_color(v_deal.stage, v_deal.updated_at),
      'properties',        CASE WHEN v_props.id IS NULL THEN null ELSE json_build_object(
        'property_type',   v_props.property_type,
        'beds',            v_props.beds,
        'baths',           v_props.baths,
        'sqft',            v_props.sqft,
        'lot_size',        v_props.lot_size,
        'year_built',      v_props.year_built,
        'occupancy',       v_props.occupancy,
        'deficiency_tags', v_props.deficiency_tags,
        'condition_notes', v_props.condition_notes,
        'repair_estimate', v_props.repair_estimate,
        'garage_parking',  v_props.garage_parking,
        'basement_type',   v_props.basement_type,
        'foundation_type', v_props.foundation_type,
        'roof_age',        v_props.roof_age,
        'furnace_age',     v_props.furnace_age,
        'ac_age',          v_props.ac_age,
        'heating_type',    v_props.heating_type,
        'cooling_type',    v_props.cooling_type,
        'electrical',      v_props.electrical,
        'plumbing',        v_props.plumbing
      ) END,
      'pricing',           (
        SELECT json_build_object(
          'arv',            di.assumptions->>'arv',
          'ask_price',      di.assumptions->>'ask_price',
          'repair_estimate', di.assumptions->>'repair_estimate',
          'assignment_fee', di.assumptions->>'assignment_fee',
          'mao',            di.assumptions->>'mao',
          'multiplier',     di.assumptions->>'multiplier',
          'calc_version',   di.calc_version
        )
        FROM public.deal_inputs di
        WHERE di.deal_id = p_deal_id AND di.tenant_id = v_tenant
        ORDER BY di.created_at DESC LIMIT 1
      )
    ),
    'error', null
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.get_acq_deal_v1(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_acq_deal_v1(uuid) TO authenticated;