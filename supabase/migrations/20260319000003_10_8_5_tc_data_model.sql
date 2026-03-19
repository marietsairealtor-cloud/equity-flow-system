-- 10.8.5: TC Checklist Data Model
-- Creates deal_tc and deal_tc_checklist tables.
-- Hardens update_deal_v1 to reject writes to terminal-stage deals.

-- deal_tc: TC coordination data, one row per deal
CREATE TABLE public.deal_tc (
  id                     UUID        NOT NULL DEFAULT gen_random_uuid(),
  deal_id                UUID        NOT NULL UNIQUE,
  tenant_id              UUID        NOT NULL,
  row_version            BIGINT      NOT NULL DEFAULT 1,
  aps_signed_date        TIMESTAMPTZ,
  conditional_deadline   TIMESTAMPTZ,
  closing_date           TIMESTAMPTZ,
  assignment_fee         NUMERIC,
  sell_price             NUMERIC,
  actual_assignment_fee  NUMERIC,
  buyer_info             JSONB,
  notes                  TEXT,
  CONSTRAINT deal_tc_pkey PRIMARY KEY (id),
  CONSTRAINT deal_tc_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deals(id) ON DELETE CASCADE,
  CONSTRAINT deal_tc_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE
);

ALTER TABLE public.deal_tc ENABLE ROW LEVEL SECURITY;

CREATE POLICY "deal_tc_select_own" ON public.deal_tc
  FOR SELECT TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE POLICY "deal_tc_insert_own" ON public.deal_tc
  FOR INSERT TO authenticated
  WITH CHECK (tenant_id = public.current_tenant_id());

CREATE POLICY "deal_tc_update_own" ON public.deal_tc
  FOR UPDATE TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE POLICY "deal_tc_delete_own" ON public.deal_tc
  FOR DELETE TO authenticated
  USING (tenant_id = public.current_tenant_id());

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.deal_tc TO authenticated;
-- Revoked immediately per CONTRACTS.md s12 -- superseded by 20260319000006
REVOKE ALL ON public.deal_tc FROM anon, authenticated;

-- deal_tc_checklist: checklist items per deal
CREATE TABLE public.deal_tc_checklist (
  id           UUID        NOT NULL DEFAULT gen_random_uuid(),
  deal_id      UUID        NOT NULL,
  tenant_id    UUID        NOT NULL,
  row_version  BIGINT      NOT NULL DEFAULT 1,
  item_key     TEXT        NOT NULL,
  completed_at TIMESTAMPTZ,
  CONSTRAINT deal_tc_checklist_pkey PRIMARY KEY (id),
  CONSTRAINT deal_tc_checklist_deal_item_key UNIQUE (deal_id, item_key),
  CONSTRAINT deal_tc_checklist_item_key_check CHECK (item_key IN (
    'aps_signed',
    'deposit_received',
    'sold_firm',
    'docs_to_lawyer',
    'closing_confirmed',
    'fee_received'
  )),
  CONSTRAINT deal_tc_checklist_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deals(id) ON DELETE CASCADE,
  CONSTRAINT deal_tc_checklist_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE
);

ALTER TABLE public.deal_tc_checklist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "deal_tc_checklist_select_own" ON public.deal_tc_checklist
  FOR SELECT TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE POLICY "deal_tc_checklist_insert_own" ON public.deal_tc_checklist
  FOR INSERT TO authenticated
  WITH CHECK (tenant_id = public.current_tenant_id());

CREATE POLICY "deal_tc_checklist_update_own" ON public.deal_tc_checklist
  FOR UPDATE TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE POLICY "deal_tc_checklist_delete_own" ON public.deal_tc_checklist
  FOR DELETE TO authenticated
  USING (tenant_id = public.current_tenant_id());

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.deal_tc_checklist TO authenticated;
-- Revoked immediately per CONTRACTS.md s12 -- superseded by 20260319000006
REVOKE ALL ON public.deal_tc_checklist FROM anon, authenticated;

-- Harden update_deal_v1: reject writes to terminal-stage deals (Immutable Close)
-- DROP + CREATE per CONTRACTS s2 (behavioral change)
DROP FUNCTION IF EXISTS public.update_deal_v1(uuid, bigint, integer);

CREATE FUNCTION public.update_deal_v1(
  p_id                   UUID,
  p_expected_row_version BIGINT,
  p_calc_version         INTEGER DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant      UUID;
  v_stage       TEXT;
  v_rows_updated INT;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  -- Immutable close: reject writes to terminal-stage deals
  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_id AND tenant_id = v_tenant;

  IF v_stage IN ('Closed / Dead') THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'DEAL_IMMUTABLE',
      'data',  null,
      'error', json_build_object('message', 'Deal is in a terminal stage and cannot be modified', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals
  SET
    row_version  = row_version + 1,
    calc_version = COALESCE(p_calc_version, calc_version)
  WHERE id         = p_id
    AND tenant_id  = v_tenant
    AND row_version = p_expected_row_version;

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'CONFLICT',
      'data',  null,
      'error', json_build_object('message', 'Row version mismatch or deal not found for this tenant', 'fields', json_build_object())
    );
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('id', p_id),
    'error', null
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.update_deal_v1(UUID, BIGINT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_deal_v1(UUID, BIGINT, INTEGER) TO authenticated;