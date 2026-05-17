-- 10.14B3: Property Field Expansion -- Electrical + Plumbing Backend
-- Adds electrical and plumbing columns to deal_properties.
-- Extends update_deal_properties_v1 allowed keys to include electrical, plumbing.
-- Extends get_acq_deal_v1 properties output to include electrical, plumbing.
-- Adds envelope-safe require_min_role_v1('member') guard to both RPCs.
-- No new tables. No new RPCs. No signature changes.

ALTER TABLE public.deal_properties
  ADD COLUMN IF NOT EXISTS electrical text NULL,
  ADD COLUMN IF NOT EXISTS plumbing   text NULL;

COMMENT ON COLUMN public.deal_properties.electrical IS
  '10.14B3: operator-captured electrical details e.g. 100A panel, knob-and-tube. Not from public seller form.';
COMMENT ON COLUMN public.deal_properties.plumbing IS
  '10.14B3: operator-captured plumbing details e.g. copper, galvanized. Not from public seller form.';

CREATE OR REPLACE FUNCTION public.update_deal_properties_v1(
  p_deal_id uuid,
  p_fields  jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant            uuid;
  v_user              uuid;
  v_rows_updated      int;
  v_allowed_keys      text[] := ARRAY[
    'property_type','beds','baths','sqft','lot_size','year_built',
    'occupancy','deficiency_tags','condition_notes',
    'garage_parking','basement_type','foundation_type',
    'roof_age','furnace_age','ac_age','heating_type','cooling_type',
    'electrical','plumbing'
  ];
  v_unknown_keys      text[];
  v_year_built        integer;
  v_roof_age          integer;
  v_furnace_age       integer;
  v_ac_age            integer;
  v_deficiency_tags   text[];
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

  -- Reject unknown keys (repair_estimate now rejected -- use update_deal_pricing_v1)
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

  -- Validate deficiency_tags shape
  IF p_fields ? 'deficiency_tags' THEN
    IF jsonb_typeof(p_fields->'deficiency_tags') = 'null' THEN
      v_deficiency_tags := NULL;
    ELSIF jsonb_typeof(p_fields->'deficiency_tags') = 'array' THEN
      IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(p_fields->'deficiency_tags') elem
        WHERE jsonb_typeof(elem) <> 'string'
      ) THEN
        RETURN json_build_object(
          'ok',    false,
          'code',  'VALIDATION_ERROR',
          'data',  '{}'::json,
          'error', json_build_object('message', 'deficiency_tags must be an array of strings', 'fields', '{}'::json)
        );
      END IF;
      v_deficiency_tags := ARRAY(SELECT jsonb_array_elements_text(p_fields->'deficiency_tags'));
    ELSE
      RETURN json_build_object(
        'ok',    false,
        'code',  'VALIDATION_ERROR',
        'data',  '{}'::json,
        'error', json_build_object('message', 'deficiency_tags must be an array of strings or null', 'fields', '{}'::json)
      );
    END IF;
  END IF;

  -- Validate typed fields safely
  IF p_fields ? 'year_built' AND p_fields->>'year_built' IS NOT NULL THEN
    BEGIN
      v_year_built := (p_fields->>'year_built')::integer;
    EXCEPTION WHEN OTHERS THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'year_built must be a valid integer', 'fields', '{}'::json));
    END;
  END IF;

  IF p_fields ? 'roof_age' AND p_fields->>'roof_age' IS NOT NULL THEN
    BEGIN
      v_roof_age := (p_fields->>'roof_age')::integer;
    EXCEPTION WHEN OTHERS THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'roof_age must be a valid integer', 'fields', '{}'::json));
    END;
  END IF;

  IF p_fields ? 'furnace_age' AND p_fields->>'furnace_age' IS NOT NULL THEN
    BEGIN
      v_furnace_age := (p_fields->>'furnace_age')::integer;
    EXCEPTION WHEN OTHERS THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'furnace_age must be a valid integer', 'fields', '{}'::json));
    END;
  END IF;

  IF p_fields ? 'ac_age' AND p_fields->>'ac_age' IS NOT NULL THEN
    BEGIN
      v_ac_age := (p_fields->>'ac_age')::integer;
    EXCEPTION WHEN OTHERS THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'ac_age must be a valid integer', 'fields', '{}'::json));
    END;
  END IF;

  -- Verify deal belongs to current tenant
  IF NOT EXISTS (
    SELECT 1 FROM public.deals
    WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
    );
  END IF;

  -- Verify deal_properties row exists
  IF NOT EXISTS (
    SELECT 1 FROM public.deal_properties
    WHERE deal_id = p_deal_id AND tenant_id = v_tenant
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Deal properties not found', 'fields', '{}'::json)
    );
  END IF;

  UPDATE public.deal_properties
  SET
    property_type   = CASE WHEN p_fields ? 'property_type'   THEN (p_fields->>'property_type')   ELSE property_type   END,
    beds            = CASE WHEN p_fields ? 'beds'             THEN (p_fields->>'beds')             ELSE beds            END,
    baths           = CASE WHEN p_fields ? 'baths'            THEN (p_fields->>'baths')            ELSE baths           END,
    sqft            = CASE WHEN p_fields ? 'sqft'             THEN (p_fields->>'sqft')             ELSE sqft            END,
    lot_size        = CASE WHEN p_fields ? 'lot_size'         THEN (p_fields->>'lot_size')         ELSE lot_size        END,
    year_built      = CASE WHEN p_fields ? 'year_built'       THEN v_year_built                    ELSE year_built      END,
    occupancy       = CASE WHEN p_fields ? 'occupancy'        THEN (p_fields->>'occupancy')        ELSE occupancy       END,
    deficiency_tags = CASE WHEN p_fields ? 'deficiency_tags'  THEN v_deficiency_tags               ELSE deficiency_tags END,
    condition_notes = CASE WHEN p_fields ? 'condition_notes'  THEN (p_fields->>'condition_notes')  ELSE condition_notes END,
    garage_parking  = CASE WHEN p_fields ? 'garage_parking'   THEN (p_fields->>'garage_parking')   ELSE garage_parking  END,
    basement_type   = CASE WHEN p_fields ? 'basement_type'    THEN (p_fields->>'basement_type')    ELSE basement_type   END,
    foundation_type = CASE WHEN p_fields ? 'foundation_type'  THEN (p_fields->>'foundation_type')  ELSE foundation_type END,
    roof_age        = CASE WHEN p_fields ? 'roof_age'         THEN v_roof_age                      ELSE roof_age        END,
    furnace_age     = CASE WHEN p_fields ? 'furnace_age'      THEN v_furnace_age                   ELSE furnace_age     END,
    ac_age          = CASE WHEN p_fields ? 'ac_age'           THEN v_ac_age                        ELSE ac_age          END,
    heating_type    = CASE WHEN p_fields ? 'heating_type'     THEN (p_fields->>'heating_type')     ELSE heating_type    END,
    cooling_type    = CASE WHEN p_fields ? 'cooling_type'     THEN (p_fields->>'cooling_type')     ELSE cooling_type    END,
    electrical      = CASE WHEN p_fields ? 'electrical'       THEN (p_fields->>'electrical')       ELSE electrical      END,
    plumbing        = CASE WHEN p_fields ? 'plumbing'         THEN (p_fields->>'plumbing')         ELSE plumbing        END,
    updated_at      = now(),
    row_version     = row_version + 1
  WHERE deal_id   = p_deal_id
    AND tenant_id = v_tenant
    AND (
      (p_fields ? 'property_type'   AND (p_fields->>'property_type')   IS DISTINCT FROM property_type)   OR
      (p_fields ? 'beds'            AND (p_fields->>'beds')            IS DISTINCT FROM beds)             OR
      (p_fields ? 'baths'           AND (p_fields->>'baths')           IS DISTINCT FROM baths)            OR
      (p_fields ? 'sqft'            AND (p_fields->>'sqft')            IS DISTINCT FROM sqft)             OR
      (p_fields ? 'lot_size'        AND (p_fields->>'lot_size')        IS DISTINCT FROM lot_size)         OR
      (p_fields ? 'year_built'      AND v_year_built                   IS DISTINCT FROM year_built)       OR
      (p_fields ? 'occupancy'       AND (p_fields->>'occupancy')       IS DISTINCT FROM occupancy)        OR
      (p_fields ? 'deficiency_tags' AND v_deficiency_tags              IS DISTINCT FROM deficiency_tags)  OR
      (p_fields ? 'condition_notes' AND (p_fields->>'condition_notes') IS DISTINCT FROM condition_notes)  OR
      (p_fields ? 'garage_parking'  AND (p_fields->>'garage_parking')  IS DISTINCT FROM garage_parking)   OR
      (p_fields ? 'basement_type'   AND (p_fields->>'basement_type')   IS DISTINCT FROM basement_type)    OR
      (p_fields ? 'foundation_type' AND (p_fields->>'foundation_type') IS DISTINCT FROM foundation_type)  OR
      (p_fields ? 'roof_age'        AND v_roof_age                     IS DISTINCT FROM roof_age)         OR
      (p_fields ? 'furnace_age'     AND v_furnace_age                  IS DISTINCT FROM furnace_age)      OR
      (p_fields ? 'ac_age'          AND v_ac_age                       IS DISTINCT FROM ac_age)           OR
      (p_fields ? 'heating_type'    AND (p_fields->>'heating_type')    IS DISTINCT FROM heating_type)     OR
      (p_fields ? 'cooling_type'    AND (p_fields->>'cooling_type')    IS DISTINCT FROM cooling_type)     OR
      (p_fields ? 'electrical'      AND (p_fields->>'electrical')      IS DISTINCT FROM electrical)       OR
      (p_fields ? 'plumbing'        AND (p_fields->>'plumbing')        IS DISTINCT FROM plumbing)
    );

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No actual changes provided', 'fields', '{}'::json)
    );
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id),
    'error', null
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.update_deal_properties_v1(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_deal_properties_v1(uuid, jsonb) TO authenticated;

-- get_acq_deal_v1: add envelope-safe member guard + electrical/plumbing to properties output
-- All other logic identical to live body. Signature unchanged.
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