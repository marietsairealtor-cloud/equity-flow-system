-- 10.12C6: Intake Backend — Draft Deal Read Path
-- RPC: get_draft_deal_v1(p_draft_id uuid) — tenant-scoped draft row for Lead Intake pre-fill

DROP FUNCTION IF EXISTS public.get_draft_deal_v1(uuid);

CREATE FUNCTION public.get_draft_deal_v1(
  p_draft_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
  d        RECORD;
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

  IF p_draft_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Draft not found', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT
    id,
    form_type,
    payload,
    address,
    asking_price,
    repair_estimate,
    promoted_deal_id,
    created_at
  INTO d
  FROM public.draft_deals
  WHERE id = p_draft_id
    AND tenant_id = v_tenant;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Draft not found', 'fields', '{}'::jsonb)
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'id', d.id,
      'form_type', d.form_type,
      'payload', d.payload,
      'address', d.address,
      'asking_price', d.asking_price,
      'repair_estimate', d.repair_estimate,
      'promoted_deal_id', d.promoted_deal_id,
      'created_at', d.created_at
    ),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.get_draft_deal_v1(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_draft_deal_v1(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_draft_deal_v1(uuid) TO authenticated;
