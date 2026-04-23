-- 10.11A3: Acquisition Backend -- Deal Detail Read Path Corrections
-- Extends get_acq_deal_v1 to return mao, multiplier, and last_contacted_at
-- No schema changes. No new tables. No new columns.
-- deal_properties has UNIQUE(deal_id) -- one row per deal guaranteed.

CREATE OR REPLACE FUNCTION public.get_acq_deal_v1(p_deal_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE SECURITY DEFINER
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
      'next_action',       v_deal.next_action,
      'next_action_due',   v_deal.next_action_due,
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
        'cooling_type',    v_props.cooling_type
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