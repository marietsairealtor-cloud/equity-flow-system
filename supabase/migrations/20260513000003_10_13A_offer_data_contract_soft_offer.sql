-- 10.13A: Offer Backend -- Data Contract + Soft Offer Copy
-- deal_soft_offers: persisted seller-facing soft-offer text/email tied to deal + authoritative assumptions snapshot.
-- get_offer_payload_v1: governed read from deals.assumptions_snapshot_id (pricing + seller identity fields).
-- refresh_deal_soft_offer_v1(p_deal_id, p_idempotency_key): persists soft-offer copy; atomic replay via rpc_idempotency_log.
-- Forward-only plain SQL. No DO blocks.

DROP FUNCTION IF EXISTS public.refresh_deal_soft_offer_v1(uuid);
DROP FUNCTION IF EXISTS public.refresh_deal_soft_offer_v1(uuid, text);
DROP FUNCTION IF EXISTS public.get_offer_payload_v1(uuid);

-- ============================================================
-- Table: deal_soft_offers
-- ============================================================
CREATE TABLE public.deal_soft_offers (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id               uuid        NOT NULL,
  deal_id                 uuid        NOT NULL REFERENCES public.deals(id) ON DELETE CASCADE,
  assumptions_snapshot_id uuid        NOT NULL REFERENCES public.deal_inputs(id),
  calc_version            integer     NOT NULL,
  copy_text               text        NOT NULL,
  copy_email              text        NOT NULL,
  expiration_clause       text        NOT NULL,
  offer_expires_at        timestamptz NOT NULL,
  created_at              timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_deal_soft_offers_deal_created
  ON public.deal_soft_offers(deal_id, created_at DESC);

COMMENT ON TABLE public.deal_soft_offers IS
  '10.13A: soft-offer copy rows tied to a deal and the frozen deal_inputs snapshot used for pricing (no orphan FK to deals).';

ALTER TABLE public.deal_soft_offers ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER deal_soft_offers_tenant_match
  BEFORE INSERT OR UPDATE ON public.deal_soft_offers
  FOR EACH ROW EXECUTE FUNCTION public.check_deal_tenant_match();

REVOKE ALL ON TABLE public.deal_soft_offers FROM anon, authenticated;

ALTER TABLE public.deal_soft_offers OWNER TO postgres;

-- ============================================================
-- RPC: get_offer_payload_v1 (read-only)
-- ============================================================
CREATE FUNCTION public.get_offer_payload_v1(p_deal_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant        uuid;
  v_deal_id       uuid;
  v_snap_id       uuid;
  v_address       text;
  v_seller_name   text;
  v_seller_phone  text;
  v_seller_email  text;
  v_di_id         uuid;
  v_calc_version  integer;
  v_asm           jsonb;
  v_mao           numeric;
  v_arv           numeric;
  v_rep           numeric;
  v_mult          numeric;
  v_fee           numeric;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'Not authorized', 'fields', '{}'::jsonb)
      );
  END;

  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_deal_id is required', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT
    d.id,
    d.assumptions_snapshot_id,
    d.address,
    d.seller_name,
    d.seller_phone,
    d.seller_email
  INTO
    v_deal_id,
    v_snap_id,
    v_address,
    v_seller_name,
    v_seller_phone,
    v_seller_email
  FROM public.deals d
  WHERE d.id = p_deal_id AND d.tenant_id = v_tenant AND d.deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Deal not found', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT
    di.id,
    di.calc_version,
    di.assumptions
  INTO
    v_di_id,
    v_calc_version,
    v_asm
  FROM public.deal_inputs di
  WHERE di.id = v_snap_id
    AND di.deal_id = p_deal_id
    AND di.tenant_id = v_tenant;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Assumptions snapshot not found', 'fields', '{}'::jsonb)
    );
  END IF;

  v_asm := COALESCE(v_asm, '{}'::jsonb);

  IF v_asm ? 'mao' AND NULLIF(trim(v_asm->>'mao'), '') IS NOT NULL THEN
    BEGIN
      v_mao := (trim(v_asm->>'mao'))::numeric;
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object(
          'message', 'Authoritative snapshot has invalid mao value',
          'fields', jsonb_build_object('mao', 'invalid')
        )
      );
    END;
  ELSE
    v_mao := NULL;
  END IF;

  BEGIN
    v_arv := CASE WHEN NULLIF(trim(v_asm->>'arv'), '') IS NULL THEN NULL ELSE (trim(v_asm->>'arv'))::numeric END;
    v_rep := CASE WHEN NULLIF(trim(v_asm->>'repair_estimate'), '') IS NULL THEN NULL ELSE (trim(v_asm->>'repair_estimate'))::numeric END;
    v_mult := CASE WHEN NULLIF(trim(v_asm->>'multiplier'), '') IS NULL THEN NULL ELSE (trim(v_asm->>'multiplier'))::numeric END;
    v_fee := CASE WHEN NULLIF(trim(v_asm->>'assignment_fee'), '') IS NULL THEN NULL ELSE (trim(v_asm->>'assignment_fee'))::numeric END;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'Pricing fields on authoritative snapshot are not numeric',
        'fields', '{}'::jsonb
      )
    );
  END;

  IF v_mao IS NULL THEN
    IF v_arv IS NOT NULL AND v_rep IS NOT NULL AND v_mult IS NOT NULL THEN
      v_mao := ROUND((v_arv * v_mult) - v_rep - COALESCE(v_fee, 0));
    ELSE
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object(
          'message',
          'Cannot derive MAO: snapshot needs mao or arv, multiplier, and repair_estimate',
          'fields', '{}'::jsonb
        )
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'deal_id', v_deal_id,
      'assumptions_snapshot_id', v_di_id,
      'calc_version', v_calc_version,
      'pricing', jsonb_build_object(
        'arv',             v_asm->>'arv',
        'repair_estimate', v_asm->>'repair_estimate',
        'multiplier',      v_asm->>'multiplier',
        'assignment_fee',  v_asm->>'assignment_fee',
        'mao',             trim(to_char(v_mao, 'FM999999990')),
        'calc_version',    v_calc_version
      ),
      'seller', jsonb_build_object(
        'address',      v_address,
        'seller_name',  v_seller_name,
        'seller_phone', v_seller_phone,
        'seller_email', v_seller_email
      ),
      'offer_clause_hours', 48
    ),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.get_offer_payload_v1(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_offer_payload_v1(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_offer_payload_v1(uuid) TO authenticated;

-- ============================================================
-- RPC: refresh_deal_soft_offer_v1 (persist copy rows + idempotency)
-- ============================================================
CREATE FUNCTION public.refresh_deal_soft_offer_v1(p_deal_id uuid, p_idempotency_key text)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant       uuid;
  v_user         uuid;
  v_claimed      boolean;
  v_stored       jsonb;
  v_payload      jsonb;
  v_data         jsonb;
  v_mao_disp     text;
  v_mult_disp    text;
  v_fee_disp     text;
  v_addr         text;
  v_name         text;
  v_clause       text;
  v_expires      timestamptz;
  v_copy_text    text;
  v_copy_mail    text;
  v_snap_id      uuid;
  v_calc         integer;
  v_new_offer_id uuid;
  v_result       jsonb;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'Not authorized', 'fields', '{}'::jsonb)
      );
  END;

  v_user := auth.uid();

  IF v_user IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant or user context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_idempotency_key IS NULL OR length(trim(p_idempotency_key)) = 0 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'p_idempotency_key is required.',
        'fields', jsonb_build_object('p_idempotency_key', 'required')
      )
    );
  END IF;

  SELECT result_json INTO v_stored
  FROM public.rpc_idempotency_log
  WHERE user_id = v_user
    AND idempotency_key = trim(p_idempotency_key)
    AND rpc_name = 'refresh_deal_soft_offer_v1';

  IF FOUND THEN
    RETURN v_stored;
  END IF;

  v_tenant := public.current_tenant_id();

  IF v_tenant IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only.', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_deal_id is required', 'fields', '{}'::jsonb)
    );
  END IF;

  v_payload := public.get_offer_payload_v1(p_deal_id);

  IF COALESCE((v_payload->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN v_payload;
  END IF;

  v_data := v_payload->'data';
  v_mao_disp := v_data->'pricing'->>'mao';
  v_mult_disp := COALESCE(v_data->'pricing'->>'multiplier', '');
  v_fee_disp := COALESCE(v_data->'pricing'->>'assignment_fee', '');
  IF v_fee_disp = '' OR v_fee_disp IS NULL THEN
    v_fee_disp := '0';
  END IF;

  v_addr := COALESCE(v_data->'seller'->>'address', '(address not set)');
  v_name := COALESCE(NULLIF(trim(v_data->'seller'->>'seller_name'), ''), 'Seller');

  v_snap_id := (v_data->>'assumptions_snapshot_id')::uuid;
  v_calc := (v_data->>'calc_version')::integer;

  v_new_offer_id := gen_random_uuid();
  v_expires := clock_timestamp() + interval '48 hours';
  v_clause := format(
    'This indicative soft offer expires at %s UTC (48 hours from generation).',
    to_char(v_expires AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS')
  );

  v_copy_text :=
    'Soft Offer' || chr(10) || chr(10) ||
    'Property: ' || v_addr || chr(10) ||
    'Maximum Allowable Offer (MAO): $' || v_mao_disp || chr(10) ||
    'Multiplier: ' || v_mult_disp || chr(10) ||
    'Assignment fee: $' || v_fee_disp || chr(10) || chr(10) ||
    v_clause || chr(10);

  v_copy_mail :=
    'Subject: Soft offer - ' || v_addr || chr(10) || chr(10) ||
    'Hello ' || v_name || ',' || chr(10) || chr(10) ||
    'Please find our indicative soft offer below.' || chr(10) || chr(10) ||
    'Property: ' || v_addr || chr(10) ||
    'Maximum Allowable Offer (MAO): $' || v_mao_disp || chr(10) ||
    'Multiplier: ' || v_mult_disp || chr(10) ||
    'Assignment fee: $' || v_fee_disp || chr(10) || chr(10) ||
    v_clause || chr(10) || chr(10) ||
    'Regards,' || chr(10);

  v_result := jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'deal_id', p_deal_id,
      'deal_soft_offer_id', v_new_offer_id,
      'assumptions_snapshot_id', v_snap_id,
      'offer_expires_at', to_char(v_expires AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    ),
    'error', null
  );

  INSERT INTO public.rpc_idempotency_log
    (user_id, idempotency_key, rpc_name, result_json)
  VALUES
    (v_user, trim(p_idempotency_key), 'refresh_deal_soft_offer_v1', v_result)
  ON CONFLICT (user_id, idempotency_key, rpc_name)
    DO UPDATE SET result_json = public.rpc_idempotency_log.result_json
  RETURNING (xmax = 0) INTO v_claimed;

  IF NOT v_claimed THEN
    SELECT result_json INTO v_result
    FROM public.rpc_idempotency_log
    WHERE user_id = v_user
      AND idempotency_key = trim(p_idempotency_key)
      AND rpc_name = 'refresh_deal_soft_offer_v1';
    RETURN v_result;
  END IF;

  DELETE FROM public.deal_soft_offers
  WHERE deal_id = p_deal_id AND tenant_id = v_tenant;

  INSERT INTO public.deal_soft_offers (
    id, tenant_id, deal_id, assumptions_snapshot_id, calc_version,
    copy_text, copy_email, expiration_clause, offer_expires_at
  ) VALUES (
    v_new_offer_id, v_tenant, p_deal_id, v_snap_id, v_calc,
    v_copy_text, v_copy_mail, v_clause, v_expires
  );

  RETURN v_result;
END;
$fn$;

ALTER FUNCTION public.refresh_deal_soft_offer_v1(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.refresh_deal_soft_offer_v1(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_deal_soft_offer_v1(uuid, text) TO authenticated;
