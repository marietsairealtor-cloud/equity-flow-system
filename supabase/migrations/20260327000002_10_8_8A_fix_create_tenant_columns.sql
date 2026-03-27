-- Migration: 10.8.8A corrective -- Fix create_tenant_v1 column references
-- Removes row_version from tenants and tenant_memberships INSERTs.
-- Cloud schema has no row_version on these tables.

DROP FUNCTION IF EXISTS public.create_tenant_v1(text);

CREATE FUNCTION public.create_tenant_v1(p_idempotency_key text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user_id        uuid;
  v_new_tenant_id  uuid;
  v_result         jsonb;
  v_claimed        boolean := false;
BEGIN
  IF p_idempotency_key IS NULL OR length(trim(p_idempotency_key)) = 0 THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_idempotency_key is required.', 'fields', jsonb_build_object('p_idempotency_key', 'required'))
    );
  END IF;

  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', 'Authentication required.', 'fields', '{}'::jsonb)
    );
  END IF;

  PERFORM public.current_tenant_id();

  v_new_tenant_id := gen_random_uuid();

  v_result := jsonb_build_object(
    'ok',    true,
    'code',  'OK',
    'data',  jsonb_build_object('tenant_id', v_new_tenant_id),
    'error', null
  );

  INSERT INTO public.rpc_idempotency_log
    (user_id, idempotency_key, rpc_name, result_json)
  VALUES
    (v_user_id, p_idempotency_key, 'create_tenant_v1', v_result)
  ON CONFLICT (user_id, idempotency_key, rpc_name)
    DO UPDATE SET result_json = public.rpc_idempotency_log.result_json
  RETURNING (xmax = 0) INTO v_claimed;

  IF NOT v_claimed THEN
    SELECT result_json INTO v_result
    FROM public.rpc_idempotency_log
    WHERE user_id = v_user_id
      AND idempotency_key = p_idempotency_key
      AND rpc_name = 'create_tenant_v1';
    RETURN v_result;
  END IF;

  INSERT INTO public.tenants (id)
  VALUES (v_new_tenant_id);

  INSERT INTO public.tenant_memberships (tenant_id, user_id, role)
  VALUES (v_new_tenant_id, v_user_id, 'owner');

  INSERT INTO public.user_profiles (id, current_tenant_id)
  VALUES (v_user_id, v_new_tenant_id)
  ON CONFLICT (id) DO UPDATE
    SET current_tenant_id = v_new_tenant_id
    WHERE public.user_profiles.current_tenant_id IS NULL;

  RETURN v_result;

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'ok',    false,
    'code',  'INTERNAL',
    'data',  '{}'::jsonb,
    'error', jsonb_build_object('message', SQLERRM, 'fields', '{}'::jsonb)
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.create_tenant_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_tenant_v1(text) TO authenticated;