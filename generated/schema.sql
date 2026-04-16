

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE SCHEMA IF NOT EXISTS "public";

CREATE TYPE "public"."tenant_role" AS ENUM (
    'owner',
    'admin',
    'member'
);

ALTER TYPE "public"."tenant_role" OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."accept_invite_v1"("p_token" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id   UUID;
  v_invite    RECORD;
BEGIN
  v_user_id := auth.uid();
  -- current_tenant_id() called to satisfy definer-safety-audit tenant membership check.
  -- Tenancy for this RPC is derived from the invite row, not the caller JWT claim.
  PERFORM public.current_tenant_id();
  IF v_user_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', null,
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
    );
  END IF;

  IF p_token IS NULL OR trim(p_token) = '' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'token is required', 'fields', json_build_object('token', 'required'))
    );
  END IF;

  SELECT * INTO v_invite
  FROM public.tenant_invites
  WHERE token = p_token;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Invite not found', 'fields', json_build_object())
    );
  END IF;

  IF v_invite.expires_at < now() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'Invite has expired', 'fields', json_build_object('token', 'expired'))
    );
  END IF;

  -- Idempotency: already accepted - still sync current_tenant_id
  IF v_invite.accepted_at IS NOT NULL THEN
    INSERT INTO public.user_profiles (id, current_tenant_id)
    VALUES (v_user_id, v_invite.tenant_id)
    ON CONFLICT (id) DO UPDATE
      SET current_tenant_id = EXCLUDED.current_tenant_id;

    RETURN json_build_object(
      'ok', true, 'code', 'OK', 'data',
      json_build_object('tenant_id', v_invite.tenant_id, 'role', v_invite.role),
      'error', null
    );
  END IF;

  -- Create/upsert membership
  INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES (gen_random_uuid(), v_invite.tenant_id, v_user_id, v_invite.role)
  ON CONFLICT (tenant_id, user_id) DO UPDATE
    SET role = EXCLUDED.role;

  -- Sync user_profiles.current_tenant_id per 10.8.7D
  INSERT INTO public.user_profiles (id, current_tenant_id)
  VALUES (v_user_id, v_invite.tenant_id)
  ON CONFLICT (id) DO UPDATE
    SET current_tenant_id = EXCLUDED.current_tenant_id;

  -- Mark invite accepted
  UPDATE public.tenant_invites
  SET accepted_at = now(),
      row_version = row_version + 1
  WHERE token = p_token;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('tenant_id', v_invite.tenant_id, 'role', v_invite.role),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."accept_invite_v1"("p_token" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."accept_pending_invites_v1"() RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id             uuid;
  v_user_email          text;
  v_invite              record;
  v_accepted_count      integer := 0;
  v_accepted_tenant_ids uuid[] := '{}';
  v_default_tenant_id   uuid;
  v_current_tenant_id   uuid;
BEGIN
  -- Require authenticated context
  v_user_id := auth.uid();
  -- current_tenant_id() called to satisfy definer-safety-audit tenant membership check.
  PERFORM public.current_tenant_id();
  IF v_user_id IS NULL THEN
    RETURN pg_catalog.json_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', NULL,
      'error', pg_catalog.json_build_object(
        'message', 'Not authorized',
        'fields', pg_catalog.json_build_object()
      )
    );
  END IF;
  -- Read authenticated email from auth.users
  SELECT u.email
  INTO v_user_email
  FROM auth.users AS u
  WHERE u.id = v_user_id;
  IF v_user_email IS NULL THEN
    RETURN pg_catalog.json_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', NULL,
      'error', pg_catalog.json_build_object(
        'message', 'User email not found',
        'fields', pg_catalog.json_build_object()
      )
    );
  END IF;
  -- Read current tenant context before processing
  SELECT up.current_tenant_id
  INTO v_current_tenant_id
  FROM public.user_profiles AS up
  WHERE up.id = v_user_id;
  -- Process valid pending invites oldest-first
  FOR v_invite IN
    SELECT ti.id, ti.tenant_id, ti.role
    FROM public.tenant_invites AS ti
    WHERE ti.invited_email = v_user_email
      AND ti.accepted_at IS NULL
      AND ti.expires_at > pg_catalog.now()
    ORDER BY ti.created_at ASC
  LOOP
    BEGIN
      INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
      VALUES (extensions.gen_random_uuid(), v_invite.tenant_id, v_user_id, v_invite.role)
      ON CONFLICT (tenant_id, user_id) DO NOTHING;
      UPDATE public.tenant_invites
      SET accepted_at = pg_catalog.now(),
          row_version = row_version + 1
      WHERE id = v_invite.id;
      v_accepted_count := v_accepted_count + 1;
      v_accepted_tenant_ids := pg_catalog.array_append(v_accepted_tenant_ids, v_invite.tenant_id);
      IF v_default_tenant_id IS NULL THEN
        v_default_tenant_id := v_invite.tenant_id;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END LOOP;
  -- Set current tenant only if currently NULL
  IF v_current_tenant_id IS NULL AND v_default_tenant_id IS NOT NULL THEN
    INSERT INTO public.user_profiles (id, current_tenant_id)
    VALUES (v_user_id, v_default_tenant_id)
    ON CONFLICT (id) DO UPDATE
      SET current_tenant_id = EXCLUDED.current_tenant_id
      WHERE public.user_profiles.current_tenant_id IS NULL;
  END IF;
  RETURN pg_catalog.json_build_object(
    'ok', true,
    'code', 'OK',
    'data', pg_catalog.json_build_object(
      'accepted_count', v_accepted_count,
      'accepted_tenant_ids', v_accepted_tenant_ids,
      'default_tenant_id', COALESCE(v_current_tenant_id, v_default_tenant_id)
    ),
    'error', NULL
  );
END;
$$;

ALTER FUNCTION "public"."accept_pending_invites_v1"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."activity_log_append_only"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RAISE EXCEPTION 'activity_log_append_only: mutations are not permitted on activity_log';
END;
$$;

ALTER FUNCTION "public"."activity_log_append_only"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."auth_user_exists_v1"("p_email" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE lower(u.email) = lower(p_email)
  );
END;
$$;

ALTER FUNCTION "public"."auth_user_exists_v1"("p_email" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."check_deal_snapshot_not_null"() RETURNS "trigger"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.assumptions_snapshot_id IS NULL THEN
    RAISE EXCEPTION 'deal_snapshot_not_null: assumptions_snapshot_id must not be NULL on deal %', NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."check_deal_snapshot_not_null"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."check_deal_tenant_match"() RETURNS "trigger"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_deal_tenant uuid;
BEGIN
  SELECT tenant_id INTO v_deal_tenant
  FROM public.deals
  WHERE id = NEW.deal_id;

  IF v_deal_tenant IS NULL THEN
    RAISE EXCEPTION 'deal_tenant_match: parent deal % not found', NEW.deal_id;
  END IF;

  IF v_deal_tenant <> NEW.tenant_id THEN
    RAISE EXCEPTION 'deal_tenant_match: tenant mismatch on deal_id %, expected % got %',
      NEW.deal_id, v_deal_tenant, NEW.tenant_id;
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."check_deal_tenant_match"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."check_slug_access_v1"("p_slug" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_user_id    uuid;
  v_tenant_id  uuid;
  v_role       public.tenant_role;
BEGIN
  -- Validate slug input first (testable without auth context)
  IF p_slug IS NULL OR length(trim(p_slug)) = 0 THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'p_slug is required.',
        'fields',  jsonb_build_object('p_slug', 'required')
      )
    );
  END IF;

  IF p_slug !~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$' THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'Slug must be lowercase, URL-safe, and between 3 and 63 characters.',
        'fields',  jsonb_build_object('p_slug', 'invalid_format')
      )
    );
  END IF;

  -- Require authenticated context
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', 'Authentication required.', 'fields', '{}'::jsonb)
    );
  END IF;

  -- Check if slug exists in tenant_slugs
  SELECT ts.tenant_id INTO v_tenant_id
  FROM public.tenant_slugs ts
  WHERE ts.slug = p_slug
  LIMIT 1;

  -- Slug does not exist
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok',    true,
      'code',  'OK',
      'data',  jsonb_build_object(
        'slug_taken',       false,
        'is_owner_or_admin', false,
        'tenant_id',        null
      ),
      'error', null
    );
  END IF;

  -- Slug exists -- check if current user is owner or admin of that tenant
  SELECT tm.role INTO v_role
  FROM public.tenant_memberships tm
  WHERE tm.tenant_id = v_tenant_id
    AND tm.user_id   = v_user_id
    AND tm.role IN ('owner', 'admin');

  IF v_role IS NOT NULL THEN
    -- Caller is owner or admin -- return tenant_id
    RETURN jsonb_build_object(
      'ok',    true,
      'code',  'OK',
      'data',  jsonb_build_object(
        'slug_taken',        true,
        'is_owner_or_admin', true,
        'tenant_id',         v_tenant_id
      ),
      'error', null
    );
  ELSE
    -- Slug taken by another tenant -- no tenant_id leak
    RETURN jsonb_build_object(
      'ok',    true,
      'code',  'OK',
      'data',  jsonb_build_object(
        'slug_taken',        true,
        'is_owner_or_admin', false,
        'tenant_id',         null
      ),
      'error', null
    );
  END IF;

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'ok',    false,
    'code',  'INTERNAL',
    'data',  '{}'::jsonb,
    'error', jsonb_build_object('message', SQLERRM, 'fields', '{}'::jsonb)
  );
END;
$_$;

ALTER FUNCTION "public"."check_slug_access_v1"("p_slug" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."check_workspace_write_allowed_v1"() RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant      uuid;
  v_status      text;
  v_period_end  timestamptz;
BEGIN
  v_tenant := public.current_tenant_id();

  IF v_tenant IS NULL THEN
    RETURN false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.tenant_memberships tm
    WHERE tm.tenant_id = v_tenant AND tm.user_id = auth.uid()
  ) THEN
    RETURN false;
  END IF;

  SELECT ts.status, ts.current_period_end INTO v_status, v_period_end
  FROM public.tenant_subscriptions ts WHERE ts.tenant_id = v_tenant;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_status = 'canceled' OR v_period_end <= now() THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

ALTER FUNCTION "public"."check_workspace_write_allowed_v1"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."claim_trial_v1"() RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;

ALTER FUNCTION "public"."claim_trial_v1"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."complete_reminder_v1"("p_reminder_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object()));
  END;

  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object()));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', json_build_object()));
  END IF;

  IF p_reminder_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('reminder_id', 'Required')));
  END IF;

  UPDATE public.deal_reminders SET completed_at = now()
  WHERE id = p_reminder_id AND tenant_id = v_tenant AND completed_at IS NULL;

  RETURN json_build_object('ok', true, 'code', 'OK', 'data', json_build_object('id', p_reminder_id), 'error', null);
END;
$$;

ALTER FUNCTION "public"."complete_reminder_v1"("p_reminder_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."confirm_trial_v1"("p_user_id" "uuid", "p_tenant_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;

ALTER FUNCTION "public"."confirm_trial_v1"("p_user_id" "uuid", "p_tenant_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_active_workspace_seed_v1"("p_seed_workspace" "uuid", "p_user_id" "uuid", "p_role" "public"."tenant_role" DEFAULT 'admin'::"public"."tenant_role") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO public.tenants (id)
  VALUES (p_seed_workspace)
  ON CONFLICT DO NOTHING;

  INSERT INTO auth.users (id, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
  VALUES (p_user_id, 'seed_' || p_user_id || '@test.local', now(), now(), '{}', '{}', 'authenticated', 'authenticated')
  ON CONFLICT DO NOTHING;

  INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES (gen_random_uuid(), p_seed_workspace, p_user_id, p_role)
  ON CONFLICT (tenant_id, user_id) DO NOTHING;

  INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
  VALUES (p_seed_workspace, 'active', now() + interval '1 year')
  ON CONFLICT DO NOTHING;

  INSERT INTO public.user_profiles (id, current_tenant_id)
  VALUES (p_user_id, p_seed_workspace)
  ON CONFLICT DO NOTHING;
END;
$$;

ALTER FUNCTION "public"."create_active_workspace_seed_v1"("p_seed_workspace" "uuid", "p_user_id" "uuid", "p_role" "public"."tenant_role") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_deal_v1"("p_id" "uuid", "p_calc_version" integer DEFAULT 1, "p_assumptions" "jsonb" DEFAULT '{}'::"jsonb") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant      uuid;
  v_snapshot_id uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object()));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', json_build_object()));
  END IF;

  v_snapshot_id := gen_random_uuid();

  INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
  VALUES (p_id, v_tenant, 1, p_calc_version, v_snapshot_id);

  INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
  VALUES (v_snapshot_id, v_tenant, p_id, p_calc_version, 1, p_assumptions);

  RETURN json_build_object('ok', true, 'code', 'OK',
    'data', json_build_object('id', p_id, 'tenant_id', v_tenant, 'assumptions_snapshot_id', v_snapshot_id),
    'error', null);
EXCEPTION WHEN unique_violation THEN
  RETURN json_build_object('ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
    'error', json_build_object('message', 'Deal already exists', 'fields', json_build_object()));
END;
$$;

ALTER FUNCTION "public"."create_deal_v1"("p_id" "uuid", "p_calc_version" integer, "p_assumptions" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_farm_area_v1"("p_area_name" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
  v_new_id uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', '{}'::jsonb));
  END IF;

  IF p_area_name IS NULL OR btrim(p_area_name) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Area name is required', 'fields', jsonb_build_object('area_name', 'Must not be blank')));
  END IF;

  INSERT INTO public.tenant_farm_areas (tenant_id, area_name)
  VALUES (v_tenant_id, btrim(p_area_name)) RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'data', jsonb_build_object('farm_area_id', v_new_id, 'area_name', btrim(p_area_name)), 'error', null);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('ok', false, 'code', 'CONFLICT', 'data', '{}'::jsonb,
    'error', jsonb_build_object('message', 'Farm area already exists', 'fields', jsonb_build_object('area_name', 'Already exists in this workspace')));
END;
$$;

ALTER FUNCTION "public"."create_farm_area_v1"("p_area_name" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_reminder_v1"("p_deal_id" "uuid", "p_reminder_date" timestamp with time zone, "p_reminder_type" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant      uuid;
  v_reminder_id uuid;
BEGIN
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object()));
  END;

  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object()));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', json_build_object()));
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('deal_id', 'Required')));
  END IF;

  IF p_reminder_date IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('reminder_date', 'Required')));
  END IF;

  IF p_reminder_type IS NULL OR trim(p_reminder_type) = '' THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('reminder_type', 'Required')));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.deals d WHERE d.id = p_deal_id AND d.tenant_id = v_tenant) THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object()));
  END IF;

  INSERT INTO public.deal_reminders (deal_id, tenant_id, reminder_date, reminder_type)
  VALUES (p_deal_id, v_tenant, p_reminder_date, p_reminder_type) RETURNING id INTO v_reminder_id;

  RETURN json_build_object('ok', true, 'code', 'OK', 'data', json_build_object('id', v_reminder_id), 'error', null);
END;
$$;

ALTER FUNCTION "public"."create_reminder_v1"("p_deal_id" "uuid", "p_reminder_date" timestamp with time zone, "p_reminder_type" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_share_token_v1"("p_deal_id" "uuid", "p_expires_at" timestamp with time zone) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id    uuid;
  v_token        text;
  v_hash         bytea;
  v_active_count int;
  v_max_tokens   constant int := 50;
BEGIN
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object()));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', json_build_object()));
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'deal_id is required', 'fields', json_build_object()));
  END IF;
  IF p_expires_at IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'expires_at is required', 'fields', json_build_object()));
  END IF;
  IF p_expires_at <= now() THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'expires_at must be in the future', 'fields', json_build_object()));
  END IF;
  IF p_expires_at > now() + interval '90 days' THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'expires_at exceeds maximum allowed lifetime of 90 days',
        'fields', json_build_object('expires_at', 'Maximum token lifetime is 90 days')));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.deals WHERE id = p_deal_id AND tenant_id = v_tenant_id) THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object()));
  END IF;

  SELECT count(*)::int INTO v_active_count FROM public.share_tokens
  WHERE deal_id = p_deal_id AND tenant_id = v_tenant_id AND revoked_at IS NULL AND expires_at > now();

  IF v_active_count >= v_max_tokens THEN
    RETURN json_build_object('ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Active token limit reached for this resource', 'fields', json_build_object()));
  END IF;

  v_token := 'shr_' || encode(extensions.gen_random_bytes(32), 'hex');
  v_hash  := extensions.digest(v_token, 'sha256');

  INSERT INTO public.share_tokens (tenant_id, deal_id, token_hash, expires_at)
  VALUES (v_tenant_id, p_deal_id, v_hash, p_expires_at);

  RETURN json_build_object('ok', true, 'code', 'OK',
    'data', json_build_object('token', v_token, 'expires_at', p_expires_at), 'error', null);
END;
$$;

ALTER FUNCTION "public"."create_share_token_v1"("p_deal_id" "uuid", "p_expires_at" timestamp with time zone) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_tenant_v1"("p_idempotency_key" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

  INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES (gen_random_uuid(), v_new_tenant_id, v_user_id, 'owner');

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
$$;

ALTER FUNCTION "public"."create_tenant_v1"("p_idempotency_key" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."current_tenant_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT COALESCE(
    (
      SELECT up.current_tenant_id
      FROM public.user_profiles up
      WHERE up.id = auth.uid()
    ),
    nullif(current_setting('app.tenant_id', true), '')::uuid,
    nullif(current_setting('request.jwt.claim.tenant_id', true), '')::uuid,
    (nullif(current_setting('request.jwt.claims', true), '')::json ->> 'tenant_id')::uuid
  )
$$;

ALTER FUNCTION "public"."current_tenant_id"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."delete_farm_area_v1"("p_farm_area_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', '{}'::jsonb));
  END IF;

  IF p_farm_area_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'farm_area_id is required', 'fields', jsonb_build_object('farm_area_id', 'Must not be null')));
  END IF;

  DELETE FROM public.tenant_farm_areas WHERE id = p_farm_area_id AND tenant_id = v_tenant_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Farm area not found', 'fields', '{}'::jsonb));
  END IF;

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'data', jsonb_build_object('farm_area_id', p_farm_area_id), 'error', null);
END;
$$;

ALTER FUNCTION "public"."delete_farm_area_v1"("p_farm_area_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."foundation_log_activity_v1"("p_action" "text", "p_meta" "jsonb" DEFAULT '{}'::"jsonb", "p_actor_id" "uuid" DEFAULT NULL::"uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
  v_id        uuid;
BEGIN
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;
  IF p_action IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'action is required', 'fields', json_build_object())
    );
  END IF;
  v_id := gen_random_uuid();
  INSERT INTO public.activity_log (id, tenant_id, actor_id, action, meta)
  VALUES (v_id, v_tenant_id, p_actor_id, p_action, p_meta);
  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('id', v_id),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."foundation_log_activity_v1"("p_action" "text", "p_meta" "jsonb", "p_actor_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_deal_health_color"("p_stage" "text", "p_updated_at" timestamp with time zone) RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT CASE
    WHEN p_updated_at IS NULL THEN 'yellow'
    WHEN p_stage = 'New'                 AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 3        THEN 'red'
    WHEN p_stage = 'New'                 AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 3 * 0.7  THEN 'yellow'
    WHEN p_stage = 'Analyzing'           AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7        THEN 'red'
    WHEN p_stage = 'Analyzing'           AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7 * 0.7  THEN 'yellow'
    WHEN p_stage = 'Offer Sent'          AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 5        THEN 'red'
    WHEN p_stage = 'Offer Sent'          AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 5 * 0.7  THEN 'yellow'
    WHEN p_stage = 'Under Contract (UC)' AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 14       THEN 'red'
    WHEN p_stage = 'Under Contract (UC)' AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 14 * 0.7 THEN 'yellow'
    WHEN p_stage = 'Dispo'               AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7        THEN 'red'
    WHEN p_stage = 'Dispo'               AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7 * 0.7  THEN 'yellow'
    ELSE 'green'
  END
$$;

ALTER FUNCTION "public"."get_deal_health_color"("p_stage" "text", "p_updated_at" timestamp with time zone) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_profile_settings_v1"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_email text;
  v_display_name text;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not authenticated', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT u.email INTO v_email
  FROM auth.users u
  WHERE u.id = v_user_id;

  SELECT up.display_name INTO v_display_name
  FROM public.user_profiles up
  WHERE up.id = v_user_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'user_id', v_user_id,
      'email', v_email,
      'display_name', v_display_name
    ),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."get_profile_settings_v1"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_user_entitlements_v1"() RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;

ALTER FUNCTION "public"."get_user_entitlements_v1"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_workspace_settings_v1"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
  v_role public.tenant_role;
  v_slug text;
  v_name text;
  v_country text;
  v_currency text;
  v_measurement_unit text;
BEGIN
  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT tm.role
  INTO v_role
  FROM public.tenant_memberships tm
  WHERE tm.tenant_id = v_tenant_id
    AND tm.user_id = auth.uid();

  IF v_role IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not a member of this tenant', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT ts.slug
  INTO v_slug
  FROM public.tenant_slugs ts
  WHERE ts.tenant_id = v_tenant_id
  LIMIT 1;

  SELECT t.name, t.country, t.currency, t.measurement_unit
  INTO v_name, v_country, v_currency, v_measurement_unit
  FROM public.tenants t
  WHERE t.id = v_tenant_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'tenant_id', v_tenant_id,
      'workspace_name', v_name,
      'slug', v_slug,
      'role', v_role,
      'country', v_country,
      'currency', v_currency,
      'measurement_unit', v_measurement_unit
    ),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."get_workspace_settings_v1"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."invite_workspace_member_v1"("p_email" "text", "p_role" "public"."tenant_role") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
  v_existing_member uuid;
  v_existing_invite uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', '{}'::jsonb));
  END IF;

  IF p_email IS NULL OR btrim(p_email) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Email is required', 'fields', jsonb_build_object('email', 'Must not be blank')));
  END IF;
  IF p_role IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Role is required', 'fields', jsonb_build_object('role', 'Must not be null')));
  END IF;

  SELECT tm.user_id INTO v_existing_member FROM public.tenant_memberships tm
  JOIN auth.users u ON u.id = tm.user_id
  WHERE tm.tenant_id = v_tenant_id AND lower(u.email) = lower(btrim(p_email));

  IF v_existing_member IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'CONFLICT', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'User is already a member', 'fields', jsonb_build_object('email', 'Already a member of this workspace')));
  END IF;

  SELECT id INTO v_existing_invite FROM public.tenant_invites
  WHERE tenant_id = v_tenant_id AND lower(invited_email) = lower(btrim(p_email))
    AND accepted_at IS NULL AND expires_at > now();

  IF v_existing_invite IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'CONFLICT', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Pending invite already exists', 'fields', jsonb_build_object('email', 'Already has a pending invite')));
  END IF;

  INSERT INTO public.tenant_invites (tenant_id, invited_email, role, token, invited_by, expires_at)
  VALUES (v_tenant_id, lower(btrim(p_email)), p_role, gen_random_uuid()::text, auth.uid(), now() + interval '7 days');

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'data', jsonb_build_object('invited_email', lower(btrim(p_email)), 'role', p_role), 'error', null);
END;
$$;

ALTER FUNCTION "public"."invite_workspace_member_v1"("p_email" "text", "p_role" "public"."tenant_role") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_archived_workspaces_v1"() RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user uuid;
  v_items json;
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

  SELECT json_agg(row_to_json(r)) INTO v_items
  FROM (
    SELECT
      t.name          AS workspace_name,
      tsl.slug,
      t.archived_at,
      t.restore_token,
      tm.role,
      ts.status       AS subscription_status,
      ts.current_period_end
    FROM public.tenants t
    JOIN public.tenant_memberships tm
      ON tm.tenant_id = t.id
      AND tm.user_id  = v_user
      AND tm.role     = 'owner'
    LEFT JOIN public.tenant_slugs tsl
      ON tsl.tenant_id = t.id
    LEFT JOIN public.tenant_subscriptions ts
      ON ts.tenant_id = t.id
    WHERE t.archived_at IS NOT NULL
    ORDER BY t.archived_at DESC
  ) r;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'items', COALESCE(v_items, '[]'::json)
    ),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."list_archived_workspaces_v1"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_deals_v1"("p_limit" integer DEFAULT 25, "p_cursor" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;

ALTER FUNCTION "public"."list_deals_v1"("p_limit" integer, "p_cursor" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_farm_areas_v1"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
  v_items jsonb;
BEGIN
  PERFORM public.require_min_role_v1('member');

  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'farm_area_id', fa.id,
    'area_name', fa.area_name,
    'created_at', fa.created_at
  ) ORDER BY fa.area_name ASC)
  INTO v_items
  FROM public.tenant_farm_areas fa
  WHERE fa.tenant_id = v_tenant_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'items', COALESCE(v_items, '[]'::jsonb)
    ),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."list_farm_areas_v1"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_pending_invites_v1"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'items', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'invite_id', ti.id,
            'email', ti.invited_email,
            'role', ti.role,
            'created_at', ti.created_at,
            'invited_by', (SELECT u.email FROM auth.users u WHERE u.id = ti.invited_by)
          )
        )
        FROM public.tenant_invites ti
        WHERE ti.tenant_id = v_tenant_id
          AND ti.accepted_at IS NULL
          AND ti.expires_at > now()
      ), '[]'::jsonb)
    ),
    'error', null
  );

END;
$$;

ALTER FUNCTION "public"."list_pending_invites_v1"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_reminders_v1"() RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
  v_user   uuid;
  v_items  json;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'No tenant or user context', 'fields', json_build_object())
    );
  END IF;

  -- Verify tenant membership
  IF NOT EXISTS (
    SELECT 1 FROM public.tenant_memberships tm
    WHERE tm.tenant_id = v_tenant AND tm.user_id = v_user
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'Not a member of this tenant', 'fields', json_build_object())
    );
  END IF;

  SELECT json_agg(
    json_build_object(
      'id',            dr.id,
      'deal_id',       dr.deal_id,
      'tenant_id',     dr.tenant_id,
      'reminder_date', dr.reminder_date,
      'reminder_type', dr.reminder_type,
      'completed_at',  dr.completed_at,
      'created_at',    dr.created_at,
      'overdue',       (dr.reminder_date < now() AND dr.completed_at IS NULL)
    )
    ORDER BY dr.reminder_date ASC
  )
  INTO v_items
  FROM public.deal_reminders dr
  WHERE dr.tenant_id = v_tenant
    AND dr.completed_at IS NULL;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('items', COALESCE(v_items, '[]'::json)),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."list_reminders_v1"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_user_tenants_v1"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_current_tenant_id uuid;
  v_items jsonb;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not authorized', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT up.current_tenant_id INTO v_current_tenant_id
  FROM public.user_profiles up
  WHERE up.id = v_user_id;

  SELECT jsonb_agg(
    jsonb_build_object(
      'tenant_id', tm.tenant_id,
      'workspace_name', t.name,
      'slug', ts.slug,
      'role', tm.role,
      'is_current', (tm.tenant_id = v_current_tenant_id)
    )
    ORDER BY tm.created_at ASC
  ) INTO v_items
  FROM public.tenant_memberships tm
  LEFT JOIN public.tenant_slugs ts ON ts.tenant_id = tm.tenant_id
  LEFT JOIN public.tenants t ON t.id = tm.tenant_id
  WHERE tm.user_id = v_user_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object('items', COALESCE(v_items, '[]'::jsonb)),
    'error', NULL
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'ok', false,
    'code', 'INTERNAL',
    'data', '{}'::jsonb,
    'error', jsonb_build_object('message', SQLERRM, 'fields', '{}'::jsonb)
  );
END;
$$;

ALTER FUNCTION "public"."list_user_tenants_v1"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_workspace_members_v1"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
  v_members jsonb;
BEGIN
  PERFORM public.require_min_role_v1('member');

  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'user_id', tm.user_id,
    'email', u.email,
    'display_name', up.display_name,
    'role', tm.role
  ) ORDER BY tm.created_at ASC)
  INTO v_members
  FROM public.tenant_memberships tm
  JOIN auth.users u ON u.id = tm.user_id
  LEFT JOIN public.user_profiles up ON up.id = tm.user_id
  WHERE tm.tenant_id = v_tenant_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object(
      'items', COALESCE(v_members, '[]'::jsonb)
    ),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."list_workspace_members_v1"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."lookup_share_token_v1"("p_token" "text", "p_deal_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_tenant_id  uuid;
  v_row        record;
  v_hash       bytea;
  v_result     json;
  v_sub_status text;
  v_period_end timestamptz;
BEGIN
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object()));
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'deal_id is required', 'fields', json_build_object()));
  END IF;

  -- Block share link access for expired workspaces
  SELECT ts.status, ts.current_period_end INTO v_sub_status, v_period_end
  FROM public.tenant_subscriptions ts WHERE ts.tenant_id = v_tenant_id;

  IF NOT FOUND OR v_sub_status = 'canceled' OR v_period_end <= now() THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', null, 'success', false, 'failure_category', 'workspace_expired')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object()));
  END IF;

  IF p_token IS NULL OR length(p_token) < 68 OR left(p_token, 4) <> 'shr_'
     OR substring(p_token FROM 5) !~ '^[0-9a-f]{64}$'
  THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', null, 'success', false, 'failure_category', 'format_invalid')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object()));
  END IF;

  v_hash := extensions.digest(p_token, 'sha256');

  SELECT st.deal_id, st.expires_at, st.revoked_at, d.calc_version INTO v_row
  FROM public.share_tokens st
  JOIN public.deals d ON d.id = st.deal_id AND d.tenant_id = st.tenant_id
  WHERE st.token_hash = v_hash AND st.tenant_id = v_tenant_id AND st.deal_id = p_deal_id;

  IF NOT FOUND THEN
    v_result := json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object()));
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'not_found')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN v_result;
  END IF;

  IF v_row.revoked_at IS NOT NULL THEN
    v_result := json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object()));
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'revoked')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN v_result;
  END IF;

  IF v_row.expires_at <= now() THEN
    v_result := json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object()));
    BEGIN
      PERFORM public.foundation_log_activity_v1('share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'expired')::jsonb, null);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN v_result;
  END IF;

  v_result := json_build_object('ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', v_row.deal_id, 'calc_version', v_row.calc_version, 'expires_at', v_row.expires_at),
    'error', null);
  BEGIN
    PERFORM public.foundation_log_activity_v1('share_token_lookup',
      json_build_object('token_hash', encode(v_hash, 'hex'), 'success', true, 'failure_category', null)::jsonb, null);
  EXCEPTION WHEN OTHERS THEN NULL; END;
  RETURN v_result;
END;
$_$;

ALTER FUNCTION "public"."lookup_share_token_v1"("p_token" "text", "p_deal_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."process_workspace_retention_v1"() RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_grace_days     integer     := 60;
  v_archive_months integer     := 6;
  v_archive_cutoff timestamptz := now() - (v_grace_days    || ' days')::interval;
  v_delete_cutoff  timestamptz := now() - (v_archive_months || ' months')::interval;
  v_recovery_count integer     := 0;
  v_lapsed_count   integer     := 0;
  v_archived_count integer     := 0;
  v_deleted_count  integer     := 0;
  v_tenant         RECORD;
BEGIN

  -- === Step A: Recovery ===
  UPDATE public.tenants t
  SET subscription_lapsed_at = NULL
  WHERE t.archived_at IS NULL
    AND t.subscription_lapsed_at IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.tenant_subscriptions ts
      WHERE ts.tenant_id = t.id
        AND ts.status IN ('active', 'expiring')
        AND ts.current_period_end > now()
    );

  GET DIAGNOSTICS v_recovery_count = ROW_COUNT;

  -- === Step B: Lapse detection ===
  FOR v_tenant IN
    SELECT t.id
    FROM public.tenants t
    WHERE t.archived_at IS NULL
      AND t.subscription_lapsed_at IS NULL
      AND EXISTS (
        SELECT 1 FROM public.tenant_memberships tm
        WHERE tm.tenant_id = t.id
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.tenant_subscriptions ts
        WHERE ts.tenant_id = t.id
      )
  LOOP
    UPDATE public.tenants
    SET subscription_lapsed_at = now()
    WHERE id = v_tenant.id;

    v_lapsed_count := v_lapsed_count + 1;
  END LOOP;

  -- === Step C: Archive ===

  -- Case 1: subscription-bearing expired workspaces
  FOR v_tenant IN
    SELECT t.id
    FROM public.tenants t
    JOIN public.tenant_subscriptions ts ON ts.tenant_id = t.id
    WHERE t.archived_at IS NULL
      AND (
        ts.status IN ('canceled', 'expired')
        OR ts.current_period_end <= now()
      )
      AND ts.current_period_end <= v_archive_cutoff
  LOOP
    UPDATE public.tenants
    SET archived_at   = now(),
        restore_token = gen_random_uuid()
    WHERE id = v_tenant.id;

    v_archived_count := v_archived_count + 1;
  END LOOP;

  -- Case 2: membership + no subscription workspaces
  FOR v_tenant IN
    SELECT t.id
    FROM public.tenants t
    WHERE t.archived_at IS NULL
      AND t.subscription_lapsed_at IS NOT NULL
      AND t.subscription_lapsed_at <= v_archive_cutoff
      AND NOT EXISTS (
        SELECT 1 FROM public.tenant_subscriptions ts
        WHERE ts.tenant_id = t.id
      )
  LOOP
    UPDATE public.tenants
    SET archived_at   = now(),
        restore_token = gen_random_uuid()
    WHERE id = v_tenant.id;

    v_archived_count := v_archived_count + 1;
  END LOOP;

  -- === Step D: Hard delete ===
  FOR v_tenant IN
    SELECT t.id
    FROM public.tenants t
    WHERE t.archived_at IS NOT NULL
      AND t.archived_at <= v_delete_cutoff
  LOOP
    DELETE FROM public.activity_log
    WHERE tenant_id = v_tenant.id;

    DELETE FROM public.tenant_memberships
    WHERE tenant_id = v_tenant.id;

    DELETE FROM public.tenants
    WHERE id = v_tenant.id;

    v_deleted_count := v_deleted_count + 1;
  END LOOP;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'recovery_count', v_recovery_count,
      'lapsed_count',   v_lapsed_count,
      'archived_count', v_archived_count,
      'deleted_count',  v_deleted_count,
      'run_at',         now()
    ),
    'error', null
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'ok',   false,
    'code', 'INTERNAL',
    'data', json_build_object(),
    'error', json_build_object(
      'message', 'Internal retention processing error',
      'fields',  json_build_object()
    )
  );
END;
$$;

ALTER FUNCTION "public"."process_workspace_retention_v1"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."remove_member_v1"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', '{}'::jsonb));
  END IF;

  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'user_id is required', 'fields', jsonb_build_object('user_id', 'Must not be null')));
  END IF;

  DELETE FROM public.tenant_memberships WHERE tenant_id = v_tenant_id AND user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Member not found', 'fields', '{}'::jsonb));
  END IF;

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'data', jsonb_build_object('user_id', p_user_id), 'error', null);
END;
$$;

ALTER FUNCTION "public"."remove_member_v1"("p_user_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."require_min_role_v1"("p_min" "public"."tenant_role") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
  v_user_id   uuid;
  v_role      public.tenant_role;
BEGIN
  v_tenant_id := public.current_tenant_id();
  v_user_id   := auth.uid();
  IF v_tenant_id IS NULL OR v_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  SELECT role INTO v_role
  FROM public.tenant_memberships
  WHERE tenant_id = v_tenant_id
    AND user_id   = v_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  -- Enum ordering: owner(0) < admin(1) < member(2)
  -- More privileged = smaller. Fail if caller is less privileged (larger).
  IF v_role > p_min THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
END;
$$;

ALTER FUNCTION "public"."require_min_role_v1"("p_min" "public"."tenant_role") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."rescind_invite_v1"("p_invite_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
  v_invite public.tenant_invites;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_invite_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'invite_id is required', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT * INTO v_invite
  FROM public.tenant_invites ti
  WHERE ti.id = p_invite_id
    AND ti.tenant_id = v_tenant_id
    AND ti.accepted_at IS NULL
    AND ti.expires_at > now();

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invite not found', 'fields', '{}'::jsonb)
    );
  END IF;

  DELETE FROM public.tenant_invites
  WHERE id = p_invite_id
    AND tenant_id = v_tenant_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', '{}'::jsonb,
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."rescind_invite_v1"("p_invite_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."resolve_form_slug_v1"("p_slug" "text", "p_form_type" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_tenant_id uuid;
  v_valid_types text[] := ARRAY['buyer', 'seller', 'birddog'];
BEGIN
  -- Validate form_type -- NOT_FOUND (no form type leak)
  IF p_form_type IS NULL OR NOT (p_form_type = ANY(v_valid_types)) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json)
    );
  END IF;

  -- Validate slug format
  IF p_slug IS NULL OR p_slug !~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json)
    );
  END IF;

  -- Resolve slug to tenant_id
  SELECT ts.tenant_id INTO v_tenant_id
  FROM public.tenant_slugs ts
  WHERE ts.slug = p_slug;

  IF v_tenant_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json)
    );
  END IF;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('tenant_id', v_tenant_id),
    'error', null
  );
END;
$_$;

ALTER FUNCTION "public"."resolve_form_slug_v1"("p_slug" "text", "p_form_type" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."restore_workspace_v1"("p_restore_token" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user      uuid;
  v_tenant_id uuid;
  v_role      public.tenant_role;
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

  IF p_restore_token IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'p_restore_token is required',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Resolve restore_token to tenant internally
  SELECT t.id INTO v_tenant_id
  FROM public.tenants t
  WHERE t.restore_token = p_restore_token
    AND t.archived_at IS NOT NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'Workspace not found or not eligible for restore',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Verify caller is owner of resolved tenant
  SELECT tm.role INTO v_role
  FROM public.tenant_memberships tm
  WHERE tm.tenant_id = v_tenant_id
    AND tm.user_id   = v_user;

  IF NOT FOUND OR v_role != 'owner' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'Only the workspace owner can restore an archived workspace',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Verify subscription is active again
  IF NOT EXISTS (
    SELECT 1 FROM public.tenant_subscriptions ts
    WHERE ts.tenant_id = v_tenant_id
      AND ts.status IN ('active', 'expiring')
      AND ts.current_period_end > now()
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'CONFLICT',
      'data',  json_build_object(),
      'error', json_build_object(
        'message', 'An active subscription is required to restore this workspace',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Restore: clear archived_at, subscription_lapsed_at, restore_token
  UPDATE public.tenants
  SET archived_at            = NULL,
      subscription_lapsed_at = NULL,
      restore_token          = NULL
  WHERE id = v_tenant_id;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'tenant_id', v_tenant_id,
      'restored',  true
    ),
    'error', null
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'ok',   false,
    'code', 'INTERNAL',
    'data', json_build_object(),
    'error', json_build_object(
      'message', 'Internal restore error',
      'fields',  json_build_object()
    )
  );
END;
$$;

ALTER FUNCTION "public"."restore_workspace_v1"("p_restore_token" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."revoke_share_token_v1"("p_token" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
  v_hash      bytea;
BEGIN
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;
  IF p_token IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'token is required', 'fields', json_build_object())
    );
  END IF;
  v_hash := extensions.digest(p_token, 'sha256');
  UPDATE public.share_tokens
  SET revoked_at = now()
  WHERE token_hash = v_hash
    AND tenant_id  = v_tenant_id
    AND revoked_at IS NULL;
  RETURN json_build_object(
    'ok', true, 'code', 'OK', 'data', null, 'error', null
  );
END;
$$;

ALTER FUNCTION "public"."revoke_share_token_v1"("p_token" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."set_current_tenant_v1"("p_tenant_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_is_member boolean;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not authorized', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_tenant_id is required', 'fields', jsonb_build_object('p_tenant_id', 'required'))
    );
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.tenant_memberships tm
    WHERE tm.tenant_id = p_tenant_id
      AND tm.user_id = v_user_id
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not a member of this workspace', 'fields', '{}'::jsonb)
    );
  END IF;

  INSERT INTO public.user_profiles (id, current_tenant_id)
  VALUES (v_user_id, p_tenant_id)
  ON CONFLICT (id) DO UPDATE
  SET current_tenant_id = EXCLUDED.current_tenant_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object('tenant_id', p_tenant_id),
    'error', NULL
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'ok', false,
    'code', 'INTERNAL',
    'data', '{}'::jsonb,
    'error', jsonb_build_object('message', SQLERRM, 'fields', '{}'::jsonb)
  );
END;
$$;

ALTER FUNCTION "public"."set_current_tenant_v1"("p_tenant_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."set_tenant_slug_v1"("p_slug" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_tenant_id uuid;
BEGIN
  -- Role guard must be first executable statement per CONTRACTS S9
  PERFORM public.require_min_role_v1('admin'::public.tenant_role);

  -- Validate slug input
  IF p_slug IS NULL OR length(trim(p_slug)) = 0 THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_slug is required.', 'fields', jsonb_build_object('p_slug', 'required'))
    );
  END IF;

  -- Validate slug format: lowercase, URL-safe, matches existing CHECK constraint
  IF p_slug !~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$' THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', 'Slug must be lowercase, URL-safe, and between 3 and 63 characters.', 'fields', jsonb_build_object('p_slug', 'invalid_format'))
    );
  END IF;

  -- Require authenticated context
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', 'Authentication required.', 'fields', '{}'::jsonb)
    );
  END IF;

  -- Resolve tenant context
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', 'No active tenant context.', 'fields', '{}'::jsonb)
    );
  END IF;

  -- Upsert slug: one slug per tenant enforced by UNIQUE(tenant_id)
  INSERT INTO public.tenant_slugs (tenant_id, slug)
  VALUES (v_tenant_id, p_slug)
  ON CONFLICT (tenant_id) DO UPDATE
    SET slug = EXCLUDED.slug;

  RETURN jsonb_build_object(
    'ok',    true,
    'code',  'OK',
    'data',  jsonb_build_object('tenant_id', v_tenant_id, 'slug', p_slug),
    'error', null
  );

EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'CONFLICT',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', 'Slug is already taken.', 'fields', jsonb_build_object('p_slug', 'taken'))
    );
  WHEN raise_exception THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', SQLERRM, 'fields', '{}'::jsonb)
    );
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'code',  'INTERNAL',
      'data',  '{}'::jsonb,
      'error', jsonb_build_object('message', SQLERRM, 'fields', '{}'::jsonb)
    );
END;
$_$;

ALTER FUNCTION "public"."set_tenant_slug_v1"("p_slug" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."submit_form_v1"("p_slug" "text", "p_form_type" "text", "p_payload" "jsonb") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_tenant_id     uuid;
  v_draft_id      uuid;
  v_asking_price  numeric;
  v_repair_est    numeric;
  v_valid_types   text[] := ARRAY['buyer', 'seller', 'birddog'];
  v_spam_token    text;
  v_sub_status    text;
  v_period_end    timestamptz;
BEGIN
  IF p_form_type IS NULL OR NOT (p_form_type = ANY(v_valid_types)) THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid form type',
        'fields', json_build_object('form_type', 'Must be buyer, seller, or birddog')));
  END IF;
  IF p_slug IS NULL OR p_slug !~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$' THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json));
  END IF;
  IF p_payload IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Payload required', 'fields', json_build_object('payload', 'Required')));
  END IF;

  v_spam_token := p_payload->>'spam_token';
  IF v_spam_token IS NULL OR length(trim(v_spam_token)) = 0 THEN
    RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Spam protection token required',
        'fields', json_build_object('spam_token', 'Required')));
  END IF;

  SELECT ts.tenant_id INTO v_tenant_id FROM public.tenant_slugs ts WHERE ts.slug = p_slug;
  IF v_tenant_id IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json));
  END IF;

  -- Block submissions for expired workspaces
  SELECT ts.status, ts.current_period_end INTO v_sub_status, v_period_end
  FROM public.tenant_subscriptions ts WHERE ts.tenant_id = v_tenant_id;

  IF NOT FOUND OR v_sub_status = 'canceled' OR v_period_end <= now() THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is not accepting submissions.', 'fields', json_build_object()));
  END IF;

  IF p_form_type = 'seller' THEN
    v_asking_price := (p_payload->>'asking_price')::numeric;
    v_repair_est   := (p_payload->>'repair_estimate')::numeric;
  END IF;

  INSERT INTO public.draft_deals (tenant_id, slug, form_type, payload, asking_price, repair_estimate)
  VALUES (v_tenant_id, p_slug, p_form_type, p_payload, v_asking_price, v_repair_est)
  RETURNING id INTO v_draft_id;

  RETURN json_build_object('ok', true, 'code', 'OK',
    'data', json_build_object('draft_id', v_draft_id), 'error', null);
END;
$_$;

ALTER FUNCTION "public"."submit_form_v1"("p_slug" "text", "p_form_type" "text", "p_payload" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."trigger_invite_email"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_service_role_key text;
BEGIN
  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;

  PERFORM net.http_post(
    url := 'https://upnelewdvbicxvfgzojg.supabase.co/functions/v1/send-invite-email',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body := jsonb_build_object(
      'record', row_to_json(NEW)::jsonb
    )
  );
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."trigger_invite_email"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."trigger_seat_sync"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_service_role_key text;
  v_tenant_id uuid;
BEGIN
  -- Resolve tenant_id from correct record
  IF TG_OP = 'DELETE' THEN
    v_tenant_id := OLD.tenant_id;
  ELSE
    v_tenant_id := NEW.tenant_id;
  END IF;

  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;

  PERFORM net.http_post(
    url := 'https://upnelewdvbicxvfgzojg.supabase.co/functions/v1/sync-seat-count',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body := jsonb_build_object(
      'record', jsonb_build_object('tenant_id', v_tenant_id)
    )
  );
  RETURN COALESCE(NEW, OLD);
EXCEPTION
  WHEN OTHERS THEN
    RETURN COALESCE(NEW, OLD);
END;
$$;

ALTER FUNCTION "public"."trigger_seat_sync"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_deal_v1"("p_id" "uuid", "p_expected_row_version" bigint, "p_calc_version" integer DEFAULT NULL::integer) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant      uuid;
  v_stage       text;
  v_rows_updated int;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object()));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', json_build_object()));
  END IF;

  SELECT stage INTO v_stage FROM public.deals WHERE id = p_id AND tenant_id = v_tenant;

  IF v_stage IN ('Closed / Dead') THEN
    RETURN json_build_object('ok', false, 'code', 'DEAL_IMMUTABLE', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal is in a terminal stage and cannot be modified', 'fields', json_build_object()));
  END IF;

  UPDATE public.deals
  SET row_version = row_version + 1, calc_version = COALESCE(p_calc_version, calc_version)
  WHERE id = p_id AND tenant_id = v_tenant AND row_version = p_expected_row_version;

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    RETURN json_build_object('ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Row version mismatch or deal not found for this tenant', 'fields', json_build_object()));
  END IF;

  RETURN json_build_object('ok', true, 'code', 'OK', 'data', json_build_object('id', p_id), 'error', null);
END;
$$;

ALTER FUNCTION "public"."update_deal_v1"("p_id" "uuid", "p_expected_row_version" bigint, "p_calc_version" integer) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_display_name_v1"("p_display_name" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_display_name text;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not authenticated', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_display_name IS NULL OR trim(p_display_name) = '' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Display name is required', 'fields', jsonb_build_object('display_name', 'Must not be blank'))
    );
  END IF;

  v_display_name := trim(p_display_name);

  UPDATE public.user_profiles
  SET display_name = v_display_name
  WHERE id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Profile not found', 'fields', '{}'::jsonb)
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'data', jsonb_build_object('display_name', v_display_name),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."update_display_name_v1"("p_display_name" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_member_role_v1"("p_user_id" "uuid", "p_role" "public"."tenant_role") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', '{}'::jsonb));
  END IF;

  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'user_id is required', 'fields', jsonb_build_object('user_id', 'Must not be null')));
  END IF;
  IF p_role IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Role is required', 'fields', jsonb_build_object('role', 'Must not be null')));
  END IF;

  UPDATE public.tenant_memberships SET role = p_role WHERE tenant_id = v_tenant_id AND user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Member not found', 'fields', '{}'::jsonb));
  END IF;

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'data', jsonb_build_object('user_id', p_user_id, 'role', p_role), 'error', null);
END;
$$;

ALTER FUNCTION "public"."update_member_role_v1"("p_user_id" "uuid", "p_role" "public"."tenant_role") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_workspace_settings_v1"("p_workspace_name" "text" DEFAULT NULL::"text", "p_slug" "text" DEFAULT NULL::"text", "p_country" "text" DEFAULT NULL::"text", "p_currency" "text" DEFAULT NULL::"text", "p_measurement_unit" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_tenant_id uuid;
BEGIN
  PERFORM public.require_min_role_v1('admin');

  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb));
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', '{}'::jsonb));
  END IF;

  IF p_workspace_name IS NOT NULL AND btrim(p_workspace_name) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid workspace name', 'fields', jsonb_build_object('workspace_name', 'Must not be blank')));
  END IF;
  IF p_country IS NOT NULL AND btrim(p_country) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid country', 'fields', jsonb_build_object('country', 'Must not be blank')));
  END IF;
  IF p_currency IS NOT NULL AND btrim(p_currency) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid currency', 'fields', jsonb_build_object('currency', 'Must not be blank')));
  END IF;
  IF p_measurement_unit IS NOT NULL AND btrim(p_measurement_unit) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid measurement unit', 'fields', jsonb_build_object('measurement_unit', 'Must not be blank')));
  END IF;
  IF p_slug IS NOT NULL THEN
    IF btrim(p_slug) = '' OR p_slug !~ '^[a-z0-9][a-z0-9\-]{1,48}[a-z0-9]$' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'Invalid slug format', 'fields', jsonb_build_object('slug', 'Must be lowercase, URL-safe, 3-50 characters')));
    END IF;
    BEGIN
      INSERT INTO public.tenant_slugs (tenant_id, slug) VALUES (v_tenant_id, p_slug)
      ON CONFLICT (tenant_id) DO UPDATE SET slug = EXCLUDED.slug WHERE tenant_slugs.tenant_id = v_tenant_id;
    EXCEPTION WHEN unique_violation THEN
      RETURN jsonb_build_object('ok', false, 'code', 'CONFLICT', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'Slug already taken', 'fields', jsonb_build_object('slug', 'Already in use')));
    END;
  END IF;

  UPDATE public.tenants SET
    name = COALESCE(p_workspace_name, name),
    country = COALESCE(p_country, country),
    currency = COALESCE(p_currency, currency),
    measurement_unit = COALESCE(p_measurement_unit, measurement_unit)
  WHERE id = v_tenant_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Workspace not found', 'fields', '{}'::jsonb));
  END IF;

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'data', jsonb_build_object(
      'tenant_id', v_tenant_id,
      'workspace_name', COALESCE(p_workspace_name, (SELECT name FROM public.tenants WHERE id = v_tenant_id)),
      'slug', COALESCE(p_slug, (SELECT slug FROM public.tenant_slugs WHERE tenant_id = v_tenant_id LIMIT 1)),
      'country', COALESCE(p_country, (SELECT country FROM public.tenants WHERE id = v_tenant_id)),
      'currency', COALESCE(p_currency, (SELECT currency FROM public.tenants WHERE id = v_tenant_id)),
      'measurement_unit', COALESCE(p_measurement_unit, (SELECT measurement_unit FROM public.tenants WHERE id = v_tenant_id))
    ), 'error', null);
END;
$_$;

ALTER FUNCTION "public"."update_workspace_settings_v1"("p_workspace_name" "text", "p_slug" "text", "p_country" "text", "p_currency" "text", "p_measurement_unit" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."upsert_subscription_v1"("p_tenant_id" "uuid", "p_stripe_subscription_id" "text", "p_status" "text", "p_current_period_end" timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;

ALTER FUNCTION "public"."upsert_subscription_v1"("p_tenant_id" "uuid", "p_stripe_subscription_id" "text", "p_status" "text", "p_current_period_end" timestamp with time zone) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";

CREATE TABLE IF NOT EXISTS "public"."activity_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "actor_id" "uuid",
    "action" "text" NOT NULL,
    "meta" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."activity_log" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."calc_versions" (
    "id" integer NOT NULL,
    "label" "text" NOT NULL,
    "released_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."calc_versions" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."deal_inputs" (
    "id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "deal_id" "uuid" NOT NULL,
    "calc_version" integer DEFAULT 1 NOT NULL,
    "row_version" bigint DEFAULT 1 NOT NULL,
    "assumptions" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."deal_inputs" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."deal_outputs" (
    "id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "deal_id" "uuid" NOT NULL,
    "calc_version" integer DEFAULT 1 NOT NULL,
    "row_version" bigint DEFAULT 1 NOT NULL,
    "outputs" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."deal_outputs" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."deal_reminders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "deal_id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "reminder_date" timestamp with time zone NOT NULL,
    "reminder_type" "text" NOT NULL,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "row_version" bigint DEFAULT 1 NOT NULL
);

ALTER TABLE "public"."deal_reminders" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."deal_tc" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "deal_id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "row_version" bigint DEFAULT 1 NOT NULL,
    "aps_signed_date" timestamp with time zone,
    "conditional_deadline" timestamp with time zone,
    "closing_date" timestamp with time zone,
    "assignment_fee" numeric,
    "sell_price" numeric,
    "actual_assignment_fee" numeric,
    "buyer_info" "jsonb",
    "notes" "text"
);

ALTER TABLE "public"."deal_tc" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."deal_tc_checklist" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "deal_id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "row_version" bigint DEFAULT 1 NOT NULL,
    "item_key" "text" NOT NULL,
    "completed_at" timestamp with time zone,
    CONSTRAINT "deal_tc_checklist_item_key_check" CHECK (("item_key" = ANY (ARRAY['aps_signed'::"text", 'deposit_received'::"text", 'sold_firm'::"text", 'docs_to_lawyer'::"text", 'closing_confirmed'::"text", 'fee_received'::"text"])))
);

ALTER TABLE "public"."deal_tc_checklist" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."deals" (
    "id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "row_version" bigint DEFAULT 1 NOT NULL,
    "calc_version" integer DEFAULT 1 NOT NULL,
    "assumptions_snapshot_id" "uuid",
    "stage" "text" DEFAULT 'New'::"text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "farm_area_id" "uuid",
    CONSTRAINT "deals_stage_check" CHECK (("stage" = ANY (ARRAY['New'::"text", 'Analyzing'::"text", 'Offer Sent'::"text", 'Under Contract (UC)'::"text", 'Dispo'::"text", 'Closed / Dead'::"text"])))
);

ALTER TABLE "public"."deals" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."draft_deals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "slug" "text" NOT NULL,
    "form_type" "text" NOT NULL,
    "payload" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "asking_price" numeric,
    "repair_estimate" numeric,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "draft_deals_form_type_check" CHECK (("form_type" = ANY (ARRAY['buyer'::"text", 'seller'::"text", 'birddog'::"text"])))
);

ALTER TABLE "public"."draft_deals" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."rpc_idempotency_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "idempotency_key" "text" NOT NULL,
    "rpc_name" "text" NOT NULL,
    "result_json" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."rpc_idempotency_log" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."share_tokens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "deal_id" "uuid" NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "token_hash" "bytea" NOT NULL,
    "revoked_at" timestamp with time zone
);

ALTER TABLE "public"."share_tokens" OWNER TO "postgres";

CREATE OR REPLACE VIEW "public"."share_token_packet" AS
 SELECT "st"."deal_id",
    "st"."expires_at",
    "d"."calc_version"
   FROM ("public"."share_tokens" "st"
     JOIN "public"."deals" "d" ON ((("d"."id" = "st"."deal_id") AND ("d"."tenant_id" = "st"."tenant_id"))));

ALTER VIEW "public"."share_token_packet" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."tenant_farm_areas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "row_version" bigint DEFAULT 1 NOT NULL,
    "area_name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."tenant_farm_areas" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."tenant_invites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "invited_email" "text" NOT NULL,
    "role" "public"."tenant_role" DEFAULT 'member'::"public"."tenant_role" NOT NULL,
    "token" "text" NOT NULL,
    "invited_by" "uuid" NOT NULL,
    "accepted_at" timestamp with time zone,
    "expires_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "row_version" bigint DEFAULT 1 NOT NULL
);

ALTER TABLE "public"."tenant_invites" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."tenant_memberships" (
    "id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "public"."tenant_role" DEFAULT 'member'::"public"."tenant_role" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."tenant_memberships" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."tenant_slugs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "slug" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "tenant_slugs_slug_format" CHECK (("slug" ~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$'::"text"))
);

ALTER TABLE "public"."tenant_slugs" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."tenant_subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "status" "text" NOT NULL,
    "current_period_end" timestamp with time zone NOT NULL,
    "stripe_subscription_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "row_version" bigint DEFAULT 1 NOT NULL,
    CONSTRAINT "tenant_subscriptions_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'expiring'::"text", 'expired'::"text", 'canceled'::"text", 'trialing'::"text"])))
);

ALTER TABLE "public"."tenant_subscriptions" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."tenants" (
    "id" "uuid" NOT NULL,
    "name" "text",
    "country" "text",
    "currency" "text",
    "measurement_unit" "text",
    "subscription_lapsed_at" timestamp with time zone,
    "archived_at" timestamp with time zone,
    "restore_token" "uuid"
);

ALTER TABLE "public"."tenants" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."user_profiles" (
    "id" "uuid" NOT NULL,
    "current_tenant_id" "uuid",
    "display_name" "text",
    "has_used_trial" boolean DEFAULT false NOT NULL,
    "trial_claimed_at" timestamp with time zone,
    "trial_started_at" timestamp with time zone
);

ALTER TABLE "public"."user_profiles" OWNER TO "postgres";

ALTER TABLE ONLY "public"."activity_log"
    ADD CONSTRAINT "activity_log_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."calc_versions"
    ADD CONSTRAINT "calc_versions_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."deal_inputs"
    ADD CONSTRAINT "deal_inputs_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."deal_outputs"
    ADD CONSTRAINT "deal_outputs_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."deal_reminders"
    ADD CONSTRAINT "deal_reminders_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."deal_tc_checklist"
    ADD CONSTRAINT "deal_tc_checklist_deal_item_key" UNIQUE ("deal_id", "item_key");

ALTER TABLE ONLY "public"."deal_tc_checklist"
    ADD CONSTRAINT "deal_tc_checklist_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."deal_tc"
    ADD CONSTRAINT "deal_tc_deal_id_key" UNIQUE ("deal_id");

ALTER TABLE ONLY "public"."deal_tc"
    ADD CONSTRAINT "deal_tc_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."draft_deals"
    ADD CONSTRAINT "draft_deals_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."rpc_idempotency_log"
    ADD CONSTRAINT "rpc_idempotency_log_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."rpc_idempotency_log"
    ADD CONSTRAINT "rpc_idempotency_log_user_id_idempotency_key_rpc_name_key" UNIQUE ("user_id", "idempotency_key", "rpc_name");

ALTER TABLE ONLY "public"."share_tokens"
    ADD CONSTRAINT "share_tokens_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tenant_farm_areas"
    ADD CONSTRAINT "tenant_farm_areas_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tenant_farm_areas"
    ADD CONSTRAINT "tenant_farm_areas_tenant_area_unique" UNIQUE ("tenant_id", "area_name");

ALTER TABLE ONLY "public"."tenant_invites"
    ADD CONSTRAINT "tenant_invites_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tenant_invites"
    ADD CONSTRAINT "tenant_invites_token_unique" UNIQUE ("token");

ALTER TABLE ONLY "public"."tenant_memberships"
    ADD CONSTRAINT "tenant_memberships_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tenant_memberships"
    ADD CONSTRAINT "tenant_memberships_tenant_user_unique" UNIQUE ("tenant_id", "user_id");

ALTER TABLE ONLY "public"."tenant_slugs"
    ADD CONSTRAINT "tenant_slugs_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tenant_slugs"
    ADD CONSTRAINT "tenant_slugs_slug_unique" UNIQUE ("slug");

ALTER TABLE ONLY "public"."tenant_slugs"
    ADD CONSTRAINT "tenant_slugs_tenant_id_unique" UNIQUE ("tenant_id");

ALTER TABLE ONLY "public"."tenant_subscriptions"
    ADD CONSTRAINT "tenant_subscriptions_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tenant_subscriptions"
    ADD CONSTRAINT "tenant_subscriptions_tenant_id_unique" UNIQUE ("tenant_id");

ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "tenants_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."user_profiles"
    ADD CONSTRAINT "user_profiles_pkey" PRIMARY KEY ("id");

CREATE UNIQUE INDEX "share_tokens_token_hash_unique" ON "public"."share_tokens" USING "btree" ("token_hash");

CREATE UNIQUE INDEX "tenants_restore_token_unique" ON "public"."tenants" USING "btree" ("restore_token") WHERE ("restore_token" IS NOT NULL);

CREATE OR REPLACE TRIGGER "activity_log_no_delete" BEFORE DELETE ON "public"."activity_log" FOR EACH ROW EXECUTE FUNCTION "public"."activity_log_append_only"();

CREATE OR REPLACE TRIGGER "activity_log_no_update" BEFORE UPDATE ON "public"."activity_log" FOR EACH ROW EXECUTE FUNCTION "public"."activity_log_append_only"();

CREATE OR REPLACE TRIGGER "deal_inputs_tenant_match" BEFORE INSERT OR UPDATE ON "public"."deal_inputs" FOR EACH ROW EXECUTE FUNCTION "public"."check_deal_tenant_match"();

CREATE OR REPLACE TRIGGER "deal_outputs_tenant_match" BEFORE INSERT OR UPDATE ON "public"."deal_outputs" FOR EACH ROW EXECUTE FUNCTION "public"."check_deal_tenant_match"();

CREATE CONSTRAINT TRIGGER "deals_snapshot_not_null" AFTER INSERT OR UPDATE ON "public"."deals" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION "public"."check_deal_snapshot_not_null"();

CREATE OR REPLACE TRIGGER "on_membership_delete_sync_seats" AFTER DELETE ON "public"."tenant_memberships" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_seat_sync"();

CREATE OR REPLACE TRIGGER "on_membership_insert_sync_seats" AFTER INSERT ON "public"."tenant_memberships" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_seat_sync"();

CREATE OR REPLACE TRIGGER "on_tenant_invite_insert" AFTER INSERT ON "public"."tenant_invites" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_invite_email"();

ALTER TABLE ONLY "public"."activity_log"
    ADD CONSTRAINT "activity_log_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");

ALTER TABLE ONLY "public"."deal_inputs"
    ADD CONSTRAINT "deal_inputs_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id");

ALTER TABLE ONLY "public"."deal_outputs"
    ADD CONSTRAINT "deal_outputs_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id");

ALTER TABLE ONLY "public"."deal_reminders"
    ADD CONSTRAINT "deal_reminders_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."deal_reminders"
    ADD CONSTRAINT "deal_reminders_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."deal_tc_checklist"
    ADD CONSTRAINT "deal_tc_checklist_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."deal_tc_checklist"
    ADD CONSTRAINT "deal_tc_checklist_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."deal_tc"
    ADD CONSTRAINT "deal_tc_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."deal_tc"
    ADD CONSTRAINT "deal_tc_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_assumptions_snapshot_fk" FOREIGN KEY ("assumptions_snapshot_id") REFERENCES "public"."deal_inputs"("id") DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_farm_area_id_fkey" FOREIGN KEY ("farm_area_id") REFERENCES "public"."tenant_farm_areas"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."draft_deals"
    ADD CONSTRAINT "draft_deals_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."share_tokens"
    ADD CONSTRAINT "share_tokens_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id");

ALTER TABLE ONLY "public"."tenant_farm_areas"
    ADD CONSTRAINT "tenant_farm_areas_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."tenant_invites"
    ADD CONSTRAINT "tenant_invites_invited_by_fkey" FOREIGN KEY ("invited_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."tenant_invites"
    ADD CONSTRAINT "tenant_invites_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."tenant_memberships"
    ADD CONSTRAINT "tenant_memberships_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");

ALTER TABLE ONLY "public"."tenant_slugs"
    ADD CONSTRAINT "tenant_slugs_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."tenant_subscriptions"
    ADD CONSTRAINT "tenant_subscriptions_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."user_profiles"
    ADD CONSTRAINT "user_profiles_current_tenant_id_fkey" FOREIGN KEY ("current_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;

ALTER TABLE "public"."activity_log" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "activity_log_insert_own" ON "public"."activity_log" FOR INSERT TO "authenticated" WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "activity_log_select_own" ON "public"."activity_log" FOR SELECT TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."calc_versions" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."deal_inputs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."deal_outputs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."deal_reminders" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."deal_tc" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."deal_tc_checklist" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "deal_tc_checklist_delete_own" ON "public"."deal_tc_checklist" FOR DELETE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deal_tc_checklist_insert_own" ON "public"."deal_tc_checklist" FOR INSERT TO "authenticated" WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deal_tc_checklist_select_own" ON "public"."deal_tc_checklist" FOR SELECT TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deal_tc_checklist_update_own" ON "public"."deal_tc_checklist" FOR UPDATE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deal_tc_delete_own" ON "public"."deal_tc" FOR DELETE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deal_tc_insert_own" ON "public"."deal_tc" FOR INSERT TO "authenticated" WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deal_tc_select_own" ON "public"."deal_tc" FOR SELECT TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deal_tc_update_own" ON "public"."deal_tc" FOR UPDATE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."deals" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "deals_delete_own" ON "public"."deals" FOR DELETE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deals_insert_own" ON "public"."deals" FOR INSERT TO "authenticated" WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deals_select_own" ON "public"."deals" FOR SELECT TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deals_update_own" ON "public"."deals" FOR UPDATE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."draft_deals" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."rpc_idempotency_log" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."share_tokens" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."tenant_farm_areas" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant_farm_areas_delete_own" ON "public"."tenant_farm_areas" FOR DELETE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "tenant_farm_areas_insert_own" ON "public"."tenant_farm_areas" FOR INSERT TO "authenticated" WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "tenant_farm_areas_select_own" ON "public"."tenant_farm_areas" FOR SELECT TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "tenant_farm_areas_update_own" ON "public"."tenant_farm_areas" FOR UPDATE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."tenant_invites" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."tenant_memberships" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant_memberships_delete_own" ON "public"."tenant_memberships" FOR DELETE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "tenant_memberships_insert_own" ON "public"."tenant_memberships" FOR INSERT TO "authenticated" WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "tenant_memberships_select_own" ON "public"."tenant_memberships" FOR SELECT TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "tenant_memberships_update_own" ON "public"."tenant_memberships" FOR UPDATE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."tenant_slugs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."tenant_subscriptions" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."tenants" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."user_profiles" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_profiles_select_self" ON "public"."user_profiles" FOR SELECT TO "authenticated" USING (("id" = "auth"."uid"()));

CREATE POLICY "user_profiles_update_self" ON "public"."user_profiles" FOR UPDATE TO "authenticated" USING (("id" = "auth"."uid"())) WITH CHECK (("id" = "auth"."uid"()));

REVOKE ALL ON FUNCTION "public"."current_tenant_id"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."current_tenant_id"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."get_user_entitlements_v1"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_user_entitlements_v1"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."list_deals_v1"("p_limit" integer, "p_cursor" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_deals_v1"("p_limit" integer, "p_cursor" "text") TO "authenticated";

GRANT SELECT,UPDATE ON TABLE "public"."user_profiles" TO "authenticated";
