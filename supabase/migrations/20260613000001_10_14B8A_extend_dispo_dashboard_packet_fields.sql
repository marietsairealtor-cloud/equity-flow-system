-- 10.14B8A -- Dispo Dashboard Packet + Media Approval Read Extension
-- Migration 1 of 2: Extend list_dispo_dashboard_deals_v1 to return
-- the 8 dispo_* packet fields and derived dispo_below_market_value.
-- No schema changes. No privilege changes. No public surface changes.

CREATE OR REPLACE FUNCTION public.list_dispo_dashboard_deals_v1()
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

  RETURN json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object(
      'items', COALESCE(
        (
          SELECT json_agg(
            json_build_object(
              'id',                          d.id,
              'stage',                       d.stage,
              'address',                     d.address,
              'assignee_user_id',            d.assignee_user_id,
              'farm_area_id',                d.farm_area_id,
              'next_action',                 d.next_action,
              'next_action_due',             d.next_action_due,
              'updated_at',                  d.updated_at,
              'created_at',                  d.created_at,
              'health_color',                public.get_deal_health_color(d.stage, d.updated_at),
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
                'active_count',    COALESCE(tok.active_count, 0),
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
              ),
              'dispo_asking_price',          d.dispo_asking_price,
              'dispo_intersection',          d.dispo_intersection,
              'dispo_closing_date',          d.dispo_closing_date,
              'dispo_description',           d.dispo_description,
              'dispo_comparables',           d.dispo_comparables,
              'dispo_media_url',             d.dispo_media_url,
              'dispo_market_value_estimate', d.dispo_market_value_estimate,
              'dispo_below_market_override', d.dispo_below_market_override,
              'dispo_below_market_value',    COALESCE(
                d.dispo_below_market_override,
                CASE
                  WHEN d.dispo_market_value_estimate IS NOT NULL
                    AND d.dispo_asking_price IS NOT NULL
                  THEN d.dispo_market_value_estimate - d.dispo_asking_price
                  ELSE NULL
                END
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
