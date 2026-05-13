-- 10.14B1: Dispo Backend -- Buyer Active Status Mutation
-- update_buyer_active_status_v1(p_buyer_id uuid, p_is_active boolean)
-- Updates intake_buyers.is_active for a tenant-scoped buyer.
-- No signature change to list_buyers_v1. No new tables.

CREATE FUNCTION public.update_buyer_active_status_v1(
  p_buyer_id  uuid,
  p_is_active boolean
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant uuid;
  v_user   uuid;
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
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant or user context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only.', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_buyer_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_buyer_id is required', 'fields', jsonb_build_object('p_buyer_id', 'required'))
    );
  END IF;

  IF p_is_active IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_is_active is required', 'fields', jsonb_build_object('p_is_active', 'required'))
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.intake_buyers
    WHERE id = p_buyer_id AND tenant_id = v_tenant
  ) THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Buyer not found', 'fields', '{}'::jsonb)
    );
  END IF;

  UPDATE public.intake_buyers
  SET is_active  = p_is_active,
      updated_at = now()
  WHERE id = p_buyer_id AND tenant_id = v_tenant;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'buyer_id',  p_buyer_id,
      'is_active', p_is_active
    ),
    'error', null
  );
END;
$fn$;

ALTER FUNCTION public.update_buyer_active_status_v1(uuid, boolean) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.update_buyer_active_status_v1(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_buyer_active_status_v1(uuid, boolean) TO authenticated;