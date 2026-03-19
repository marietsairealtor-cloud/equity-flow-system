-- 10.8.4: Deal health computation
-- Adds internal helper get_deal_health_color (not executable by authenticated).
-- Replaces list_deals_v1 with DROP/CREATE (return shape change per CONTRACTS s2).
-- Tenancy via public.current_tenant_id(). No direct tenant_memberships query.

-- Internal helper: callable only from SECURITY DEFINER RPCs, not by authenticated.
CREATE OR REPLACE FUNCTION public.get_deal_health_color(
  p_stage      TEXT,
  p_updated_at TIMESTAMPTZ
)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT CASE
    WHEN p_updated_at IS NULL THEN 'yellow'
    WHEN p_stage = 'New'        AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 3        THEN 'red'
    WHEN p_stage = 'New'        AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 3 * 0.7  THEN 'yellow'
    WHEN p_stage = 'Analyzing'  AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7        THEN 'red'
    WHEN p_stage = 'Analyzing'  AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7 * 0.7  THEN 'yellow'
    WHEN p_stage = 'Offer Sent' AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 5        THEN 'red'
    WHEN p_stage = 'Offer Sent' AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 5 * 0.7  THEN 'yellow'
    WHEN p_stage = 'UC'         AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 14       THEN 'red'
    WHEN p_stage = 'UC'         AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 14 * 0.7 THEN 'yellow'
    WHEN p_stage = 'Dispo'      AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7        THEN 'red'
    WHEN p_stage = 'Dispo'      AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7 * 0.7  THEN 'yellow'
    ELSE 'green'
  END
$fn$;

-- Firewall: helper is not executable by any role directly.
REVOKE ALL ON FUNCTION public.get_deal_health_color(TEXT, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;

-- DROP existing list_deals_v1 before CREATE (return shape change per CONTRACTS s2).
DROP FUNCTION IF EXISTS public.list_deals_v1(integer);

CREATE FUNCTION public.list_deals_v1(
  p_limit  INTEGER DEFAULT 25,
  p_cursor TEXT    DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant UUID;
BEGIN
  v_tenant := public.current_tenant_id();

  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  NULL,
      'error', json_build_object('message', 'Not authorized', 'fields', '{}')
    );
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'items', COALESCE(
        (
          SELECT json_agg(
            json_build_object(
              'id',           d.id,
              'tenant_id',    d.tenant_id,
              'row_version',  d.row_version,
              'calc_version', d.calc_version,
              'stage',        d.stage,
              'health_color', public.get_deal_health_color(d.stage, d.updated_at)
            )
            ORDER BY d.id
          )
          FROM public.deals d
          WHERE d.tenant_id = v_tenant
          AND d.deleted_at IS NULL
          LIMIT LEAST(COALESCE(p_limit, 25), 100)
        ),
        '[]'::json
      ),
      'next_cursor', NULL
    ),
    'error', NULL
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.list_deals_v1(INTEGER, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_deals_v1(INTEGER, TEXT) TO authenticated;