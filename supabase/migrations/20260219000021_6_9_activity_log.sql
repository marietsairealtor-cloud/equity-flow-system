-- 6.9 Foundation Surface Ready — Activity log table + write RPC
-- Satisfies DoD bullet 4: "Activity log write path exists"

-- 1) Activity log table
CREATE TABLE public.activity_log (
    id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id  uuid        NOT NULL REFERENCES public.tenants(id),
    actor_id   uuid,
    action     text        NOT NULL,
    meta       jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;

-- 2) RLS policies (tenant isolation via current_tenant_id())
CREATE POLICY activity_log_select_own
  ON public.activity_log
  FOR SELECT TO authenticated
  USING (tenant_id = public.current_tenant_id());

CREATE POLICY activity_log_insert_own
  ON public.activity_log
  FOR INSERT TO authenticated
  WITH CHECK (tenant_id = public.current_tenant_id());

-- 3) Privilege firewall (CONTRACTS.md S12)
REVOKE ALL ON public.activity_log FROM anon;
REVOKE ALL ON public.activity_log FROM authenticated;

-- 4) Write RPC (SECURITY DEFINER, tenant-enforced)
CREATE FUNCTION public.foundation_log_activity_v1(
    p_tenant_id uuid,
    p_action    text,
    p_meta      jsonb DEFAULT '{}'::jsonb,
    p_actor_id  uuid  DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_id uuid;
BEGIN
  IF p_tenant_id IS NULL OR p_action IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  null,
      'error', json_build_object('message', 'tenant_id and action are required', 'fields', json_build_object())
    );
  END IF;

  IF public.current_tenant_id() IS DISTINCT FROM p_tenant_id THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'Tenant context mismatch', 'fields', json_build_object())
    );
  END IF;

  v_id := gen_random_uuid();

  INSERT INTO public.activity_log (id, tenant_id, actor_id, action, meta)
  VALUES (v_id, p_tenant_id, p_actor_id, p_action, p_meta);

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('id', v_id),
    'error', null
  );
END;
$fn$;

-- 5) Grant EXECUTE on RPC only
GRANT EXECUTE ON FUNCTION public.foundation_log_activity_v1(uuid, text, jsonb, uuid) TO authenticated;
