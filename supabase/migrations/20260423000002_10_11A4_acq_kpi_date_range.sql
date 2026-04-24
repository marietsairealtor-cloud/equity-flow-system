-- 10.11A4: Acquisition Backend -- KPI Date Range Filter
-- Extends get_acq_kpis_v1 with optional p_date_from and p_date_to parameters
-- Drops old zero-arg surface first to avoid overload conflict.
-- avg_assignment_fee uses latest deal_inputs row per deal (ORDER BY created_at DESC LIMIT 1)
-- No schema changes. No new tables. No new columns.

-- Drop old zero-arg surface
DROP FUNCTION IF EXISTS public.get_acq_kpis_v1();

CREATE OR REPLACE FUNCTION public.get_acq_kpis_v1(
  p_date_from timestamptz DEFAULT NULL,
  p_date_to   timestamptz DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
STABLE SECURITY DEFINER
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

  IF p_date_from IS NOT NULL AND p_date_to IS NOT NULL AND p_date_to < p_date_from THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'p_date_to must not be before p_date_from', 'fields', json_build_object())
    );
  END IF;

  -- contracts signed: deals in terminal stages within date range
  SELECT COUNT(*) INTO v_contracts_signed
  FROM public.deals
  WHERE tenant_id  = v_tenant
    AND stage IN ('under_contract', 'dispo', 'tc', 'closed')
    AND deleted_at IS NULL
    AND (p_date_from IS NULL OR created_at >= p_date_from)
    AND (p_date_to   IS NULL OR created_at <= p_date_to);

  -- leads worked: all deals within date range
  SELECT COUNT(*) INTO v_leads_worked
  FROM public.deals
  WHERE tenant_id  = v_tenant
    AND deleted_at IS NULL
    AND (p_date_from IS NULL OR created_at >= p_date_from)
    AND (p_date_to   IS NULL OR created_at <= p_date_to);

  -- avg assignment fee: one latest deal_inputs row per deal
  SELECT COALESCE(AVG(latest.assignment_fee), 0) INTO v_avg_assignment_fee
  FROM (
    SELECT DISTINCT ON (d.id)
      (di.assumptions->>'assignment_fee')::numeric AS assignment_fee
    FROM public.deals d
    JOIN public.deal_inputs di
      ON di.deal_id = d.id AND di.tenant_id = v_tenant
    WHERE d.tenant_id  = v_tenant
      AND d.stage IN ('under_contract', 'dispo', 'tc', 'closed')
      AND d.deleted_at IS NULL
      AND (p_date_from IS NULL OR d.created_at >= p_date_from)
      AND (p_date_to   IS NULL OR d.created_at <= p_date_to)
      AND di.assumptions->>'assignment_fee' IS NOT NULL
    ORDER BY d.id, di.created_at DESC, di.id DESC
  ) latest;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object(
      'contracts_signed',     v_contracts_signed,
      'lead_to_contract_pct', CASE WHEN v_leads_worked = 0 THEN 0
                                   ELSE ROUND((v_contracts_signed::numeric / v_leads_worked) * 100, 1)
                              END,
      'avg_assignment_fee',   ROUND(v_avg_assignment_fee, 2)
    ),
    'error', null
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.get_acq_kpis_v1(timestamptz, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_acq_kpis_v1(timestamptz, timestamptz) TO authenticated;