-- 10.8.12: 1-Month Free Trial (One-Time, User-Scoped)
-- Three-column trial state on user_profiles:
--   has_used_trial:   boolean -- permanently true after webhook confirms subscription
--   trial_claimed_at: timestamptz -- set atomically at checkout creation; expires after 2 hours
--   trial_started_at: timestamptz -- set by webhook after confirmed subscription
-- Two-phase enforcement:
--   claim_trial_v1()   -- atomic reservation at checkout creation
--   confirm_trial_v1() -- webhook finalization after Stripe confirms subscription
-- Stale claim recovery: trial_claimed_at older than 2 hours is treated as expired reservation.

-- Step 1: Add trial columns to user_profiles
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS has_used_trial   boolean     NOT NULL DEFAULT false;

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS trial_claimed_at timestamptz DEFAULT NULL;

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS trial_started_at timestamptz DEFAULT NULL;

-- Step 2: claim_trial_v1()
-- Atomically reserves trial at checkout creation.
-- Eligible when: has_used_trial = false AND (trial_claimed_at IS NULL OR claimed > 2 hours ago).
-- Sets trial_claimed_at = now() atomically via UPDATE ... RETURNING.
-- Returns trial_eligible = true only if reservation succeeded.
-- Returns trial_eligible = false if already used or active reservation exists.
-- No parameters -- derives user from auth.uid() only.

CREATE FUNCTION public.claim_trial_v1()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user            uuid;
  v_trial_days      integer     := 30;
  v_claim_expiry    interval    := interval '2 hours';
  v_reserved_id     uuid;
BEGIN
  v_user := auth.uid();

  IF v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'Authentication required',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Verify user profile exists
  IF NOT EXISTS (
    SELECT 1 FROM public.user_profiles WHERE id = v_user
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'User profile not found',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Atomic reservation: claim only when not used and no active reservation
  UPDATE public.user_profiles
  SET trial_claimed_at = now()
  WHERE id             = v_user
    AND has_used_trial = false
    AND (
      trial_claimed_at IS NULL
      OR trial_claimed_at < now() - v_claim_expiry
    )
  RETURNING id INTO v_reserved_id;

  IF v_reserved_id IS NOT NULL THEN
    -- Reservation succeeded
    RETURN json_build_object(
      'ok',   true,
      'code', 'OK',
      'data', json_build_object(
        'trial_eligible',    true,
        'trial_period_days', v_trial_days
      ),
      'error', null
    );
  END IF;

  -- Reservation failed: already used or active reservation exists
  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'trial_eligible',    false,
      'trial_period_days', null
    ),
    'error', null
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'ok',   false,
    'code', 'INTERNAL',
    'data', json_build_object(),
    'error', json_build_object(
      'message', 'Internal trial claim error',
      'fields',  json_build_object()
    )
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.claim_trial_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_trial_v1() TO authenticated;

-- Step 3: confirm_trial_v1(p_user_id uuid, p_tenant_id uuid)
-- Service_role only. Called by stripe-webhook after confirmed subscription
-- creation with status = trialing.
-- Verifies user is owner of target tenant.
-- Finalizes trial: sets has_used_trial = true, trial_started_at = now().
-- Idempotent: already-confirmed returns OK without re-writing.
-- Missing profile returns NOT_FOUND.

CREATE FUNCTION public.confirm_trial_v1(
  p_user_id   uuid,
  p_tenant_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_has_used boolean;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'p_user_id is required',
        'fields',  json_build_object()
      )
    );
  END IF;

  IF p_tenant_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'p_tenant_id is required',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Verify user profile exists
  SELECT up.has_used_trial INTO v_has_used
  FROM public.user_profiles up
  WHERE up.id = p_user_id;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'User profile not found',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Idempotent: already confirmed
  IF v_has_used THEN
    RETURN json_build_object(
      'ok',   true,
      'code', 'OK',
      'data', json_build_object(
        'user_id',           p_user_id,
        'confirmed',         true,
        'already_confirmed', true
      ),
      'error', null
    );
  END IF;

  -- Verify user is owner of target tenant
  IF NOT EXISTS (
    SELECT 1 FROM public.tenant_memberships tm
    WHERE tm.tenant_id = p_tenant_id
      AND tm.user_id   = p_user_id
      AND tm.role      = 'owner'
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'User is not owner of target tenant',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Validate active reservation exists and has not expired
  IF NOT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id               = p_user_id
      AND up.trial_claimed_at IS NOT NULL
      AND up.trial_claimed_at >= now() - interval '2 hours'
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'CONFLICT',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'No valid trial reservation found. Reservation may have expired.',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Finalize trial usage
  UPDATE public.user_profiles
  SET has_used_trial   = true,
      trial_started_at = now()
  WHERE id = p_user_id;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'user_id',           p_user_id,
      'confirmed',         true,
      'already_confirmed', false
    ),
    'error', null
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'ok',   false,
    'code', 'INTERNAL',
    'data', json_build_object(),
    'error', json_build_object(
      'message', 'Internal trial confirmation error',
      'fields',  json_build_object()
    )
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.confirm_trial_v1(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.confirm_trial_v1(uuid, uuid) FROM authenticated;

-- Step 4: Update upsert_subscription_v1() to accept trialing as valid status.
-- Adds trialing to allowed statuses. Re-grants to service_role.
-- No other behavior change. Interface unchanged.

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
  v_allowed_statuses text[] := ARRAY['active','expiring','expired','canceled','trialing'];
BEGIN
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

  IF p_status IS NULL OR NOT (p_status = ANY(v_allowed_statuses)) THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'p_status must be one of: active, expiring, expired, canceled, trialing.',
        'fields',  jsonb_build_object('p_status', 'invalid')
      )
    );
  END IF;

  INSERT INTO public.tenant_subscriptions (
    tenant_id,
    stripe_subscription_id,
    status,
    current_period_end,
    created_at,
    updated_at,
    row_version
  )
  VALUES (
    p_tenant_id,
    p_stripe_subscription_id,
    p_status,
    p_current_period_end,
    now(),
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
    'ok',   true,
    'code', 'OK',
    'data', jsonb_build_object(
      'tenant_id', p_tenant_id,
      'status',    p_status
    ),
    'error', null
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'ok',   false,
    'code', 'INTERNAL',
    'data', '{}'::jsonb,
    'error', jsonb_build_object(
      'message', SQLERRM,
      'fields',  '{}'::jsonb
    )
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.upsert_subscription_v1(uuid, text, text, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.upsert_subscription_v1(uuid, text, text, timestamptz) FROM authenticated;

-- Step 5: Update get_user_entitlements_v1() to return trialing status.
-- trialing stored in tenant_subscriptions.status by webhook via upsert_subscription_v1.
-- trialing treated same as active for routing and access.

CREATE OR REPLACE FUNCTION public.get_user_entitlements_v1()
RETURNS json
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_tenant              uuid;
  v_user                uuid;
  v_role                public.tenant_role;
  v_member              boolean;
  v_archived_at         timestamptz;
  v_raw_status          text;
  v_sub_status          text;
  v_sub_days_remaining  integer;
  v_period_end          timestamptz;
  v_expiring_threshold  integer := 5;
  v_grace_days          integer := 60;
  v_app_mode            text;
  v_can_manage_billing  boolean;
  v_renew_route         text;
  v_retention_deadline  timestamptz;
  v_days_until_deletion integer;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'No tenant or user context',
        'fields',  json_build_object()
      )
    );
  END IF;

  SELECT tm.role INTO v_role
  FROM public.tenant_memberships tm
  WHERE tm.tenant_id = v_tenant
    AND tm.user_id   = v_user;

  v_member := FOUND;

  IF NOT v_member THEN
    RETURN json_build_object(
      'ok',   true,
      'code', 'OK',
      'data', json_build_object(
        'tenant_id',                   v_tenant,
        'user_id',                     v_user,
        'is_member',                   false,
        'role',                        null,
        'entitled',                    false,
        'subscription_status',         'none',
        'subscription_days_remaining', null,
        'app_mode',                    'normal',
        'can_manage_billing',          false,
        'renew_route',                 'none',
        'retention_deadline',          null,
        'days_until_deletion',         null
      ),
      'error', null
    );
  END IF;

  SELECT t.archived_at INTO v_archived_at
  FROM public.tenants t
  WHERE t.id = v_tenant;

  IF v_archived_at IS NOT NULL THEN
    RETURN json_build_object(
      'ok',   true,
      'code', 'OK',
      'data', json_build_object(
        'tenant_id',                   v_tenant,
        'user_id',                     v_user,
        'is_member',                   true,
        'role',                        v_role,
        'entitled',                    true,
        'subscription_status',         'expired',
        'subscription_days_remaining', null,
        'app_mode',                    'archived_unreachable',
        'can_manage_billing',          false,
        'renew_route',                 'none',
        'retention_deadline',          null,
        'days_until_deletion',         GREATEST(0,
          EXTRACT(DAY FROM (v_archived_at + interval '6 months' - now()))::integer
        )
      ),
      'error', null
    );
  END IF;

  SELECT ts.status, ts.current_period_end
  INTO v_raw_status, v_period_end
  FROM public.tenant_subscriptions ts
  WHERE ts.tenant_id = v_tenant;

  IF NOT FOUND THEN
    v_sub_status          := 'none';
    v_sub_days_remaining  := null;
    v_app_mode            := 'read_only_expired';
    v_can_manage_billing  := (v_role = 'owner');
    v_renew_route         := CASE WHEN v_role = 'owner' THEN 'billing' ELSE 'none' END;
    v_retention_deadline  := null;
    v_days_until_deletion := null;

  ELSIF v_raw_status = 'trialing' THEN
    v_sub_status         := 'trialing';
    v_sub_days_remaining := GREATEST(0, EXTRACT(DAY FROM (v_period_end - now()))::integer);
    v_app_mode           := 'normal';
    v_can_manage_billing := (v_role = 'owner');
    v_renew_route        := CASE WHEN v_role = 'owner' THEN 'billing' ELSE 'none' END;
    v_retention_deadline  := null;
    v_days_until_deletion := null;

  ELSIF v_raw_status = 'canceled' OR v_period_end <= now() THEN
    v_sub_status         := 'expired';
    v_sub_days_remaining := null;
    v_retention_deadline := v_period_end + (v_grace_days || ' days')::interval;

    IF now() <= v_retention_deadline THEN
      v_app_mode           := 'read_only_expired';
      v_can_manage_billing := (v_role = 'owner');
      v_renew_route        := CASE WHEN v_role = 'owner' THEN 'billing' ELSE 'none' END;
      v_days_until_deletion := null;
    ELSE
      v_app_mode            := 'archived_unreachable';
      v_can_manage_billing  := false;
      v_renew_route         := 'none';
      v_days_until_deletion := GREATEST(0,
        EXTRACT(DAY FROM (v_retention_deadline + interval '6 months' - now()))::integer
      );
    END IF;

  ELSIF v_raw_status IN ('active', 'expiring') THEN
    v_sub_days_remaining := GREATEST(0, EXTRACT(DAY FROM (v_period_end - now()))::integer);
    IF v_sub_days_remaining <= v_expiring_threshold THEN
      v_sub_status := 'expiring';
    ELSE
      v_sub_status         := 'active';
      v_sub_days_remaining := null;
    END IF;
    v_app_mode            := 'normal';
    v_can_manage_billing  := (v_role = 'owner');
    v_renew_route         := CASE WHEN v_role = 'owner' THEN 'billing' ELSE 'none' END;
    v_retention_deadline  := null;
    v_days_until_deletion := null;

  ELSE
    v_sub_status          := 'none';
    v_sub_days_remaining  := null;
    v_app_mode            := 'normal';
    v_can_manage_billing  := (v_role = 'owner');
    v_renew_route         := CASE WHEN v_role = 'owner' THEN 'billing' ELSE 'none' END;
    v_retention_deadline  := null;
    v_days_until_deletion := null;
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'tenant_id',                   v_tenant,
      'user_id',                     v_user,
      'is_member',                   v_member,
      'role',                        v_role,
      'entitled',                    v_member,
      'subscription_status',         v_sub_status,
      'subscription_days_remaining', v_sub_days_remaining,
      'app_mode',                    v_app_mode,
      'can_manage_billing',          v_can_manage_billing,
      'renew_route',                 v_renew_route,
      'retention_deadline',          v_retention_deadline,
      'days_until_deletion',         v_days_until_deletion
    ),
    'error', null
  );
END;
$fn$;
-- Step 6: Update tenant_subscriptions_status_check constraint to allow trialing.
ALTER TABLE public.tenant_subscriptions
  DROP CONSTRAINT IF EXISTS tenant_subscriptions_status_check;

ALTER TABLE public.tenant_subscriptions
  ADD CONSTRAINT tenant_subscriptions_status_check
  CHECK (status IN ('active', 'expiring', 'expired', 'canceled', 'trialing'));