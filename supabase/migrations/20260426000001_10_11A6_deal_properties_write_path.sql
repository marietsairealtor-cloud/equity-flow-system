-- 10.11A6: Acquisition Backend -- Deal Properties Write Path
-- Adds update_deal_properties_v1(p_deal_id uuid, p_fields jsonb)
-- Writes to deal_properties table only. Does not touch deal_inputs or assumptions.
-- beds, baths, sqft, garage_parking are text fields (v1 shorthand support).
-- repair_estimate, year_built, roof_age, furnace_age, ac_age are typed -- validated safely.
-- Same jsonb patch semantics as update_deal_seller_v1.
-- Missing deal_properties row = NOT_FOUND (no auto-create).

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
    'occupancy','deficiency_tags','condition_notes','repair_estimate',
    'garage_parking','basement_type','foundation_type',
    'roof_age','furnace_age','ac_age','heating_type','cooling_type'
  ];
  v_unknown_keys      text[];
  v_year_built        integer;
  v_repair_estimate   numeric;
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

  -- Validate deficiency_tags shape
  IF p_fields ? 'deficiency_tags' THEN
    IF jsonb_typeof(p_fields->'deficiency_tags') = 'null' THEN
      -- explicit null = clear field
      v_deficiency_tags := NULL;
    ELSIF jsonb_typeof(p_fields->'deficiency_tags') = 'array' THEN
      -- validate every element is a JSON string
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

  -- Validate typed numeric/integer fields safely
  IF p_fields ? 'year_built' AND p_fields->>'year_built' IS NOT NULL THEN
    BEGIN
      v_year_built := (p_fields->>'year_built')::integer;
    EXCEPTION WHEN others THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'year_built must be a valid integer', 'fields', '{}'::json));
    END;
  END IF;

  IF p_fields ? 'repair_estimate' AND p_fields->>'repair_estimate' IS NOT NULL THEN
    BEGIN
      v_repair_estimate := (p_fields->>'repair_estimate')::numeric;
    EXCEPTION WHEN others THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'repair_estimate must be a valid number', 'fields', '{}'::json));
    END;
  END IF;

  IF p_fields ? 'roof_age' AND p_fields->>'roof_age' IS NOT NULL THEN
    BEGIN
      v_roof_age := (p_fields->>'roof_age')::integer;
    EXCEPTION WHEN others THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'roof_age must be a valid integer', 'fields', '{}'::json));
    END;
  END IF;

  IF p_fields ? 'furnace_age' AND p_fields->>'furnace_age' IS NOT NULL THEN
    BEGIN
      v_furnace_age := (p_fields->>'furnace_age')::integer;
    EXCEPTION WHEN others THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'furnace_age must be a valid integer', 'fields', '{}'::json));
    END;
  END IF;

  IF p_fields ? 'ac_age' AND p_fields->>'ac_age' IS NOT NULL THEN
    BEGIN
      v_ac_age := (p_fields->>'ac_age')::integer;
    EXCEPTION WHEN others THEN
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

  -- UPDATE only if at least one provided field IS DISTINCT FROM current value
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
    repair_estimate = CASE WHEN p_fields ? 'repair_estimate'  THEN v_repair_estimate               ELSE repair_estimate END,
    garage_parking  = CASE WHEN p_fields ? 'garage_parking'   THEN (p_fields->>'garage_parking')   ELSE garage_parking  END,
    basement_type   = CASE WHEN p_fields ? 'basement_type'    THEN (p_fields->>'basement_type')    ELSE basement_type   END,
    foundation_type = CASE WHEN p_fields ? 'foundation_type'  THEN (p_fields->>'foundation_type')  ELSE foundation_type END,
    roof_age        = CASE WHEN p_fields ? 'roof_age'         THEN v_roof_age                      ELSE roof_age        END,
    furnace_age     = CASE WHEN p_fields ? 'furnace_age'      THEN v_furnace_age                   ELSE furnace_age     END,
    ac_age          = CASE WHEN p_fields ? 'ac_age'           THEN v_ac_age                        ELSE ac_age          END,
    heating_type    = CASE WHEN p_fields ? 'heating_type'     THEN (p_fields->>'heating_type')     ELSE heating_type    END,
    cooling_type    = CASE WHEN p_fields ? 'cooling_type'     THEN (p_fields->>'cooling_type')     ELSE cooling_type    END,
    updated_at      = now(),
    row_version     = row_version + 1
  WHERE deal_id   = p_deal_id
    AND tenant_id = v_tenant
    AND (
      (p_fields ? 'property_type'   AND (p_fields->>'property_type')  IS DISTINCT FROM property_type)   OR
      (p_fields ? 'beds'            AND (p_fields->>'beds')           IS DISTINCT FROM beds)             OR
      (p_fields ? 'baths'           AND (p_fields->>'baths')          IS DISTINCT FROM baths)            OR
      (p_fields ? 'sqft'            AND (p_fields->>'sqft')           IS DISTINCT FROM sqft)             OR
      (p_fields ? 'lot_size'        AND (p_fields->>'lot_size')       IS DISTINCT FROM lot_size)         OR
      (p_fields ? 'year_built'      AND v_year_built                  IS DISTINCT FROM year_built)       OR
      (p_fields ? 'occupancy'       AND (p_fields->>'occupancy')      IS DISTINCT FROM occupancy)        OR
      (p_fields ? 'deficiency_tags' AND v_deficiency_tags             IS DISTINCT FROM deficiency_tags)  OR
      (p_fields ? 'condition_notes' AND (p_fields->>'condition_notes') IS DISTINCT FROM condition_notes) OR
      (p_fields ? 'repair_estimate' AND v_repair_estimate             IS DISTINCT FROM repair_estimate)  OR
      (p_fields ? 'garage_parking'  AND (p_fields->>'garage_parking') IS DISTINCT FROM garage_parking)   OR
      (p_fields ? 'basement_type'   AND (p_fields->>'basement_type')  IS DISTINCT FROM basement_type)    OR
      (p_fields ? 'foundation_type' AND (p_fields->>'foundation_type') IS DISTINCT FROM foundation_type) OR
      (p_fields ? 'roof_age'        AND v_roof_age                    IS DISTINCT FROM roof_age)         OR
      (p_fields ? 'furnace_age'     AND v_furnace_age                 IS DISTINCT FROM furnace_age)      OR
      (p_fields ? 'ac_age'          AND v_ac_age                      IS DISTINCT FROM ac_age)           OR
      (p_fields ? 'heating_type'    AND (p_fields->>'heating_type')   IS DISTINCT FROM heating_type)     OR
      (p_fields ? 'cooling_type'    AND (p_fields->>'cooling_type')   IS DISTINCT FROM cooling_type)
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

REVOKE EXECUTE ON FUNCTION public.update_deal_properties_v1(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_deal_properties_v1(uuid, jsonb) TO authenticated;