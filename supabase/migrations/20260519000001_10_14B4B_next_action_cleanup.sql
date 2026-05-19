-- 10.14B4B: ACQ Backend Cleanup -- Remove Orphaned next_action Fields
-- Removes next_action and next_action_due from:
--   update_deal_property_v1 allowed keys
--   get_acq_deal_v1 output
--   list_acq_deals_v1 output
-- Adds envelope-safe require_min_role_v1('member') guard to update_deal_property_v1 and list_acq_deals_v1.
-- last_contacted_at cleanup is deferred to 10.14B4C.
-- No schema changes. No new tables. No new RPCs. No signature changes.
-- Columns next_action and next_action_due remain on public.deals (not dropped -- deprecated).
-- Reminder system (list_reminders_v1) remains authoritative follow-up path.

-- update_deal_property_v1: remove next_action/next_action_due, add member guard
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
  v_allowed_keys  text[] := ARRAY['address'];
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

  IF p_fields IS NULL OR jsonb_typeof(p_fields) <> 'object' OR p_fields = '{}'::jsonb THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_fields must be a non-empty JSON object', 'fields', '{}'::json)
    );
  END IF;

  -- Reject unknown keys (next_action and next_action_due removed -- use reminder system)
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

  UPDATE public.deals
  SET
    address     = CASE WHEN p_fields ? 'address' THEN (p_fields->>'address') ELSE address END,
    updated_at  = now(),
    row_version = row_version + 1
  WHERE id        = p_deal_id
    AND tenant_id = v_tenant
    AND deleted_at IS NULL
    AND (
      (p_fields ? 'address' AND (p_fields->>'address') IS DISTINCT FROM address)
    );

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
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

REVOKE EXECUTE ON FUNCTION public.update_deal_property_v1(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_deal_property_v1(uuid, jsonb) TO authenticated;

-- get_acq_deal_v1: remove next_action, next_action_due from output
-- last_contacted_at retained -- cleanup deferred to 10.14B4C
-- member guard already present -- preserved exactly
CREATE OR REPLACE FUNCTION public.get_acq_deal_v1(p_deal_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant          uuid;
  v_deal            record;
  v_props           record;
  v_last_contacted  timestamptz;
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

  -- Derive last_contacted_at from most recent call_log note
  -- Retained in B4B -- removal deferred to 10.14B4C
  SELECT dn.created_at INTO v_last_contacted
  FROM public.deal_notes dn
  WHERE dn.deal_id   = p_deal_id
    AND dn.tenant_id = v_tenant
    AND dn.note_type = 'call_log'
  ORDER BY dn.created_at DESC
  LIMIT 1;

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
      'last_contacted_at', v_last_contacted,
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

-- list_acq_deals_v1: remove next_action/next_action_due, add member guard
CREATE OR REPLACE FUNCTION public.list_acq_deals_v1(
  p_filter       text DEFAULT 'all',
  p_farm_area_id uuid DEFAULT NULL
)
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

  IF p_filter NOT IN ('all', 'new', 'analyzing', 'offer_sent', 'under_contract', 'follow_ups') THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid filter value', 'fields', json_build_object())
    );
  END IF;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object(
      'items', COALESCE(
        (
          SELECT json_agg(
            json_build_object(
              'id',              d.id,
              'stage',           d.stage,
              'address',         d.address,
              'assignee_user_id', d.assignee_user_id,
              'farm_area_id',    d.farm_area_id,
              'updated_at',      d.updated_at,
              'created_at',      d.created_at,
              'health_color',    public.get_deal_health_color(d.stage, d.updated_at),
              'arv',             (
                SELECT di.assumptions->>'arv'
                FROM public.deal_inputs di
                WHERE di.deal_id = d.id AND di.tenant_id = v_tenant
                ORDER BY di.created_at DESC LIMIT 1
              ),
              'ask',             (
                SELECT di.assumptions->>'ask_price'
                FROM public.deal_inputs di
                WHERE di.deal_id = d.id AND di.tenant_id = v_tenant
                ORDER BY di.created_at DESC LIMIT 1
              )
            )
            ORDER BY d.updated_at DESC
          )
          FROM public.deals d
          WHERE d.tenant_id = v_tenant
            AND d.deleted_at IS NULL
            AND d.stage NOT IN ('dispo', 'tc', 'closed', 'dead')
            AND (
              p_filter = 'all'
              OR (p_filter = 'follow_ups' AND EXISTS (
                SELECT 1 FROM public.deal_reminders r
                WHERE r.deal_id = d.id
                  AND r.tenant_id = v_tenant
                  AND r.completed_at IS NULL
                  AND r.reminder_date <= now()
              ))
              OR (p_filter NOT IN ('all', 'follow_ups') AND d.stage = p_filter)
            )
            AND (p_farm_area_id IS NULL OR d.farm_area_id = p_farm_area_id)
        ),
        '[]'::json
      )
    ),
    'error', null
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.list_acq_deals_v1(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_acq_deals_v1(text, uuid) TO authenticated;