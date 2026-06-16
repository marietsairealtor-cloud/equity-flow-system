-- 10.14B8B -- Dispo Backend -- Expanded Share Packet Fields
-- Migration 3 of 3: Extend list_dispo_dashboard_deals_v1 and
-- lookup_share_token_public_v1 to return new B8B packet fields.
-- All token validation, hash logic, failure envelopes, tenant checks,
-- and logging preserved byte-for-byte from B7B/B8 approved bodies.
-- Grants unchanged.

-- ============================================================
-- lookup_share_token_public_v1 -- add 7 new fields to SELECT + result
-- ============================================================

CREATE OR REPLACE FUNCTION public.lookup_share_token_public_v1(p_token text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_hash       bytea;
  v_row        record;
  v_result     json;
  v_sub_status text;
  v_period_end timestamptz;
  v_media      json;
BEGIN
  IF p_token IS NULL OR length(p_token) < 68 OR left(p_token, 4) <> 'shr_'
     OR substring(p_token FROM 5) !~ '^[0-9a-f]{64}$'
  THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', null, 'success', false, 'failure_category', 'format_invalid')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found', 'fields', json_build_object()));
  END IF;

  v_hash := extensions.digest(p_token, 'sha256');

  SELECT st.deal_id, st.tenant_id, st.expires_at, st.revoked_at,
         d.dispo_asking_price, d.dispo_intersection, d.dispo_closing_date,
         d.dispo_description, d.dispo_comparables, d.dispo_media_url,
         d.dispo_market_value_estimate, d.dispo_below_market_override,
         COALESCE(
           d.dispo_below_market_override,
           CASE WHEN d.dispo_market_value_estimate IS NOT NULL AND d.dispo_asking_price IS NOT NULL
                THEN d.dispo_market_value_estimate - d.dispo_asking_price
                ELSE NULL END
         ) AS dispo_below_market_value,
         d.dispo_headline, d.dispo_tagline, d.dispo_offer_deadline,
         d.dispo_walkthrough, d.dispo_features,
         d.dispo_contact_name, d.dispo_contact_phone
  INTO v_row
  FROM public.share_tokens st
  JOIN public.deals d ON d.id = st.deal_id AND d.tenant_id = st.tenant_id
  WHERE st.token_hash = v_hash;

  IF NOT FOUND THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'not_found')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found', 'fields', json_build_object()));
  END IF;

  IF v_row.revoked_at IS NOT NULL THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'revoked')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found', 'fields', json_build_object()));
  END IF;

  IF v_row.expires_at <= now() THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'expired')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found', 'fields', json_build_object()));
  END IF;

  SELECT ts.status, ts.current_period_end INTO v_sub_status, v_period_end
  FROM public.tenant_subscriptions ts WHERE ts.tenant_id = v_row.tenant_id;
  IF NOT FOUND OR v_sub_status = 'canceled' OR v_period_end <= now() THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'workspace_expired')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found', 'fields', json_build_object()));
  END IF;

  -- Approved media -- first by sort_order then updated_at (hero = first item)
  SELECT COALESCE(
    json_agg(
      json_build_object(
        'media_id',     dm.id,
        'storage_path', dm.storage_path,
        'sort_order',   dm.sort_order,
        'updated_at',   dm.updated_at
      )
      ORDER BY dm.sort_order ASC NULLS LAST, dm.updated_at ASC
    ),
    '[]'::json
  )
  INTO v_media
  FROM public.deal_media dm
  WHERE dm.tenant_id = v_row.tenant_id
    AND dm.deal_id = v_row.deal_id
    AND dm.is_dispo_approved = true;

  v_result := json_build_object('ok', true, 'code', 'OK',
    'data', json_build_object(
      'expires_at',                  v_row.expires_at,
      'dispo_asking_price',          v_row.dispo_asking_price,
      'dispo_intersection',          v_row.dispo_intersection,
      'dispo_closing_date',          v_row.dispo_closing_date,
      'dispo_description',           v_row.dispo_description,
      'dispo_comparables',           v_row.dispo_comparables,
      'dispo_media_url',             v_row.dispo_media_url,
      'dispo_market_value_estimate', v_row.dispo_market_value_estimate,
      'dispo_below_market_override', v_row.dispo_below_market_override,
      'dispo_below_market_value',    v_row.dispo_below_market_value,
      'dispo_headline',              v_row.dispo_headline,
      'dispo_tagline',               v_row.dispo_tagline,
      'dispo_offer_deadline',        v_row.dispo_offer_deadline,
      'dispo_walkthrough',           v_row.dispo_walkthrough,
      'dispo_features',              v_row.dispo_features,
      'dispo_contact_name',          v_row.dispo_contact_name,
      'dispo_contact_phone',         v_row.dispo_contact_phone,
      'media',                       v_media
    ),
    'error', null);

  BEGIN
    PERFORM public.foundation_log_activity_v1('share_token_lookup',
      json_build_object('token_hash', encode(v_hash, 'hex'), 'success', true, 'failure_category', null)::jsonb, null);
  EXCEPTION WHEN OTHERS THEN NULL; END;

  RETURN v_result;
END;
$fn$;

-- ============================================================
-- list_dispo_dashboard_deals_v1 -- add 7 new B8B fields per deal item
-- Preserves approved B8A body byte-for-byte; appends new fields only.
-- ============================================================

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
              ),
              'dispo_headline',              d.dispo_headline,
              'dispo_tagline',               d.dispo_tagline,
              'dispo_offer_deadline',        d.dispo_offer_deadline,
              'dispo_walkthrough',           d.dispo_walkthrough,
              'dispo_features',              d.dispo_features,
              'dispo_contact_name',          d.dispo_contact_name,
              'dispo_contact_phone',         d.dispo_contact_phone
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
