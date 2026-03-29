-- Migration: 10.8.8C -- Upsert Subscription RPC
-- Adds upsert_subscription_v1() for Stripe webhook billing writes.
-- SECURITY DEFINER; service_role only; not app-user callable.

DROP FUNCTION IF EXISTS public.upsert_subscription_v1(uuid, text, text, timestamptz);

CREATE FUNCTION public.upsert_subscription_v1(
  p_tenant_id              uuid,
  p_stripe_subscription_id text,
  p_status                 text,
  p_current_period_end     timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_allowed_statuses text[] := ARRAY['active','expiring','expired','canceled'];
BEGIN
  -- Validate tenant_id
  IF p_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'p_tenant_id is required.',
        'fields',  jsonb_build_object('p_tenant_id', 'required')
      )
    );
  END IF;

  -- Validate stripe_subscription_id
  IF p_stripe_subscription_id IS NULL OR length(trim(p_stripe_subscription_id)) = 0 THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'p_stripe_subscription_id is required.',
        'fields',  jsonb_build_object('p_stripe_subscription_id', 'required')
      )
    );
  END IF;

  -- Validate current_period_end
  IF p_current_period_end IS NULL THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'p_current_period_end is required.',
        'fields',  jsonb_build_object('p_current_period_end', 'required')
      )
    );
  END IF;

  -- Validate status
  IF p_status IS NULL OR NOT (p_status = ANY(v_allowed_statuses)) THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'p_status must be one of: active, expiring, expired, canceled.',
        'fields',  jsonb_build_object('p_status', 'invalid')
      )
    );
  END IF;

  -- Verify tenant exists
  IF NOT EXISTS (SELECT 1 FROM public.tenants WHERE id = p_tenant_id) THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'Tenant not found.',
        'fields',  jsonb_build_object('p_tenant_id', 'not_found')
      )
    );
  END IF;

  -- Upsert subscription
  INSERT INTO public.tenant_subscriptions (
    tenant_id,
    stripe_subscription_id,
    status,
    current_period_end,
    updated_at,
    row_version
  )
  VALUES (
    p_tenant_id,
    p_stripe_subscription_id,
    p_status,
    p_current_period_end,
    now(),
    1
  )
  ON CONFLICT (tenant_id) DO UPDATE
    SET stripe_subscription_id = EXCLUDED.stripe_subscription_id,
        status                 = EXCLUDED.status,
        current_period_end     = EXCLUDED.current_period_end,
        updated_at             = now(),
        row_version            = public.tenant_subscriptions.row_version + 1;

  RETURN jsonb_build_object(
    'ok',    true,
    'code',  'OK',
    'data',  jsonb_build_object(
      'tenant_id', p_tenant_id,
      'status',    p_status
    ),
    'error', null
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'ok',    false,
    'code',  'INTERNAL',
    'data',  '{}'::jsonb,
    'error', jsonb_build_object('message', SQLERRM, 'fields', '{}'::jsonb)
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.upsert_subscription_v1(uuid, text, text, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.upsert_subscription_v1(uuid, text, text, timestamptz) FROM authenticated;