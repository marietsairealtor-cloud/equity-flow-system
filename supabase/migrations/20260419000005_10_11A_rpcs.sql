-- 10.11A RPCs: Acquisition backend
-- get_acq_kpis_v1, list_acq_deals_v1, get_acq_deal_v1,
-- update_seller_info_v1, update_property_info_v1,
-- advance_deal_stage_v1, mark_deal_dead_v1,
-- handoff_to_dispo_v1, handoff_to_tc_v1,
-- return_to_acq_v1, return_to_dispo_v1,
-- list_deal_media_v1, register_deal_media_v1, delete_deal_media_v1

-- ============================================================
-- get_acq_kpis_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_acq_kpis_v1()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant              uuid;
  v_contracts_signed    integer;
  v_leads_worked        integer;
  v_avg_assignment_fee  numeric;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  SELECT COUNT(*) INTO v_contracts_signed
  FROM public.deals
  WHERE tenant_id = v_tenant
    AND stage IN ('under_contract', 'dispo', 'tc', 'closed')
    AND deleted_at IS NULL;

  SELECT COUNT(*) INTO v_leads_worked
  FROM public.deals
  WHERE tenant_id = v_tenant
    AND deleted_at IS NULL;

  SELECT COALESCE(AVG(
    (di.assumptions->>'assignment_fee')::numeric
  ), 0) INTO v_avg_assignment_fee
  FROM public.deals d
  JOIN public.deal_inputs di ON di.deal_id = d.id AND di.tenant_id = v_tenant
  WHERE d.tenant_id = v_tenant
    AND d.stage IN ('under_contract', 'dispo', 'tc', 'closed')
    AND d.deleted_at IS NULL
    AND di.assumptions->>'assignment_fee' IS NOT NULL;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object(
      'contracts_signed',       v_contracts_signed,
      'lead_to_contract_pct',   CASE WHEN v_leads_worked = 0 THEN 0
                                     ELSE ROUND((v_contracts_signed::numeric / v_leads_worked) * 100, 1)
                                END,
      'avg_assignment_fee',     ROUND(v_avg_assignment_fee, 2)
    ),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_acq_kpis_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_acq_kpis_v1() TO authenticated;

-- ============================================================
-- list_acq_deals_v1
-- p_filter: 'all' | 'new' | 'analyzing' | 'offer_sent' | 'under_contract' | 'follow_ups'
-- p_farm_area_id: optional uuid filter
-- Excludes dispo/tc/closed/dead from Acq dataset.
-- follow_ups = deals with at least one incomplete reminder past due.
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_acq_deals_v1(
  p_filter       text    DEFAULT 'all',
  p_farm_area_id uuid    DEFAULT NULL
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
              'next_action',     d.next_action,
              'next_action_due', d.next_action_due,
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

REVOKE ALL ON FUNCTION public.list_acq_deals_v1(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_acq_deals_v1(text, uuid) TO authenticated;

-- ============================================================
-- get_acq_deal_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_acq_deal_v1(
  p_deal_id uuid
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
  v_deal   record;
  v_props  record;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
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
      'next_action',       v_deal.next_action,
      'next_action_due',   v_deal.next_action_due,
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
        'cooling_type',    v_props.cooling_type
      ) END,
      'pricing',           (
        SELECT json_build_object(
          'arv',            di.assumptions->>'arv',
          'ask_price',      di.assumptions->>'ask_price',
          'repair_estimate', di.assumptions->>'repair_estimate',
          'assignment_fee', di.assumptions->>'assignment_fee',
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

REVOKE ALL ON FUNCTION public.get_acq_deal_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_acq_deal_v1(uuid) TO authenticated;

-- ============================================================
-- update_seller_info_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_seller_info_v1(
  p_deal_id        uuid,
  p_seller_name    text    DEFAULT NULL,
  p_seller_phone   text    DEFAULT NULL,
  p_seller_email   text    DEFAULT NULL,
  p_seller_pain    text    DEFAULT NULL,
  p_seller_timeline text   DEFAULT NULL,
  p_seller_notes   text    DEFAULT NULL,
  p_next_action    text    DEFAULT NULL,
  p_next_action_due timestamptz DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
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

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
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

  UPDATE public.deals SET
    seller_name     = COALESCE(p_seller_name,     seller_name),
    seller_phone    = COALESCE(p_seller_phone,    seller_phone),
    seller_email    = COALESCE(p_seller_email,    seller_email),
    seller_pain     = COALESCE(p_seller_pain,     seller_pain),
    seller_timeline = COALESCE(p_seller_timeline, seller_timeline),
    seller_notes    = COALESCE(p_seller_notes,    seller_notes),
    next_action     = COALESCE(p_next_action,     next_action),
    next_action_due = COALESCE(p_next_action_due, next_action_due),
    updated_at      = now(),
    row_version     = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.update_seller_info_v1(uuid, text, text, text, text, text, text, text, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_seller_info_v1(uuid, text, text, text, text, text, text, text, timestamptz) TO authenticated;

-- ============================================================
-- update_property_info_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_property_info_v1(
  p_deal_id         uuid,
  p_property_type   text      DEFAULT NULL,
  p_beds            integer   DEFAULT NULL,
  p_baths           numeric   DEFAULT NULL,
  p_sqft            integer   DEFAULT NULL,
  p_lot_size        text      DEFAULT NULL,
  p_year_built      integer   DEFAULT NULL,
  p_occupancy       text      DEFAULT NULL,
  p_deficiency_tags text[]    DEFAULT NULL,
  p_condition_notes text      DEFAULT NULL,
  p_repair_estimate numeric   DEFAULT NULL,
  p_garage_parking  text      DEFAULT NULL,
  p_basement_type   text      DEFAULT NULL,
  p_foundation_type text      DEFAULT NULL,
  p_roof_age        integer   DEFAULT NULL,
  p_furnace_age     integer   DEFAULT NULL,
  p_ac_age          integer   DEFAULT NULL,
  p_heating_type    text      DEFAULT NULL,
  p_cooling_type    text      DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
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

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
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

  INSERT INTO public.deal_properties (
    tenant_id, deal_id,
    property_type, beds, baths, sqft, lot_size, year_built, occupancy,
    deficiency_tags, condition_notes, repair_estimate,
    garage_parking, basement_type, foundation_type,
    roof_age, furnace_age, ac_age, heating_type, cooling_type
  )
  VALUES (
    v_tenant, p_deal_id,
    p_property_type, p_beds, p_baths, p_sqft, p_lot_size, p_year_built, p_occupancy,
    p_deficiency_tags, p_condition_notes, p_repair_estimate,
    p_garage_parking, p_basement_type, p_foundation_type,
    p_roof_age, p_furnace_age, p_ac_age, p_heating_type, p_cooling_type
  )
  ON CONFLICT (deal_id) DO UPDATE SET
    property_type   = COALESCE(EXCLUDED.property_type,   deal_properties.property_type),
    beds            = COALESCE(EXCLUDED.beds,            deal_properties.beds),
    baths           = COALESCE(EXCLUDED.baths,           deal_properties.baths),
    sqft            = COALESCE(EXCLUDED.sqft,            deal_properties.sqft),
    lot_size        = COALESCE(EXCLUDED.lot_size,        deal_properties.lot_size),
    year_built      = COALESCE(EXCLUDED.year_built,      deal_properties.year_built),
    occupancy       = COALESCE(EXCLUDED.occupancy,       deal_properties.occupancy),
    deficiency_tags = COALESCE(EXCLUDED.deficiency_tags, deal_properties.deficiency_tags),
    condition_notes = COALESCE(EXCLUDED.condition_notes, deal_properties.condition_notes),
    repair_estimate = COALESCE(EXCLUDED.repair_estimate, deal_properties.repair_estimate),
    garage_parking  = COALESCE(EXCLUDED.garage_parking,  deal_properties.garage_parking),
    basement_type   = COALESCE(EXCLUDED.basement_type,   deal_properties.basement_type),
    foundation_type = COALESCE(EXCLUDED.foundation_type, deal_properties.foundation_type),
    roof_age        = COALESCE(EXCLUDED.roof_age,        deal_properties.roof_age),
    furnace_age     = COALESCE(EXCLUDED.furnace_age,     deal_properties.furnace_age),
    ac_age          = COALESCE(EXCLUDED.ac_age,          deal_properties.ac_age),
    heating_type    = COALESCE(EXCLUDED.heating_type,    deal_properties.heating_type),
    cooling_type    = COALESCE(EXCLUDED.cooling_type,    deal_properties.cooling_type),
    updated_at      = now(),
    row_version     = deal_properties.row_version + 1;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.update_property_info_v1(uuid, text, integer, numeric, integer, text, integer, text, text[], text, numeric, text, text, text, integer, integer, integer, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_property_info_v1(uuid, text, integer, numeric, integer, text, integer, text, text[], text, numeric, text, text, text, integer, integer, integer, text, text) TO authenticated;

-- ============================================================
-- advance_deal_stage_v1
-- Valid actions: start_analysis | send_offer | mark_contract_signed
-- UC -> Dispo handled by handoff_to_dispo_v1 only
-- ============================================================
CREATE OR REPLACE FUNCTION public.advance_deal_stage_v1(
  p_deal_id uuid,
  p_action  text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant    uuid;
  v_stage     text;
  v_new_stage text;
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

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  -- Enforce valid transitions
  IF p_action = 'start_analysis' AND v_stage = 'new' THEN
    v_new_stage := 'analyzing';
  ELSIF p_action = 'send_offer' AND v_stage = 'analyzing' THEN
    v_new_stage := 'offer_sent';
  ELSIF p_action = 'mark_contract_signed' AND v_stage = 'offer_sent' THEN
    v_new_stage := 'under_contract';
  ELSE
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid stage transition for current deal state', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    stage       = v_new_stage,
    updated_at  = now(),
    row_version = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', v_new_stage),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.advance_deal_stage_v1(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.advance_deal_stage_v1(uuid, text) TO authenticated;

-- ============================================================
-- mark_deal_dead_v1
-- Available for all active non-terminal stages
-- Unavailable for closed / dead
-- dead_reason required
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_deal_dead_v1(
  p_deal_id    uuid,
  p_dead_reason text
)
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

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'dead'),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.mark_deal_dead_v1(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_deal_dead_v1(uuid, text) TO authenticated;

-- ============================================================
-- handoff_to_dispo_v1
-- UC only → dispo, saves assignee, creates notification
-- ============================================================
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

  -- Validate assignee is a member of this tenant
  IF p_assignee_user_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.tenant_memberships
    WHERE tenant_id = v_tenant AND user_id = p_assignee_user_id
  ) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Assignee is not a member of this workspace', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    stage              = 'dispo',
    assignee_user_id   = p_assignee_user_id,
    updated_at         = now(),
    row_version        = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'dispo', 'assignee_user_id', p_assignee_user_id),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.handoff_to_dispo_v1(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.handoff_to_dispo_v1(uuid, uuid) TO authenticated;

-- ============================================================
-- handoff_to_tc_v1
-- dispo only → tc
-- ============================================================
CREATE OR REPLACE FUNCTION public.handoff_to_tc_v1(
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

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  IF v_stage <> 'dispo' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Handoff to TC is only allowed from Dispo stage', 'fields', json_build_object())
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

  UPDATE public.deals SET
    stage            = 'tc',
    assignee_user_id = p_assignee_user_id,
    updated_at       = now(),
    row_version      = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'tc', 'assignee_user_id', p_assignee_user_id),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.handoff_to_tc_v1(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.handoff_to_tc_v1(uuid, uuid) TO authenticated;

-- ============================================================
-- return_to_acq_v1
-- dispo → under_contract
-- ============================================================
CREATE OR REPLACE FUNCTION public.return_to_acq_v1(
  p_deal_id uuid
)
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

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  IF v_stage <> 'dispo' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Return to Acq is only allowed from Dispo stage', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    stage       = 'under_contract',
    updated_at  = now(),
    row_version = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'under_contract'),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.return_to_acq_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.return_to_acq_v1(uuid) TO authenticated;

-- ============================================================
-- return_to_dispo_v1
-- tc → dispo
-- ============================================================
CREATE OR REPLACE FUNCTION public.return_to_dispo_v1(
  p_deal_id uuid
)
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

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  IF v_stage <> 'tc' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Return to Dispo is only allowed from TC stage', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    stage       = 'dispo',
    updated_at  = now(),
    row_version = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'dispo'),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.return_to_dispo_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.return_to_dispo_v1(uuid) TO authenticated;

-- ============================================================
-- list_deal_media_v1
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_deal_media_v1(
  p_deal_id uuid
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
              'id',           m.id,
              'storage_path', m.storage_path,
              'media_type',   m.media_type,
              'sort_order',   m.sort_order,
              'uploaded_at',  m.uploaded_at,
              'uploaded_by',  m.uploaded_by
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

REVOKE ALL ON FUNCTION public.list_deal_media_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_deal_media_v1(uuid) TO authenticated;

-- ============================================================
-- register_deal_media_v1
-- Called after client uploads file to Storage
-- ============================================================
CREATE OR REPLACE FUNCTION public.register_deal_media_v1(
  p_deal_id      uuid,
  p_storage_path text,
  p_sort_order   integer DEFAULT 0
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant   uuid;
  v_media_id uuid;
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

  IF p_storage_path IS NULL OR trim(p_storage_path) = '' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Storage path is required', 'fields', json_build_object('storage_path', 'required'))
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

  BEGIN
    INSERT INTO public.deal_media (
      tenant_id, deal_id, storage_path, media_type, sort_order, uploaded_by
    )
    VALUES (
      v_tenant, p_deal_id, p_storage_path, 'photo', p_sort_order, auth.uid()
    )
    RETURNING id INTO v_media_id;
  EXCEPTION WHEN unique_violation THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'A file with this storage path already exists', 'fields', json_build_object())
    );
  END;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('media_id', v_media_id, 'storage_path', p_storage_path),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.register_deal_media_v1(uuid, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_deal_media_v1(uuid, text, integer) TO authenticated;

-- ============================================================
-- delete_deal_media_v1
-- Deletes metadata row and returns storage_path for server-side deletion
-- Actual Storage object deletion triggered via Edge Function
-- ============================================================
CREATE OR REPLACE FUNCTION public.delete_deal_media_v1(
  p_media_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant       uuid;
  v_storage_path text;
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

  SELECT storage_path INTO v_storage_path
  FROM public.deal_media
  WHERE id = p_media_id AND tenant_id = v_tenant;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Media not found', 'fields', json_build_object())
    );
  END IF;

  DELETE FROM public.deal_media
  WHERE id = p_media_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('media_id', p_media_id, 'storage_path', v_storage_path),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.delete_deal_media_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_deal_media_v1(uuid) TO authenticated;
