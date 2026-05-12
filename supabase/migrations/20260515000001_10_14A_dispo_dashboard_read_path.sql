-- 10.14A: Dispo Backend — Dashboard Data Contract + KPI Read Path
-- 1) handoff_to_tc_v1: require auth user + append deal_activity_log (enables KPI "Deals Moved to TC").
-- 2) get_dispo_kpis_v1(p_date_from, p_date_to): windowed KPIs + current Dispo avg assignment fee.
-- 3) list_dispo_dashboard_deals_v1(): deals in stage dispo only + share-link summary + activity teaser;
--    buyer_interest.signals is an empty array (schema_version 1) until buyer-signal persistence exists.

-- ============================================================
-- handoff_to_tc_v1 — activity log + user guard (align handoff_to_dispo_v1)
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
  v_user   uuid;
  v_stage  text;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN json_build_object(
        'ok', false,
        'code', 'NOT_AUTHORIZED',
        'data', json_build_object(),
        'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
      );
  END;

  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant or user context', 'fields', json_build_object())
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

  INSERT INTO public.deal_activity_log (
    tenant_id, deal_id, activity_type, content, created_by, created_at
  ) VALUES (
    v_tenant, p_deal_id, 'handoff', 'Deal handed off to TC', v_user, now()
  );

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'tc', 'assignee_user_id', p_assignee_user_id),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.handoff_to_tc_v1(uuid, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.handoff_to_tc_v1(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.handoff_to_tc_v1(uuid, uuid) TO authenticated;

-- ============================================================
-- get_dispo_kpis_v1
-- Windowed: deals_moved_to_tc, deposit_collected (deal_tc_checklist.deposit_received completed_at).
-- Snapshot: avg_assignment_fee across deals currently in stage dispo (latest assumptions snapshot).
-- ============================================================
DROP FUNCTION IF EXISTS public.get_dispo_kpis_v1(timestamptz, timestamptz);

CREATE FUNCTION public.get_dispo_kpis_v1(
  p_date_from timestamptz DEFAULT NULL,
  p_date_to   timestamptz DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant              uuid;
  v_from                timestamptz;
  v_to                  timestamptz;
  v_deals_moved_to_tc   bigint;
  v_deposit_collected   bigint;
  v_avg_assignment_fee  numeric;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN json_build_object(
        'ok', false,
        'code', 'NOT_AUTHORIZED',
        'data', json_build_object(),
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

  v_from := COALESCE(p_date_from, now() - interval '30 days');
  v_to := COALESCE(p_date_to, now());

  IF v_to < v_from THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object(
        'message', 'effective date window is invalid (end before start)',
        'fields', json_build_object()
      )
    );
  END IF;

  SELECT COUNT(*) INTO v_deals_moved_to_tc
  FROM public.deal_activity_log al
  WHERE al.tenant_id = v_tenant
    AND al.activity_type = 'handoff'
    AND al.content = 'Deal handed off to TC'
    AND al.created_at >= v_from
    AND al.created_at <= v_to;

  SELECT COUNT(*) INTO v_deposit_collected
  FROM public.deal_tc_checklist c
  WHERE c.tenant_id = v_tenant
    AND c.item_key = 'deposit_received'
    AND c.completed_at IS NOT NULL
    AND c.completed_at >= v_from
    AND c.completed_at <= v_to;

  SELECT COALESCE(AVG((di.assumptions->>'assignment_fee')::numeric), 0) INTO v_avg_assignment_fee
  FROM public.deals d
  JOIN public.deal_inputs di
    ON di.id = d.assumptions_snapshot_id
   AND di.tenant_id = d.tenant_id
  WHERE d.tenant_id = v_tenant
    AND d.deleted_at IS NULL
    AND d.stage = 'dispo'
    AND di.assumptions ? 'assignment_fee'
    AND NULLIF(trim(di.assumptions->>'assignment_fee'), '') IS NOT NULL;

  RETURN json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object(
      'deals_moved_to_tc',      v_deals_moved_to_tc,
      'deposit_collected',      v_deposit_collected,
      'avg_assignment_fee',     ROUND(v_avg_assignment_fee, 2),
      'date_from',              v_from,
      'date_to',                v_to
    ),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.get_dispo_kpis_v1(timestamptz, timestamptz) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_dispo_kpis_v1(timestamptz, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_dispo_kpis_v1(timestamptz, timestamptz) TO authenticated;

-- ============================================================
-- list_dispo_dashboard_deals_v1
-- ============================================================
CREATE FUNCTION public.list_dispo_dashboard_deals_v1()
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
  EXCEPTION
    WHEN OTHERS THEN
      RETURN json_build_object(
        'ok', false,
        'code', 'NOT_AUTHORIZED',
        'data', json_build_object(),
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

  RETURN json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object(
      'items', COALESCE(
        (
          SELECT json_agg(
            json_build_object(
              'id',                 d.id,
              'stage',              d.stage,
              'address',            d.address,
              'assignee_user_id',   d.assignee_user_id,
              'farm_area_id',       d.farm_area_id,
              'next_action',        d.next_action,
              'next_action_due',    d.next_action_due,
              'updated_at',         d.updated_at,
              'created_at',         d.created_at,
              'health_color',       public.get_deal_health_color(d.stage, d.updated_at),
              'arv', (
                SELECT di2.assumptions->>'arv'
                FROM public.deal_inputs di2
                WHERE di2.deal_id = d.id AND di2.tenant_id = v_tenant
                ORDER BY di2.created_at DESC
                LIMIT 1
              ),
              'ask', (
                SELECT di2.assumptions->>'ask_price'
                FROM public.deal_inputs di2
                WHERE di2.deal_id = d.id AND di2.tenant_id = v_tenant
                ORDER BY di2.created_at DESC
                LIMIT 1
              ),
              'assignment_fee', (
                SELECT di2.assumptions->>'assignment_fee'
                FROM public.deal_inputs di2
                WHERE di2.deal_id = d.id AND di2.tenant_id = v_tenant
                ORDER BY di2.created_at DESC
                LIMIT 1
              ),
              'share_link', json_build_object(
                'status', CASE
                  WHEN COALESCE(tok.active_count, 0) > 0 THEN 'active'
                  WHEN COALESCE(tok.token_total, 0) = 0 THEN 'none'
                  WHEN COALESCE(tok.revoked_total, 0) = tok.token_total THEN 'revoked'
                  WHEN COALESCE(tok.expired_total, 0) = tok.token_total THEN 'expired'
                  ELSE 'inactive'
                END,
                'active_count', COALESCE(tok.active_count, 0),
                'next_expires_at', tok.next_expires_at
              ),
              'buyer_interest', json_build_object(
                'schema_version', 1,
                'signals',        json_build_array()
              ),
              'activity', json_build_object(
                'entry_count',        COALESCE(actc.entry_count, 0),
                'last_activity_type', act1.activity_type,
                'last_activity_at',   act1.created_at
              )
            )
            ORDER BY d.updated_at DESC
          )
          FROM public.deals d
          LEFT JOIN LATERAL (
            SELECT
              COUNT(*)::int AS token_total,
              COUNT(*) FILTER (
                WHERE st.revoked_at IS NULL AND st.expires_at > now()
              )::int AS active_count,
              MIN(st.expires_at) FILTER (
                WHERE st.revoked_at IS NULL AND st.expires_at > now()
              ) AS next_expires_at,
              COUNT(*) FILTER (WHERE st.revoked_at IS NOT NULL)::int AS revoked_total,
              COUNT(*) FILTER (
                WHERE st.revoked_at IS NULL AND st.expires_at <= now()
              )::int AS expired_total
            FROM public.share_tokens st
            WHERE st.tenant_id = v_tenant
              AND st.deal_id = d.id
          ) tok ON true
          LEFT JOIN LATERAL (
            SELECT COUNT(*)::bigint AS entry_count
            FROM public.deal_activity_log x
            WHERE x.deal_id = d.id
              AND x.tenant_id = v_tenant
          ) actc ON true
          LEFT JOIN LATERAL (
            SELECT y.activity_type, y.created_at
            FROM public.deal_activity_log y
            WHERE y.deal_id = d.id
              AND y.tenant_id = v_tenant
            ORDER BY y.created_at DESC, y.id DESC
            LIMIT 1
          ) act1 ON true
          WHERE d.tenant_id = v_tenant
            AND d.deleted_at IS NULL
            AND d.stage = 'dispo'
        ),
        '[]'::json
      )
    ),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.list_dispo_dashboard_deals_v1() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.list_dispo_dashboard_deals_v1() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_dispo_dashboard_deals_v1() TO authenticated;
