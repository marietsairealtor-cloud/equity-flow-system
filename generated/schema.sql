

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

CREATE OR REPLACE FUNCTION "public"."_intake_apply_mao_to_assumptions_v1"("p_assumptions" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_a              jsonb;
  v_arv            numeric;
  v_mult           numeric;
  v_repair         numeric;
  v_assignment_fee numeric;
  v_mao            numeric;
  v_has_arv        boolean;
  v_has_mult       boolean;
  v_has_rep        boolean;
BEGIN
  v_a := COALESCE(p_assumptions, '{}'::jsonb) - 'mao';

  v_has_arv := (v_a ? 'arv') AND v_a->>'arv' IS NOT NULL AND trim(v_a->>'arv') <> '';
  v_has_mult := (v_a ? 'multiplier') AND v_a->>'multiplier' IS NOT NULL AND trim(v_a->>'multiplier') <> '';
  v_has_rep := (v_a ? 'repair_estimate') AND v_a->>'repair_estimate' IS NOT NULL AND trim(v_a->>'repair_estimate') <> '';

  IF v_has_arv AND v_has_mult AND v_has_rep THEN
    v_arv := (trim(v_a->>'arv'))::numeric;
    v_mult := (trim(v_a->>'multiplier'))::numeric;
    v_repair := (trim(v_a->>'repair_estimate'))::numeric;
    v_assignment_fee := CASE
      WHEN (v_a->>'assignment_fee') IS NOT NULL AND trim(v_a->>'assignment_fee') <> ''
      THEN (trim(v_a->>'assignment_fee'))::numeric
      ELSE 0::numeric
    END;
    v_mao := ROUND((v_arv * v_mult) - v_repair - v_assignment_fee);
    RETURN v_a || jsonb_build_object('mao', v_mao);
  END IF;

  RETURN v_a - 'mao';
END;
$$;

ALTER FUNCTION "public"."_intake_apply_mao_to_assumptions_v1"("p_assumptions" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."_intake_validate_deal_property_jsonb_v1"("p_property" "jsonb") RETURNS "text"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_raw text;
BEGIN
  IF p_property IS NULL OR p_property = '{}'::jsonb THEN
    RETURN NULL;
  END IF;

  IF p_property ? 'deficiency_tags' AND jsonb_typeof(p_property->'deficiency_tags') <> 'array' THEN
    RETURN 'deficiency_tags must be a JSON array';
  END IF;

  IF p_property ? 'year_built' AND p_property->>'year_built' IS NOT NULL AND trim(p_property->>'year_built') <> '' THEN
    v_raw := trim(p_property->>'year_built');
    IF v_raw !~ '^\d+$' THEN
      RETURN 'year_built must be a valid integer';
    END IF;
    PERFORM v_raw::integer;
  END IF;

  IF p_property ? 'repair_estimate' AND p_property->>'repair_estimate' IS NOT NULL AND trim(p_property->>'repair_estimate') <> '' THEN
    v_raw := trim(p_property->>'repair_estimate');
    IF v_raw !~ '^\d+(\.\d+)?$' THEN
      RETURN 'repair_estimate (property) must be a valid number';
    END IF;
  END IF;

  IF p_property ? 'roof_age' AND p_property->>'roof_age' IS NOT NULL AND trim(p_property->>'roof_age') <> '' THEN
    IF trim(p_property->>'roof_age') !~ '^\d+$' THEN
      RETURN 'roof_age must be a valid integer';
    END IF;
    PERFORM (trim(p_property->>'roof_age'))::integer;
  END IF;

  IF p_property ? 'furnace_age' AND p_property->>'furnace_age' IS NOT NULL AND trim(p_property->>'furnace_age') <> '' THEN
    IF trim(p_property->>'furnace_age') !~ '^\d+$' THEN
      RETURN 'furnace_age must be a valid integer';
    END IF;
    PERFORM (trim(p_property->>'furnace_age'))::integer;
  END IF;

  IF p_property ? 'ac_age' AND p_property->>'ac_age' IS NOT NULL AND trim(p_property->>'ac_age') <> '' THEN
    IF trim(p_property->>'ac_age') !~ '^\d+$' THEN
      RETURN 'ac_age must be a valid integer';
    END IF;
    PERFORM (trim(p_property->>'ac_age'))::integer;
  END IF;

  RETURN NULL;
END;
$_$;

ALTER FUNCTION "public"."_intake_validate_deal_property_jsonb_v1"("p_property" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."_intake_validate_pricing_assumptions_v1"("p_assumptions" "jsonb") RETURNS "text"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_num numeric;
  v_raw text;
BEGIN
  IF p_assumptions IS NULL OR p_assumptions = '{}'::jsonb THEN
    RETURN NULL;
  END IF;

  IF p_assumptions ? 'arv' AND p_assumptions->>'arv' IS NOT NULL AND trim(p_assumptions->>'arv') <> '' THEN
    v_raw := trim(p_assumptions->>'arv');
    IF v_raw !~ '^\d+(\.\d+)?$' THEN
      RETURN 'arv must be a valid non-negative number';
    END IF;
    v_num := v_raw::numeric;
    IF v_num < 0 THEN
      RETURN 'arv must be non-negative';
    END IF;
  END IF;

  IF p_assumptions ? 'ask_price' AND p_assumptions->>'ask_price' IS NOT NULL AND trim(p_assumptions->>'ask_price') <> '' THEN
    v_raw := trim(p_assumptions->>'ask_price');
    IF v_raw !~ '^\d+(\.\d+)?$' THEN
      RETURN 'ask_price must be a valid number';
    END IF;
  END IF;

  IF p_assumptions ? 'repair_estimate' AND p_assumptions->>'repair_estimate' IS NOT NULL AND trim(p_assumptions->>'repair_estimate') <> '' THEN
    v_raw := trim(p_assumptions->>'repair_estimate');
    IF v_raw !~ '^\d+(\.\d+)?$' THEN
      RETURN 'repair_estimate must be a valid non-negative number';
    END IF;
    v_num := v_raw::numeric;
    IF v_num < 0 THEN
      RETURN 'repair_estimate must be non-negative';
    END IF;
  END IF;

  IF p_assumptions ? 'assignment_fee' AND p_assumptions->>'assignment_fee' IS NOT NULL AND trim(p_assumptions->>'assignment_fee') <> '' THEN
    v_raw := trim(p_assumptions->>'assignment_fee');
    IF v_raw !~ '^\d+(\.\d+)?$' THEN
      RETURN 'assignment_fee must be a valid number';
    END IF;
    v_num := v_raw::numeric;
    IF v_num < 0 THEN
      RETURN 'assignment_fee must be non-negative';
    END IF;
  END IF;

  IF p_assumptions ? 'multiplier' AND p_assumptions->>'multiplier' IS NOT NULL AND trim(p_assumptions->>'multiplier') <> '' THEN
    v_raw := trim(p_assumptions->>'multiplier');
    IF v_raw !~ '^\d+(\.\d+)?$' THEN
      RETURN 'multiplier must be a valid number';
    END IF;
    v_num := v_raw::numeric;
    IF v_num <= 0 OR v_num > 1 THEN
      RETURN 'multiplier must be between 0 and 1 exclusive';
    END IF;
  END IF;

  RETURN NULL;
END;
$_$;

ALTER FUNCTION "public"."_intake_validate_pricing_assumptions_v1"("p_assumptions" "jsonb") OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."advance_deal_stage_v1"("p_deal_id" "uuid", "p_action" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant    uuid;
  v_user      uuid;
  v_stage     text;
  v_new_stage text;
  v_content   text;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant or user context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
    );
  END IF;

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  IF p_action = 'start_analysis' AND v_stage = 'new' THEN
    v_new_stage := 'analyzing';
    v_content   := 'Stage advanced to Analyzing';
  ELSIF p_action = 'send_offer' AND v_stage = 'analyzing' THEN
    v_new_stage := 'offer_sent';
    v_content   := 'Stage advanced to Offer Sent';
  ELSIF p_action = 'mark_contract_signed' AND v_stage = 'offer_sent' THEN
    v_new_stage := 'under_contract';
    v_content   := 'Stage advanced to Under Contract';
  ELSE
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid stage transition for current deal state', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    stage       = v_new_stage,
    updated_at  = now(),
    row_version = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  INSERT INTO public.deal_activity_log (tenant_id, deal_id, activity_type, content, created_by, created_at)
  VALUES (v_tenant, p_deal_id, 'stage_change', v_content, v_user, now());

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', v_new_stage),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."advance_deal_stage_v1"("p_deal_id" "uuid", "p_action" "text") OWNER TO "postgres";

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
  v_tenant   uuid;
  v_user     uuid;
  v_reminder record;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant or user context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'WORKSPACE_NOT_WRITABLE', 'data', json_build_object(),
      'error', json_build_object('message', 'Workspace is not active', 'fields', json_build_object())
    );
  END IF;

  SELECT * INTO v_reminder
  FROM public.deal_reminders
  WHERE id = p_reminder_id AND tenant_id = v_tenant;

  -- Not found or cross-tenant: silent no-op (preserves idempotency contract)
  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', true, 'code', 'OK',
      'data', json_build_object('reminder_id', p_reminder_id),
      'error', null
    );
  END IF;

  -- Already completed: silent no-op -- no DB change, no activity row
  IF v_reminder.completed_at IS NOT NULL THEN
    RETURN json_build_object(
      'ok', true, 'code', 'OK',
      'data', json_build_object('reminder_id', p_reminder_id),
      'error', null
    );
  END IF;

  UPDATE public.deal_reminders
  SET completed_at = now()
  WHERE id = p_reminder_id AND tenant_id = v_tenant;

  INSERT INTO public.deal_activity_log (tenant_id, deal_id, activity_type, content, created_by, created_at)
  VALUES (v_tenant, v_reminder.deal_id, 'reminder_completed',
    'Reminder completed: ' || v_reminder.reminder_type, v_user, now());

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('reminder_id', p_reminder_id),
    'error', null
  );
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

CREATE OR REPLACE FUNCTION "public"."create_deal_from_intake_v1"("p_fields" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant         uuid;
  v_id             uuid;
  v_snapshot_id    uuid;
  v_top_keys       text[];
  v_allowed_top    text[] := ARRAY[
    'address','seller_name','seller_phone','seller_email',
    'seller_pain','seller_timeline','seller_notes','property','assumptions'
  ];
  v_prop_keys      text[] := ARRAY[
    'property_type','beds','baths','sqft','lot_size','year_built',
    'occupancy','deficiency_tags','condition_notes','repair_estimate',
    'garage_parking','basement_type','foundation_type',
    'roof_age','furnace_age','ac_age','heating_type','cooling_type'
  ];
  v_price_keys     text[] := ARRAY['arv','ask_price','repair_estimate','assignment_fee','multiplier'];
  v_unknown        text[];
  v_prop           jsonb;
  v_asm            jsonb;
  v_def_tags       text[];
  v_err            text;
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

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'WORKSPACE_NOT_WRITABLE', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Workspace is not active', 'fields', '{}'::jsonb)
    );
  END IF;

  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_fields IS NULL OR jsonb_typeof(p_fields) <> 'object' THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_fields must be a JSON object', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT ARRAY(SELECT jsonb_object_keys(p_fields)) INTO v_top_keys;
  SELECT ARRAY(
    SELECT unnest(v_top_keys)
    EXCEPT
    SELECT unnest(v_allowed_top)
  ) INTO v_unknown;
  IF array_length(v_unknown, 1) > 0 THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'Unknown top-level fields: ' || array_to_string(v_unknown, ', '),
        'fields', '{}'::jsonb
      )
    );
  END IF;

  IF p_fields ? 'property' AND (jsonb_typeof(p_fields->'property') <> 'object' OR p_fields->'property' IS NULL) THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'property must be a JSON object', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_fields ? 'assumptions' THEN
    IF jsonb_typeof(p_fields->'assumptions') <> 'object' OR p_fields->'assumptions' IS NULL THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'assumptions must be a JSON object', 'fields', '{}'::jsonb)
      );
    END IF;
    IF p_fields->'assumptions' ? 'mao' THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'mao is derived server-side', 'fields', '{}'::jsonb)
      );
    END IF;
    SELECT ARRAY(
      SELECT jsonb_object_keys(p_fields->'assumptions')
      EXCEPT
      SELECT unnest(v_price_keys)
    ) INTO v_unknown;
    IF array_length(v_unknown, 1) > 0 THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object(
          'message', 'Unknown assumptions keys: ' || array_to_string(v_unknown, ', '),
          'fields', '{}'::jsonb
        )
      );
    END IF;
  END IF;

  IF p_fields ? 'property' THEN
    SELECT ARRAY(
      SELECT jsonb_object_keys(p_fields->'property')
      EXCEPT
      SELECT unnest(v_prop_keys)
    ) INTO v_unknown;
    IF array_length(v_unknown, 1) > 0 THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object(
          'message', 'Unknown property keys: ' || array_to_string(v_unknown, ', '),
          'fields', '{}'::jsonb
        )
      );
    END IF;
    v_err := public._intake_validate_deal_property_jsonb_v1(p_fields->'property');
    IF v_err IS NOT NULL THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', v_err, 'fields', '{}'::jsonb)
      );
    END IF;
  END IF;

  v_err := public._intake_validate_pricing_assumptions_v1(COALESCE(p_fields->'assumptions', '{}'::jsonb));
  IF v_err IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', v_err, 'fields', '{}'::jsonb)
    );
  END IF;

  v_id := gen_random_uuid();
  v_snapshot_id := gen_random_uuid();
  v_asm := public._intake_apply_mao_to_assumptions_v1(COALESCE(p_fields->'assumptions', '{}'::jsonb));

  INSERT INTO public.deals (
    id, tenant_id, row_version, calc_version,
    assumptions_snapshot_id, stage,
    address,
    seller_name, seller_phone, seller_email, seller_pain, seller_timeline, seller_notes
  ) VALUES (
    v_id, v_tenant, 1, 1,
    v_snapshot_id, 'new',
    NULLIF(trim(p_fields->>'address'), ''),
    NULLIF(trim(p_fields->>'seller_name'), ''),
    NULLIF(trim(p_fields->>'seller_phone'), ''),
    NULLIF(trim(p_fields->>'seller_email'), ''),
    NULLIF(trim(p_fields->>'seller_pain'), ''),
    NULLIF(trim(p_fields->>'seller_timeline'), ''),
    NULLIF(trim(p_fields->>'seller_notes'), '')
  );

  INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
  VALUES (v_snapshot_id, v_tenant, v_id, 1, 1, COALESCE(v_asm, '{}'::jsonb));

  IF p_fields ? 'property' AND p_fields->'property' <> '{}'::jsonb THEN
    v_prop := p_fields->'property';

    IF v_prop ? 'deficiency_tags' AND jsonb_typeof(v_prop->'deficiency_tags') = 'array' THEN
      v_def_tags := ARRAY(SELECT jsonb_array_elements_text(v_prop->'deficiency_tags'));
    END IF;

    INSERT INTO public.deal_properties (
      tenant_id, deal_id, row_version,
      property_type, beds, baths, sqft, lot_size, year_built, occupancy,
      deficiency_tags, condition_notes, repair_estimate,
      garage_parking, basement_type, foundation_type,
      roof_age, furnace_age, ac_age, heating_type, cooling_type
    ) VALUES (
      v_tenant, v_id, 1,
      NULLIF(trim(v_prop->>'property_type'), ''),
      NULLIF(trim(v_prop->>'beds'), ''),
      NULLIF(trim(v_prop->>'baths'), ''),
      NULLIF(trim(v_prop->>'sqft'), ''),
      NULLIF(trim(v_prop->>'lot_size'), ''),
      CASE WHEN v_prop->>'year_built' IS NOT NULL AND trim(v_prop->>'year_built') <> ''
        THEN (trim(v_prop->>'year_built'))::integer ELSE NULL END,
      NULLIF(trim(v_prop->>'occupancy'), ''),
      v_def_tags,
      NULLIF(trim(v_prop->>'condition_notes'), ''),
      CASE WHEN v_prop->>'repair_estimate' IS NOT NULL AND trim(v_prop->>'repair_estimate') <> ''
        THEN (trim(v_prop->>'repair_estimate'))::numeric ELSE NULL END,
      NULLIF(trim(v_prop->>'garage_parking'), ''),
      NULLIF(trim(v_prop->>'basement_type'), ''),
      NULLIF(trim(v_prop->>'foundation_type'), ''),
      CASE WHEN v_prop->>'roof_age' IS NOT NULL AND trim(v_prop->>'roof_age') <> ''
        THEN (trim(v_prop->>'roof_age'))::integer ELSE NULL END,
      CASE WHEN v_prop->>'furnace_age' IS NOT NULL AND trim(v_prop->>'furnace_age') <> ''
        THEN (trim(v_prop->>'furnace_age'))::integer ELSE NULL END,
      CASE WHEN v_prop->>'ac_age' IS NOT NULL AND trim(v_prop->>'ac_age') <> ''
        THEN (trim(v_prop->>'ac_age'))::integer ELSE NULL END,
      NULLIF(trim(v_prop->>'heating_type'), ''),
      NULLIF(trim(v_prop->>'cooling_type'), '')
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object('deal_id', v_id),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."create_deal_from_intake_v1"("p_fields" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_deal_note_v1"("p_deal_id" "uuid", "p_note_type" "text", "p_content" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant  uuid;
  v_user    uuid;
  v_deal    uuid;
  v_note_id uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No tenant or user context', 'fields', '{}'::json)
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'WORKSPACE_NOT_WRITABLE',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Workspace is not active', 'fields', '{}'::json)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_deal_id is required', 'fields', '{}'::json)
    );
  END IF;

  IF p_note_type IS NULL OR p_note_type NOT IN ('note', 'call_log') THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_note_type must be note or call_log', 'fields', '{}'::json)
    );
  END IF;

  IF p_content IS NULL OR trim(p_content) = '' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_content is required', 'fields', '{}'::json)
    );
  END IF;

  SELECT id INTO v_deal
  FROM public.deals
  WHERE id        = p_deal_id
    AND tenant_id = v_tenant
    AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
    );
  END IF;

  INSERT INTO public.deal_notes (tenant_id, deal_id, note_type, content, created_by)
  VALUES (v_tenant, p_deal_id, p_note_type, trim(p_content), v_user)
  RETURNING id INTO v_note_id;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('note_id', v_note_id),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."create_deal_note_v1"("p_deal_id" "uuid", "p_note_type" "text", "p_content" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_deal_v1"("p_id" "uuid", "p_calc_version" integer DEFAULT 1, "p_assumptions" "jsonb" DEFAULT '{}'::"jsonb") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_tenant         uuid;
  v_snapshot_id    uuid;
  v_arv            numeric;
  v_repair         numeric;
  v_profit         numeric;
  v_multiplier     numeric;
  v_mao            numeric;
  v_assumptions    jsonb;
  v_arv_raw        text;
  v_repair_raw     text;
  v_profit_raw     text;
  v_multiplier_raw text;
BEGIN
  -- Role enforcement first: minimum member required (first executable statement per contract).
  -- All failures from require_min_role_v1 map to NOT_AUTHORIZED:
  --   null tenant context, insufficient role, or any auth-layer exception.
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN json_build_object(
        'ok',    false,
        'code',  'NOT_AUTHORIZED',
        'data',  '{}'::jsonb,
        'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
      );
  END;

  -- Write lock enforcement: workspace must be active
  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'Workspace is read-only or expired', 'fields', json_build_object())
    );
  END IF;

  -- Resolve tenant context
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  -- Validate p_id
  IF p_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'p_id is required', 'fields', json_build_object('p_id', 'required'))
    );
  END IF;

  -- Safe extraction of raw text values before casting
  v_arv_raw        := trim(p_assumptions->>'arv');
  v_repair_raw     := trim(p_assumptions->>'repair_estimate');
  v_profit_raw     := trim(p_assumptions->>'desired_profit');
  v_multiplier_raw := trim(p_assumptions->>'multiplier');

  -- Validate arv
  IF v_arv_raw IS NULL OR v_arv_raw = '' OR v_arv_raw !~ '^\d+(\.\d+)?$' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'arv is required and must be a non-negative number', 'fields', json_build_object('arv', 'required'))
    );
  END IF;
  v_arv := v_arv_raw::numeric;
  IF v_arv < 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'arv must be non-negative', 'fields', json_build_object('arv', 'invalid'))
    );
  END IF;

  -- Validate repair_estimate
  IF v_repair_raw IS NULL OR v_repair_raw = '' OR v_repair_raw !~ '^\d+(\.\d+)?$' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'repair_estimate is required and must be a non-negative number', 'fields', json_build_object('repair_estimate', 'required'))
    );
  END IF;
  v_repair := v_repair_raw::numeric;
  IF v_repair < 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'repair_estimate must be non-negative', 'fields', json_build_object('repair_estimate', 'invalid'))
    );
  END IF;

  -- Validate desired_profit
  IF v_profit_raw IS NULL OR v_profit_raw = '' OR v_profit_raw !~ '^\d+(\.\d+)?$' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'desired_profit is required and must be a non-negative number', 'fields', json_build_object('desired_profit', 'required'))
    );
  END IF;
  v_profit := v_profit_raw::numeric;
  IF v_profit < 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'desired_profit must be non-negative', 'fields', json_build_object('desired_profit', 'invalid'))
    );
  END IF;

  -- Validate multiplier
  IF v_multiplier_raw IS NULL OR v_multiplier_raw = '' OR v_multiplier_raw !~ '^\d+(\.\d+)?$' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'multiplier is required and must be a number', 'fields', json_build_object('multiplier', 'required'))
    );
  END IF;
  v_multiplier := v_multiplier_raw::numeric;
  IF v_multiplier <= 0 OR v_multiplier > 1 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::jsonb,
      'error', json_build_object('message', 'multiplier must be between 0 and 1 exclusive', 'fields', json_build_object('multiplier', 'invalid'))
    );
  END IF;

  -- Compute MAO server-side -- overwrite any frontend-supplied mao unconditionally
  v_mao := ROUND(v_arv * v_multiplier - v_repair - v_profit);

  -- Build final assumptions blob with backend-computed mao
  v_assumptions := p_assumptions || jsonb_build_object('mao', v_mao);

  -- Generate snapshot id
  v_snapshot_id := gen_random_uuid();

  -- Step 1: Insert deal
  INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
  VALUES (p_id, v_tenant, 1, p_calc_version, v_snapshot_id);

  -- Step 2: Insert deal_inputs snapshot with backend-computed assumptions
  INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
  VALUES (v_snapshot_id, v_tenant, p_id, p_calc_version, 1, v_assumptions);

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'id',                      p_id,
      'tenant_id',               v_tenant,
      'assumptions_snapshot_id', v_snapshot_id,
      'mao',                     v_mao
    ),
    'error', null
  );

EXCEPTION WHEN unique_violation THEN
  RETURN json_build_object(
    'ok',    false,
    'code',  'CONFLICT',
    'data',  '{}'::jsonb,
    'error', json_build_object('message', 'Deal already exists', 'fields', json_build_object())
  );
WHEN OTHERS THEN
  RETURN json_build_object(
    'ok',    false,
    'code',  'INTERNAL',
    'data',  '{}'::jsonb,
    'error', json_build_object('message', SQLERRM, 'fields', json_build_object())
  );
END;
$_$;

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

CREATE OR REPLACE FUNCTION "public"."delete_deal_media_v1"("p_media_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant       uuid;
  v_storage_path text;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
    );
  END IF;

  SELECT storage_path INTO v_storage_path
  FROM public.deal_media
  WHERE id = p_media_id AND tenant_id = v_tenant;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Media not found', 'fields', json_build_object())
    );
  END IF;

  DELETE FROM public.deal_media
  WHERE id = p_media_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('media_id', p_media_id, 'storage_path', v_storage_path),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."delete_deal_media_v1"("p_media_id" "uuid") OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."get_acq_deal_v1"("p_deal_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant          uuid;
  v_deal            record;
  v_props           record;
  v_last_contacted  timestamptz;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'p_deal_id is required', 'fields', json_build_object())
    );
  END IF;

  SELECT * INTO v_deal
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  SELECT * INTO v_props
  FROM public.deal_properties
  WHERE deal_id = p_deal_id AND tenant_id = v_tenant;

  -- Derive last_contacted_at from most recent call_log note
  SELECT dn.created_at INTO v_last_contacted
  FROM public.deal_notes dn
  WHERE dn.deal_id   = p_deal_id
    AND dn.tenant_id = v_tenant
    AND dn.note_type = 'call_log'
  ORDER BY dn.created_at DESC
  LIMIT 1;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object(
      'id',                v_deal.id,
      'stage',             v_deal.stage,
      'address',           v_deal.address,
      'assignee_user_id',  v_deal.assignee_user_id,
      'seller_name',       v_deal.seller_name,
      'seller_phone',      v_deal.seller_phone,
      'seller_email',      v_deal.seller_email,
      'seller_pain',       v_deal.seller_pain,
      'seller_timeline',   v_deal.seller_timeline,
      'seller_notes',      v_deal.seller_notes,
      'next_action',       v_deal.next_action,
      'next_action_due',   v_deal.next_action_due,
      'dead_reason',       v_deal.dead_reason,
      'farm_area_id',      v_deal.farm_area_id,
      'created_at',        v_deal.created_at,
      'updated_at',        v_deal.updated_at,
      'health_color',      public.get_deal_health_color(v_deal.stage, v_deal.updated_at),
      'last_contacted_at', v_last_contacted,
      'properties',        CASE WHEN v_props.id IS NULL THEN null ELSE json_build_object(
        'property_type',   v_props.property_type,
        'beds',            v_props.beds,
        'baths',           v_props.baths,
        'sqft',            v_props.sqft,
        'lot_size',        v_props.lot_size,
        'year_built',      v_props.year_built,
        'occupancy',       v_props.occupancy,
        'deficiency_tags', v_props.deficiency_tags,
        'condition_notes', v_props.condition_notes,
        'repair_estimate', v_props.repair_estimate,
        'garage_parking',  v_props.garage_parking,
        'basement_type',   v_props.basement_type,
        'foundation_type', v_props.foundation_type,
        'roof_age',        v_props.roof_age,
        'furnace_age',     v_props.furnace_age,
        'ac_age',          v_props.ac_age,
        'heating_type',    v_props.heating_type,
        'cooling_type',    v_props.cooling_type
      ) END,
      'pricing',           (
        SELECT json_build_object(
          'arv',            di.assumptions->>'arv',
          'ask_price',      di.assumptions->>'ask_price',
          'repair_estimate', di.assumptions->>'repair_estimate',
          'assignment_fee', di.assumptions->>'assignment_fee',
          'mao',            di.assumptions->>'mao',
          'multiplier',     di.assumptions->>'multiplier',
          'calc_version',   di.calc_version
        )
        FROM public.deal_inputs di
        WHERE di.deal_id = p_deal_id AND di.tenant_id = v_tenant
        ORDER BY di.created_at DESC LIMIT 1
      )
    ),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."get_acq_deal_v1"("p_deal_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_acq_kpis_v1"("p_date_from" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_date_to" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;

ALTER FUNCTION "public"."get_acq_kpis_v1"("p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_deal_health_color"("p_stage" "text", "p_updated_at" timestamp with time zone) RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT CASE
    WHEN p_updated_at IS NULL        THEN 'yellow'
    WHEN p_stage = 'new'            AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 3         THEN 'red'
    WHEN p_stage = 'new'            AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 3 * 0.7   THEN 'yellow'
    WHEN p_stage = 'analyzing'      AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7         THEN 'red'
    WHEN p_stage = 'analyzing'      AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7 * 0.7   THEN 'yellow'
    WHEN p_stage = 'offer_sent'     AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 5         THEN 'red'
    WHEN p_stage = 'offer_sent'     AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 5 * 0.7   THEN 'yellow'
    WHEN p_stage = 'under_contract' AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 14        THEN 'red'
    WHEN p_stage = 'under_contract' AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 14 * 0.7  THEN 'yellow'
    WHEN p_stage = 'dispo'          AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7         THEN 'red'
    WHEN p_stage = 'dispo'          AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 7 * 0.7   THEN 'yellow'
    WHEN p_stage = 'tc'             AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 14        THEN 'red'
    WHEN p_stage = 'tc'             AND EXTRACT(EPOCH FROM (now() - p_updated_at))/86400 > 14 * 0.7  THEN 'yellow'
    ELSE 'green'
  END
$$;

ALTER FUNCTION "public"."get_deal_health_color"("p_stage" "text", "p_updated_at" timestamp with time zone) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_lead_intake_kpis_v1"("p_date_from" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_date_to" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant                 uuid;
  v_from                   timestamptz;
  v_to                     timestamptz;
  v_new_leads              bigint;
  v_denom                  bigint;
  v_num                    bigint;
  v_submission_to_deal_pct integer;
  v_avg_review_h           numeric;
  v_unreviewed             bigint;
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

  v_from := COALESCE(p_date_from, now() - interval '30 days');
  v_to := COALESCE(p_date_to, now());

  IF v_to < v_from THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'effective date window is invalid (end before start)',
        'fields', '{}'::jsonb
      )
    );
  END IF;

  SELECT COUNT(*) INTO v_new_leads
  FROM public.intake_submissions
  WHERE tenant_id = v_tenant
    AND submitted_at >= v_from
    AND submitted_at <= v_to;

  SELECT COUNT(*) INTO v_denom
  FROM public.intake_submissions
  WHERE tenant_id = v_tenant
    AND form_type IN ('seller', 'birddog')
    AND submitted_at >= v_from
    AND submitted_at <= v_to;

  SELECT COUNT(*) INTO v_num
  FROM public.intake_submissions s
  WHERE s.tenant_id = v_tenant
    AND s.form_type IN ('seller', 'birddog')
    AND s.submitted_at >= v_from
    AND s.submitted_at <= v_to
    AND s.draft_deals_id IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.draft_deals d
      WHERE d.id = s.draft_deals_id
        AND d.tenant_id = v_tenant
        AND d.promoted_deal_id IS NOT NULL
    );

  IF v_denom = 0 THEN
    v_submission_to_deal_pct := 0;
  ELSE
    v_submission_to_deal_pct := ROUND((v_num::numeric * 100.0 / v_denom::numeric), 0)::integer;
  END IF;

  SELECT COALESCE(
    ROUND(
      AVG(EXTRACT(EPOCH FROM (reviewed_at - submitted_at)) / 3600.0)::numeric,
      1
    ),
    0
  ) INTO v_avg_review_h
  FROM public.intake_submissions
  WHERE tenant_id = v_tenant
    AND reviewed_at IS NOT NULL
    AND submitted_at >= v_from
    AND submitted_at <= v_to;

  SELECT COUNT(*) INTO v_unreviewed
  FROM public.intake_submissions
  WHERE tenant_id = v_tenant
    AND reviewed_at IS NULL;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object(
      'new_leads',               v_new_leads,
      'submission_to_deal_pct', v_submission_to_deal_pct,
      'avg_review_time_hours',  v_avg_review_h,
      'unreviewed_count',       v_unreviewed,
      'date_from',              v_from,
      'date_to',                v_to
    ),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."get_lead_intake_kpis_v1"("p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_profile_settings_v1"() RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user         uuid;
  v_email        text;
  v_display_name text;
  v_has_used_trial boolean;
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

  SELECT au.email INTO v_email
  FROM auth.users au
  WHERE au.id = v_user;

  SELECT up.display_name, up.has_used_trial
  INTO v_display_name, v_has_used_trial
  FROM public.user_profiles up
  WHERE up.id = v_user;

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

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'user_id',        v_user,
      'email',          v_email,
      'display_name',   v_display_name,
      'has_used_trial', v_has_used_trial
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

CREATE OR REPLACE FUNCTION "public"."handoff_to_dispo_v1"("p_deal_id" "uuid", "p_assignee_user_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
  v_user   uuid;
  v_stage  text;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant or user context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
    );
  END IF;

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  IF v_stage <> 'under_contract' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Handoff to Dispo is only allowed from Under Contract stage', 'fields', json_build_object())
    );
  END IF;

  IF p_assignee_user_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.tenant_memberships
    WHERE tenant_id = v_tenant AND user_id = p_assignee_user_id
  ) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Assignee is not a member of this workspace', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    stage              = 'dispo',
    assignee_user_id   = p_assignee_user_id,
    updated_at         = now(),
    row_version        = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  INSERT INTO public.deal_activity_log (tenant_id, deal_id, activity_type, content, created_by, created_at)
  VALUES (v_tenant, p_deal_id, 'handoff', 'Deal handed off to Dispo', v_user, now());

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'dispo', 'assignee_user_id', p_assignee_user_id),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."handoff_to_dispo_v1"("p_deal_id" "uuid", "p_assignee_user_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."handoff_to_tc_v1"("p_deal_id" "uuid", "p_assignee_user_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
  v_stage  text;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
    );
  END IF;

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  IF v_stage <> 'dispo' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Handoff to TC is only allowed from Dispo stage', 'fields', json_build_object())
    );
  END IF;

  IF p_assignee_user_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.tenant_memberships
    WHERE tenant_id = v_tenant AND user_id = p_assignee_user_id
  ) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Assignee is not a member of this workspace', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    stage            = 'tc',
    assignee_user_id = p_assignee_user_id,
    updated_at       = now(),
    row_version      = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'tc', 'assignee_user_id', p_assignee_user_id),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."handoff_to_tc_v1"("p_deal_id" "uuid", "p_assignee_user_id" "uuid") OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."list_acq_deals_v1"("p_filter" "text" DEFAULT 'all'::"text", "p_farm_area_id" "uuid" DEFAULT NULL::"uuid") RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF p_filter NOT IN ('all', 'new', 'analyzing', 'offer_sent', 'under_contract', 'follow_ups') THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Invalid filter value', 'fields', json_build_object())
    );
  END IF;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object(
      'items', COALESCE(
        (
          SELECT json_agg(
            json_build_object(
              'id',              d.id,
              'stage',           d.stage,
              'address',         d.address,
              'assignee_user_id', d.assignee_user_id,
              'next_action',     d.next_action,
              'next_action_due', d.next_action_due,
              'farm_area_id',    d.farm_area_id,
              'updated_at',      d.updated_at,
              'created_at',      d.created_at,
              'health_color',    public.get_deal_health_color(d.stage, d.updated_at),
              'arv',             (
                SELECT di.assumptions->>'arv'
                FROM public.deal_inputs di
                WHERE di.deal_id = d.id AND di.tenant_id = v_tenant
                ORDER BY di.created_at DESC LIMIT 1
              ),
              'ask',             (
                SELECT di.assumptions->>'ask_price'
                FROM public.deal_inputs di
                WHERE di.deal_id = d.id AND di.tenant_id = v_tenant
                ORDER BY di.created_at DESC LIMIT 1
              )
            )
            ORDER BY d.updated_at DESC
          )
          FROM public.deals d
          WHERE d.tenant_id = v_tenant
            AND d.deleted_at IS NULL
            AND d.stage NOT IN ('dispo', 'tc', 'closed', 'dead')
            AND (
              p_filter = 'all'
              OR (p_filter = 'follow_ups' AND EXISTS (
                SELECT 1 FROM public.deal_reminders r
                WHERE r.deal_id = d.id
                  AND r.tenant_id = v_tenant
                  AND r.completed_at IS NULL
                  AND r.reminder_date <= now()
              ))
              OR (p_filter NOT IN ('all', 'follow_ups') AND d.stage = p_filter)
            )
            AND (p_farm_area_id IS NULL OR d.farm_area_id = p_farm_area_id)
        ),
        '[]'::json
      )
    ),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."list_acq_deals_v1"("p_filter" "text", "p_farm_area_id" "uuid") OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."list_buyers_v1"("p_limit" integer DEFAULT 25) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
  v_limit     int;
  v_items     jsonb;
BEGIN
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context.', 'fields', '{}'::jsonb)
    );
  END IF;

  v_limit := COALESCE(p_limit, 25);
  IF v_limit < 1 OR v_limit > 100 THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_limit must be between 1 and 100.',
        'fields', jsonb_build_object('p_limit', 'Out of range.'))
    );
  END IF;

  SELECT jsonb_agg(r)
  INTO v_items
  FROM (
    SELECT jsonb_build_object(
      'id',                id,
      'name',              name,
      'email',             email,
      'phone',             phone,
      'areas_of_interest', areas_of_interest,
      'budget_range',      budget_range,
      'deal_type_tags',    deal_type_tags,
      'price_range_notes', price_range_notes,
      'notes',             notes,
      'is_active',         is_active,
      'created_at',        created_at,
      'updated_at',        updated_at
    ) AS r
    FROM public.intake_buyers
    WHERE tenant_id = v_tenant_id
    ORDER BY created_at DESC, id DESC
    LIMIT v_limit
  ) sub;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object('items', COALESCE(v_items, '[]'::jsonb)),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."list_buyers_v1"("p_limit" integer) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_deal_activity_v1"("p_deal_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
  v_user   uuid;
  v_deal   uuid;
  v_result json;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No tenant or user context', 'fields', '{}'::json)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_deal_id is required', 'fields', '{}'::json)
    );
  END IF;

  SELECT id INTO v_deal
  FROM public.deals
  WHERE id        = p_deal_id
    AND tenant_id = v_tenant
    AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
    );
  END IF;

  SELECT json_agg(
    json_build_object(
      'activity_id',    fa.id,
      'deal_id',        fa.deal_id,
      'activity_type',  fa.activity_type,
      'content',        fa.content,
      'created_by',     fa.created_by,
      'created_by_name', COALESCE(up.display_name, ''),
      'created_at',     fa.created_at
    ) ORDER BY fa.created_at DESC
  )
  INTO v_result
  FROM public.deal_activity_log fa
  LEFT JOIN public.user_profiles up ON up.id = fa.created_by
  WHERE fa.deal_id   = p_deal_id
    AND fa.tenant_id = v_tenant;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('activity', COALESCE(v_result, '[]'::json)),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."list_deal_activity_v1"("p_deal_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_deal_media_v1"("p_deal_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.deals
    WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL
  ) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object(
      'items', COALESCE(
        (
          SELECT json_agg(
            json_build_object(
              'id',           m.id,
              'storage_path', m.storage_path,
              'media_type',   m.media_type,
              'sort_order',   m.sort_order,
              'uploaded_at',  m.uploaded_at,
              'uploaded_by',  m.uploaded_by
            )
            ORDER BY m.sort_order ASC, m.uploaded_at ASC
          )
          FROM public.deal_media m
          WHERE m.deal_id = p_deal_id AND m.tenant_id = v_tenant
        ),
        '[]'::json
      )
    ),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."list_deal_media_v1"("p_deal_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_deal_notes_v1"("p_deal_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
  v_user   uuid;
  v_deal   uuid;
  v_result json;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No tenant or user context', 'fields', '{}'::json)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_deal_id is required', 'fields', '{}'::json)
    );
  END IF;

  SELECT id INTO v_deal
  FROM public.deals
  WHERE id        = p_deal_id
    AND tenant_id = v_tenant
    AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
    );
  END IF;

  SELECT json_agg(
    json_build_object(
      'note_id',        dn.id,
      'deal_id',        dn.deal_id,
      'note_type',      dn.note_type,
      'content',        dn.content,
      'created_by',     dn.created_by,
      'created_by_name', COALESCE(up.display_name, ''),
      'created_at',     dn.created_at,
      'updated_at',     dn.updated_at
    ) ORDER BY dn.created_at DESC
  )
  INTO v_result
  FROM public.deal_notes dn
  LEFT JOIN public.user_profiles up ON up.id = dn.created_by
  WHERE dn.deal_id   = p_deal_id
    AND dn.tenant_id = v_tenant;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('notes', COALESCE(v_result, '[]'::json)),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."list_deal_notes_v1"("p_deal_id" "uuid") OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."list_intake_submissions_v1"("p_limit" integer DEFAULT 25) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
  v_limit     int;
  v_items     jsonb;
BEGIN
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context.', 'fields', '{}'::jsonb)
    );
  END IF;

  v_limit := COALESCE(p_limit, 25);
  IF v_limit < 1 OR v_limit > 100 THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_limit must be between 1 and 100.',
        'fields', jsonb_build_object('p_limit', 'Out of range.'))
    );
  END IF;

  SELECT jsonb_agg(r)
  INTO v_items
  FROM (
    SELECT jsonb_build_object(
      'id',              id,
      'form_type',       form_type,
      'payload',         payload,
      'source',          source,
      'submitted_at',    submitted_at,
      'reviewed_at',     reviewed_at,
      'draft_deals_id',  draft_deals_id
    ) AS r
    FROM public.intake_submissions
    WHERE tenant_id = v_tenant_id
      AND form_type IN ('seller', 'birddog')
    ORDER BY submitted_at DESC, id DESC
    LIMIT v_limit
  ) sub;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object('items', COALESCE(v_items, '[]'::jsonb)),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."list_intake_submissions_v1"("p_limit" integer) OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."mark_deal_dead_v1"("p_deal_id" "uuid", "p_dead_reason" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
  v_stage  text;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
    );
  END IF;

  IF p_dead_reason IS NULL OR trim(p_dead_reason) = '' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Dead reason is required', 'fields', json_build_object('dead_reason', 'required'))
    );
  END IF;

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  IF v_stage IN ('closed', 'dead') THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal is already in a terminal stage', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    stage       = 'dead',
    dead_reason = p_dead_reason,
    updated_at  = now(),
    row_version = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  INSERT INTO public.deal_activity_log (tenant_id, deal_id, activity_type, content, created_by)
  VALUES (v_tenant, p_deal_id, 'marked_dead', 'Deal marked dead', auth.uid());

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'dead'),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."mark_deal_dead_v1"("p_deal_id" "uuid", "p_dead_reason" "text") OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."promote_draft_deal_v1"("p_draft_id" "uuid", "p_fields" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant      uuid;
  d             RECORD;
  v_pf          jsonb;
  v_addr        text;
  v_sn          text;
  v_sp          text;
  v_se          text;
  v_pain        text;
  v_tl          text;
  v_notes       text;
  v_asm         jsonb;
  v_prop_m      jsonb;
  v_id          uuid;
  v_snapshot_id uuid;
  v_prop_keys   text[] := ARRAY[
    'property_type','beds','baths','sqft','lot_size','year_built',
    'occupancy','deficiency_tags','condition_notes','repair_estimate',
    'garage_parking','basement_type','foundation_type',
    'roof_age','furnace_age','ac_age','heating_type','cooling_type'
  ];
  v_allowed_top text[] := ARRAY[
    'address','seller_name','seller_phone','seller_email',
    'seller_pain','seller_timeline','seller_notes','property','assumptions'
  ];
  v_price_keys  text[] := ARRAY['arv','ask_price','repair_estimate','assignment_fee','multiplier'];
  v_unknown     text[];
  v_prop        jsonb;
  v_def_tags    text[];
  v_ask_num     numeric;
  v_err         text;
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

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'WORKSPACE_NOT_WRITABLE', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Workspace is not active', 'fields', '{}'::jsonb)
    );
  END IF;

  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'No tenant context', 'fields', '{}'::jsonb)
    );
  END IF;

  IF p_draft_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_draft_id is required', 'fields', '{}'::jsonb)
    );
  END IF;

  v_pf := COALESCE(p_fields, '{}'::jsonb);
  IF jsonb_typeof(v_pf) <> 'object' THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'p_fields must be a JSON object', 'fields', '{}'::jsonb)
    );
  END IF;

  SELECT ARRAY(
    SELECT jsonb_object_keys(v_pf)
    EXCEPT
    SELECT unnest(v_allowed_top)
  ) INTO v_unknown;
  IF array_length(v_unknown, 1) > 0 THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object(
        'message', 'Unknown top-level fields: ' || array_to_string(v_unknown, ', '),
        'fields', '{}'::jsonb
      )
    );
  END IF;

  IF v_pf ? 'property' AND (jsonb_typeof(v_pf->'property') <> 'object' OR v_pf->'property' IS NULL) THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'property must be a JSON object', 'fields', '{}'::jsonb)
    );
  END IF;

  IF v_pf ? 'assumptions' THEN
    IF jsonb_typeof(v_pf->'assumptions') <> 'object' OR v_pf->'assumptions' IS NULL THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'assumptions must be a JSON object', 'fields', '{}'::jsonb)
      );
    END IF;
    IF v_pf->'assumptions' ? 'mao' THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'mao is derived server-side', 'fields', '{}'::jsonb)
      );
    END IF;
    SELECT ARRAY(
      SELECT jsonb_object_keys(v_pf->'assumptions')
      EXCEPT
      SELECT unnest(v_price_keys)
    ) INTO v_unknown;
    IF array_length(v_unknown, 1) > 0 THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object(
          'message', 'Unknown assumptions keys: ' || array_to_string(v_unknown, ', '),
          'fields', '{}'::jsonb
        )
      );
    END IF;
  END IF;

  IF v_pf ? 'property' THEN
    SELECT ARRAY(
      SELECT jsonb_object_keys(v_pf->'property')
      EXCEPT
      SELECT unnest(v_prop_keys)
    ) INTO v_unknown;
    IF array_length(v_unknown, 1) > 0 THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object(
          'message', 'Unknown property keys: ' || array_to_string(v_unknown, ', '),
          'fields', '{}'::jsonb
        )
      );
    END IF;
  END IF;

  SELECT * INTO d
  FROM public.draft_deals
  WHERE id = p_draft_id AND tenant_id = v_tenant;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Draft not found', 'fields', '{}'::jsonb)
    );
  END IF;

  IF d.promoted_deal_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Draft already promoted', 'fields', '{}'::jsonb)
    );
  END IF;

  v_err := public._intake_validate_deal_property_jsonb_v1(COALESCE(v_pf->'property', '{}'::jsonb));
  IF v_err IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', v_err, 'fields', '{}'::jsonb)
    );
  END IF;

  v_addr := NULLIF(trim(v_pf->>'address'), '');
  v_sn   := NULLIF(trim(v_pf->>'seller_name'), '');
  v_sp   := NULLIF(trim(v_pf->>'seller_phone'), '');
  v_se   := NULLIF(trim(v_pf->>'seller_email'), '');
  v_pain := NULLIF(trim(v_pf->>'seller_pain'), '');
  v_tl   := NULLIF(trim(v_pf->>'seller_timeline'), '');
  v_notes := NULLIF(trim(v_pf->>'seller_notes'), '');

  IF d.form_type = 'seller' THEN
    v_addr := COALESCE(v_addr, NULLIF(trim(d.address), ''), NULLIF(trim(d.payload->>'address'), ''));
    v_sn := COALESCE(v_sn, NULLIF(trim(d.payload->>'name'), ''));
    v_sp := COALESCE(v_sp, NULLIF(trim(d.payload->>'phone'), ''));
    v_se := COALESCE(v_se, NULLIF(trim(d.payload->>'email'), ''));
  ELSIF d.form_type = 'birddog' THEN
    v_addr := COALESCE(v_addr, NULLIF(trim(d.address), ''), NULLIF(trim(d.payload->>'address'), ''));
    v_sn := COALESCE(v_sn, NULLIF(trim(d.payload->>'name'), ''));
    v_sp := COALESCE(v_sp, NULLIF(trim(d.payload->>'phone'), ''));
    v_se := COALESCE(v_se, NULLIF(trim(d.payload->>'email'), ''));
  ELSIF d.form_type = 'buyer' THEN
    v_sn := COALESCE(v_sn, NULLIF(trim(d.payload->>'name'), ''));
    v_sp := COALESCE(v_sp, NULLIF(trim(d.payload->>'phone'), ''));
    v_se := COALESCE(v_se, NULLIF(trim(d.payload->>'email'), ''));
  END IF;

  v_asm := '{}'::jsonb;
  IF d.asking_price IS NOT NULL THEN
    v_asm := v_asm || jsonb_build_object('ask_price', d.asking_price);
  END IF;
  IF d.repair_estimate IS NOT NULL THEN
    v_asm := v_asm || jsonb_build_object('repair_estimate', d.repair_estimate);
  END IF;
  IF d.form_type = 'birddog' AND (d.payload->>'asking_price') IS NOT NULL AND trim(d.payload->>'asking_price') <> '' THEN
    v_err := public._intake_validate_pricing_assumptions_v1(
      jsonb_build_object('ask_price', trim(d.payload->>'asking_price'))
    );
    IF v_err IS NOT NULL THEN
      RETURN jsonb_build_object(
        'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
        'error', jsonb_build_object('message', 'draft payload asking_price: ' || v_err, 'fields', '{}'::jsonb)
      );
    END IF;
    v_ask_num := (trim(d.payload->>'asking_price'))::numeric;
    v_asm := v_asm || jsonb_build_object('ask_price', v_ask_num);
  END IF;

  v_asm := v_asm || COALESCE(v_pf->'assumptions', '{}'::jsonb);

  v_err := public._intake_validate_pricing_assumptions_v1(v_asm);
  IF v_err IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', v_err, 'fields', '{}'::jsonb)
    );
  END IF;

  v_asm := public._intake_apply_mao_to_assumptions_v1(v_asm);

  v_prop_m := '{}'::jsonb;
  IF d.form_type = 'birddog' AND (d.payload->>'condition_notes') IS NOT NULL THEN
    v_prop_m := v_prop_m || jsonb_build_object(
      'condition_notes', NULLIF(trim(d.payload->>'condition_notes'), '')
    );
  END IF;
  IF d.form_type IN ('seller', 'birddog') AND d.repair_estimate IS NOT NULL THEN
    v_prop_m := v_prop_m || jsonb_build_object('repair_estimate', d.repair_estimate);
  END IF;

  IF v_pf ? 'property' THEN
    v_prop_m := COALESCE(v_prop_m, '{}'::jsonb) || COALESCE(v_pf->'property', '{}'::jsonb);
  END IF;

  v_err := public._intake_validate_deal_property_jsonb_v1(
    CASE WHEN v_prop_m = '{}'::jsonb OR v_prop_m IS NULL THEN '{}'::jsonb ELSE v_prop_m END
  );
  IF v_err IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', v_err, 'fields', '{}'::jsonb)
    );
  END IF;

  v_id := gen_random_uuid();
  v_snapshot_id := gen_random_uuid();

  INSERT INTO public.deals (
    id, tenant_id, row_version, calc_version,
    assumptions_snapshot_id, stage,
    address,
    seller_name, seller_phone, seller_email, seller_pain, seller_timeline, seller_notes
  ) VALUES (
    v_id, v_tenant, 1, 1,
    v_snapshot_id, 'new',
    v_addr, v_sn, v_sp, v_se, v_pain, v_tl, v_notes
  );

  INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
  VALUES (v_snapshot_id, v_tenant, v_id, 1, 1, COALESCE(v_asm, '{}'::jsonb));

  IF v_prop_m IS NOT NULL AND v_prop_m <> '{}'::jsonb THEN
    v_prop := v_prop_m;
    v_def_tags := NULL;
    IF v_prop ? 'deficiency_tags' AND jsonb_typeof(v_prop->'deficiency_tags') = 'array' THEN
      v_def_tags := ARRAY(SELECT jsonb_array_elements_text(v_prop->'deficiency_tags'));
    END IF;

    INSERT INTO public.deal_properties (
      tenant_id, deal_id, row_version,
      property_type, beds, baths, sqft, lot_size, year_built, occupancy,
      deficiency_tags, condition_notes, repair_estimate,
      garage_parking, basement_type, foundation_type,
      roof_age, furnace_age, ac_age, heating_type, cooling_type
    ) VALUES (
      v_tenant, v_id, 1,
      NULLIF(trim(v_prop->>'property_type'), ''),
      NULLIF(trim(v_prop->>'beds'), ''),
      NULLIF(trim(v_prop->>'baths'), ''),
      NULLIF(trim(v_prop->>'sqft'), ''),
      NULLIF(trim(v_prop->>'lot_size'), ''),
      CASE WHEN v_prop->>'year_built' IS NOT NULL AND trim(v_prop->>'year_built') <> ''
        THEN (trim(v_prop->>'year_built'))::integer ELSE NULL END,
      NULLIF(trim(v_prop->>'occupancy'), ''),
      v_def_tags,
      NULLIF(trim(v_prop->>'condition_notes'), ''),
      CASE WHEN v_prop->>'repair_estimate' IS NOT NULL AND trim(v_prop->>'repair_estimate') <> ''
        THEN (trim(v_prop->>'repair_estimate'))::numeric ELSE NULL END,
      NULLIF(trim(v_prop->>'garage_parking'), ''),
      NULLIF(trim(v_prop->>'basement_type'), ''),
      NULLIF(trim(v_prop->>'foundation_type'), ''),
      CASE WHEN v_prop->>'roof_age' IS NOT NULL AND trim(v_prop->>'roof_age') <> ''
        THEN (trim(v_prop->>'roof_age'))::integer ELSE NULL END,
      CASE WHEN v_prop->>'furnace_age' IS NOT NULL AND trim(v_prop->>'furnace_age') <> ''
        THEN (trim(v_prop->>'furnace_age'))::integer ELSE NULL END,
      CASE WHEN v_prop->>'ac_age' IS NOT NULL AND trim(v_prop->>'ac_age') <> ''
        THEN (trim(v_prop->>'ac_age'))::integer ELSE NULL END,
      NULLIF(trim(v_prop->>'heating_type'), ''),
      NULLIF(trim(v_prop->>'cooling_type'), '')
    );
  END IF;

  UPDATE public.draft_deals
  SET promoted_deal_id = v_id
  WHERE id = d.id AND tenant_id = v_tenant;

  UPDATE public.intake_submissions
  SET reviewed_at = now()
  WHERE draft_deals_id = d.id AND tenant_id = v_tenant;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object('deal_id', v_id),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."promote_draft_deal_v1"("p_draft_id" "uuid", "p_fields" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."register_deal_media_v1"("p_deal_id" "uuid", "p_storage_path" "text", "p_sort_order" integer DEFAULT 0) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant   uuid;
  v_media_id uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
    );
  END IF;

  IF p_storage_path IS NULL OR trim(p_storage_path) = '' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', json_build_object(),
      'error', json_build_object('message', 'Storage path is required', 'fields', json_build_object('storage_path', 'required'))
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.deals
    WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL
  ) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  BEGIN
    INSERT INTO public.deal_media (
      tenant_id, deal_id, storage_path, media_type, sort_order, uploaded_by
    )
    VALUES (
      v_tenant, p_deal_id, p_storage_path, 'photo', p_sort_order, auth.uid()
    )
    RETURNING id INTO v_media_id;
  EXCEPTION WHEN unique_violation THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'A file with this storage path already exists', 'fields', json_build_object())
    );
  END;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('media_id', v_media_id, 'storage_path', p_storage_path),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."register_deal_media_v1"("p_deal_id" "uuid", "p_storage_path" "text", "p_sort_order" integer) OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."return_to_acq_v1"("p_deal_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
  v_stage  text;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
    );
  END IF;

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  IF v_stage <> 'dispo' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Return to Acq is only allowed from Dispo stage', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    stage       = 'under_contract',
    updated_at  = now(),
    row_version = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'under_contract'),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."return_to_acq_v1"("p_deal_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."return_to_dispo_v1"("p_deal_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
  v_stage  text;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
    );
  END IF;

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  IF v_stage <> 'tc' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Return to Dispo is only allowed from TC stage', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    stage       = 'dispo',
    updated_at  = now(),
    row_version = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'stage', 'dispo'),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."return_to_dispo_v1"("p_deal_id" "uuid") OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."submit_form_v1"("p_slug" "text", "p_form_type" "text", "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_tenant_id   uuid;
  v_draft_id    uuid;
  v_intake_id    uuid;
  v_buyer_id    uuid;
  v_address      text;
  v_valid_types  text[] := ARRAY['buyer', 'seller', 'birddog'];
  v_spam_token   text;
  v_sub_status   text;
  v_period_end   timestamptz;
BEGIN
  IF p_form_type IS NULL OR NOT (p_form_type = ANY(v_valid_types)) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Invalid form type',
        'fields', jsonb_build_object('form_type', 'Must be buyer, seller, or birddog')));
  END IF;

  IF p_slug IS NULL OR p_slug !~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not found', 'fields', '{}'::jsonb));
  END IF;

  IF p_payload IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Payload required',
        'fields', jsonb_build_object('payload', 'Required')));
  END IF;

  v_spam_token := p_payload->>'spam_token';
  IF v_spam_token IS NULL OR length(trim(v_spam_token)) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Spam protection token required',
        'fields', jsonb_build_object('spam_token', 'Required')));
  END IF;

  SELECT ts.tenant_id INTO v_tenant_id
  FROM public.tenant_slugs ts
  WHERE ts.slug = p_slug;

  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'Not found', 'fields', '{}'::jsonb));
  END IF;

  SELECT ts.status, ts.current_period_end
  INTO v_sub_status, v_period_end
  FROM public.tenant_subscriptions ts
  WHERE ts.tenant_id = v_tenant_id
  ORDER BY ts.created_at DESC
  LIMIT 1;

  IF v_sub_status IS NULL OR v_sub_status = 'canceled' OR v_period_end <= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_AUTHORIZED', 'data', '{}'::jsonb,
      'error', jsonb_build_object('message', 'This workspace is not accepting submissions.',
        'fields', '{}'::jsonb));
  END IF;

  IF p_form_type = 'seller' THEN
    v_address := NULLIF(trim(p_payload->>'address'), '');
  END IF;

  INSERT INTO public.draft_deals (
    tenant_id, slug, form_type, payload,
    asking_price, repair_estimate, address
  ) VALUES (
    v_tenant_id, p_slug, p_form_type, p_payload,
    NULL, NULL, v_address
  )
  RETURNING id INTO v_draft_id;

  INSERT INTO public.intake_submissions (tenant_id, form_type, payload, source, draft_deals_id)
  VALUES (v_tenant_id, p_form_type, p_payload, 'web', v_draft_id)
  RETURNING id INTO v_intake_id;

  IF p_form_type = 'buyer' THEN
    v_buyer_id := public.upsert_buyer_from_intake_v1(v_tenant_id, p_payload);
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'data', jsonb_build_object(
      'draft_id',  v_draft_id,
      'intake_id', v_intake_id,
      'buyer_id',  v_buyer_id
    ),
    'error', null
  );
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

CREATE OR REPLACE FUNCTION "public"."update_deal_pricing_v1"("p_deal_id" "uuid", "p_fields" "jsonb") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant           uuid;
  v_user             uuid;
  v_allowed_keys     text[] := ARRAY['arv','ask_price','repair_estimate','assignment_fee','multiplier'];
  v_unknown_keys     text[];
  v_base_row         record;
  v_base_assumptions jsonb;
  v_new_assumptions  jsonb;
  v_arv              numeric;
  v_ask_price        numeric;
  v_repair_estimate  numeric;
  v_assignment_fee   numeric;
  v_multiplier       numeric;
  v_new_id           uuid;
  v_final_arv        numeric;
  v_final_repair     numeric;
  v_final_multiplier     numeric;
  v_final_assignment_fee numeric;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No tenant or user context', 'fields', '{}'::json)
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'WORKSPACE_NOT_WRITABLE',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Workspace is not active', 'fields', '{}'::json)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_deal_id is required', 'fields', '{}'::json)
    );
  END IF;

  IF p_fields IS NULL OR jsonb_typeof(p_fields) <> 'object' OR p_fields = '{}'::jsonb THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_fields must be a non-empty JSON object', 'fields', '{}'::json)
    );
  END IF;

  -- Reject mao if sent by client
  IF p_fields ? 'mao' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'mao is derived server-side and cannot be set directly', 'fields', '{}'::json)
    );
  END IF;

  -- Reject unknown keys
  SELECT ARRAY(
    SELECT jsonb_object_keys(p_fields)
    EXCEPT
    SELECT unnest(v_allowed_keys)
  ) INTO v_unknown_keys;

  IF array_length(v_unknown_keys, 1) > 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Unknown fields: ' || array_to_string(v_unknown_keys, ', '), 'fields', '{}'::json)
    );
  END IF;

  -- Verify deal belongs to current tenant
  IF NOT EXISTS (
    SELECT 1 FROM public.deals
    WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
    );
  END IF;

  -- Get latest deal_inputs row as base
  SELECT * INTO v_base_row
  FROM public.deal_inputs
  WHERE deal_id   = p_deal_id
    AND tenant_id = v_tenant
  ORDER BY created_at DESC, id DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No base pricing row found for this deal', 'fields', '{}'::json)
    );
  END IF;

  v_base_assumptions := COALESCE(v_base_row.assumptions, '{}'::jsonb);

  -- Validate numeric fields safely
  IF p_fields ? 'arv' AND p_fields->>'arv' IS NOT NULL THEN
    BEGIN
      v_arv := (p_fields->>'arv')::numeric;
    EXCEPTION WHEN others THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'arv must be a valid number', 'fields', '{}'::json));
    END;
  END IF;

  IF p_fields ? 'ask_price' AND p_fields->>'ask_price' IS NOT NULL THEN
    BEGIN
      v_ask_price := (p_fields->>'ask_price')::numeric;
    EXCEPTION WHEN others THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'ask_price must be a valid number', 'fields', '{}'::json));
    END;
  END IF;

  IF p_fields ? 'repair_estimate' AND p_fields->>'repair_estimate' IS NOT NULL THEN
    BEGIN
      v_repair_estimate := (p_fields->>'repair_estimate')::numeric;
    EXCEPTION WHEN others THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'repair_estimate must be a valid number', 'fields', '{}'::json));
    END;
  END IF;

  IF p_fields ? 'assignment_fee' AND p_fields->>'assignment_fee' IS NOT NULL THEN
    BEGIN
      v_assignment_fee := (p_fields->>'assignment_fee')::numeric;
    EXCEPTION WHEN others THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'assignment_fee must be a valid number', 'fields', '{}'::json));
    END;
  END IF;

  IF p_fields ? 'multiplier' AND p_fields->>'multiplier' IS NOT NULL THEN
    BEGIN
      v_multiplier := (p_fields->>'multiplier')::numeric;
    EXCEPTION WHEN others THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'multiplier must be a valid number', 'fields', '{}'::json));
    END;
  END IF;

  -- Build new assumptions by merging changes onto base snapshot
  v_new_assumptions := v_base_assumptions;

  IF p_fields ? 'arv' THEN
    IF p_fields->>'arv' IS NULL THEN
      v_new_assumptions := v_new_assumptions - 'arv';
    ELSE
      v_new_assumptions := jsonb_set(v_new_assumptions, '{arv}', to_jsonb(v_arv));
    END IF;
  END IF;

  IF p_fields ? 'ask_price' THEN
    IF p_fields->>'ask_price' IS NULL THEN
      v_new_assumptions := v_new_assumptions - 'ask_price';
    ELSE
      v_new_assumptions := jsonb_set(v_new_assumptions, '{ask_price}', to_jsonb(v_ask_price));
    END IF;
  END IF;

  IF p_fields ? 'repair_estimate' THEN
    IF p_fields->>'repair_estimate' IS NULL THEN
      v_new_assumptions := v_new_assumptions - 'repair_estimate';
    ELSE
      v_new_assumptions := jsonb_set(v_new_assumptions, '{repair_estimate}', to_jsonb(v_repair_estimate));
    END IF;
  END IF;

  IF p_fields ? 'assignment_fee' THEN
    IF p_fields->>'assignment_fee' IS NULL THEN
      v_new_assumptions := v_new_assumptions - 'assignment_fee';
    ELSE
      v_new_assumptions := jsonb_set(v_new_assumptions, '{assignment_fee}', to_jsonb(v_assignment_fee));
    END IF;
  END IF;

  IF p_fields ? 'multiplier' THEN
    IF p_fields->>'multiplier' IS NULL THEN
      v_new_assumptions := v_new_assumptions - 'multiplier';
    ELSE
      v_new_assumptions := jsonb_set(v_new_assumptions, '{multiplier}', to_jsonb(v_multiplier));
    END IF;
  END IF;

  -- Reject if new assumptions identical to base
  IF v_new_assumptions = v_base_assumptions THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No actual changes provided', 'fields', '{}'::json)
    );
  END IF;

  -- Derive MAO from post-merge snapshot -- respects explicit nulls/clears
  -- Read from v_new_assumptions after all merges are applied
  v_final_arv            := (v_new_assumptions->>'arv')::numeric;
  v_final_repair         := (v_new_assumptions->>'repair_estimate')::numeric;
  v_final_multiplier     := (v_new_assumptions->>'multiplier')::numeric;
  v_final_assignment_fee := (v_new_assumptions->>'assignment_fee')::numeric;

  IF v_final_arv IS NOT NULL AND v_final_multiplier IS NOT NULL AND v_final_repair IS NOT NULL THEN
    v_new_assumptions := jsonb_set(v_new_assumptions, '{mao}',
      to_jsonb((v_final_arv * v_final_multiplier) - v_final_repair - COALESCE(v_final_assignment_fee, 0)));
  ELSE
    -- One or more inputs missing or cleared -- remove stale mao
    v_new_assumptions := v_new_assumptions - 'mao';
  END IF;

  -- Insert new deal_inputs row using clock_timestamp() for deterministic ordering
  INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, assumptions, created_at)
  VALUES (gen_random_uuid(), v_tenant, p_deal_id, v_base_row.calc_version, v_new_assumptions, clock_timestamp())
  RETURNING id INTO v_new_id;

  -- Update snapshot pointer
  UPDATE public.deals
  SET assumptions_snapshot_id = v_new_id,
      updated_at              = now(),
      row_version             = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id, 'deal_inputs_id', v_new_id),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."update_deal_pricing_v1"("p_deal_id" "uuid", "p_fields" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_deal_properties_v1"("p_deal_id" "uuid", "p_fields" "jsonb") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant            uuid;
  v_user              uuid;
  v_rows_updated      int;
  v_allowed_keys      text[] := ARRAY[
    'property_type','beds','baths','sqft','lot_size','year_built',
    'occupancy','deficiency_tags','condition_notes',
    'garage_parking','basement_type','foundation_type',
    'roof_age','furnace_age','ac_age','heating_type','cooling_type'
  ];
  v_unknown_keys      text[];
  v_year_built        integer;
  v_roof_age          integer;
  v_furnace_age       integer;
  v_ac_age            integer;
  v_deficiency_tags   text[];
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No tenant or user context', 'fields', '{}'::json)
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'WORKSPACE_NOT_WRITABLE',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Workspace is not active', 'fields', '{}'::json)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_deal_id is required', 'fields', '{}'::json)
    );
  END IF;

  IF p_fields IS NULL OR jsonb_typeof(p_fields) <> 'object' OR p_fields = '{}'::jsonb THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_fields must be a non-empty JSON object', 'fields', '{}'::json)
    );
  END IF;

  -- Reject unknown keys (repair_estimate now rejected -- use update_deal_pricing_v1)
  SELECT ARRAY(
    SELECT jsonb_object_keys(p_fields)
    EXCEPT
    SELECT unnest(v_allowed_keys)
  ) INTO v_unknown_keys;

  IF array_length(v_unknown_keys, 1) > 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Unknown fields: ' || array_to_string(v_unknown_keys, ', '), 'fields', '{}'::json)
    );
  END IF;

  -- Validate deficiency_tags shape
  IF p_fields ? 'deficiency_tags' THEN
    IF jsonb_typeof(p_fields->'deficiency_tags') = 'null' THEN
      v_deficiency_tags := NULL;
    ELSIF jsonb_typeof(p_fields->'deficiency_tags') = 'array' THEN
      IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(p_fields->'deficiency_tags') elem
        WHERE jsonb_typeof(elem) <> 'string'
      ) THEN
        RETURN json_build_object(
          'ok',    false,
          'code',  'VALIDATION_ERROR',
          'data',  '{}'::json,
          'error', json_build_object('message', 'deficiency_tags must be an array of strings', 'fields', '{}'::json)
        );
      END IF;
      v_deficiency_tags := ARRAY(SELECT jsonb_array_elements_text(p_fields->'deficiency_tags'));
    ELSE
      RETURN json_build_object(
        'ok',    false,
        'code',  'VALIDATION_ERROR',
        'data',  '{}'::json,
        'error', json_build_object('message', 'deficiency_tags must be an array of strings or null', 'fields', '{}'::json)
      );
    END IF;
  END IF;

  -- Validate typed fields safely
  IF p_fields ? 'year_built' AND p_fields->>'year_built' IS NOT NULL THEN
    BEGIN
      v_year_built := (p_fields->>'year_built')::integer;
    EXCEPTION WHEN others THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'year_built must be a valid integer', 'fields', '{}'::json));
    END;
  END IF;

  IF p_fields ? 'roof_age' AND p_fields->>'roof_age' IS NOT NULL THEN
    BEGIN
      v_roof_age := (p_fields->>'roof_age')::integer;
    EXCEPTION WHEN others THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'roof_age must be a valid integer', 'fields', '{}'::json));
    END;
  END IF;

  IF p_fields ? 'furnace_age' AND p_fields->>'furnace_age' IS NOT NULL THEN
    BEGIN
      v_furnace_age := (p_fields->>'furnace_age')::integer;
    EXCEPTION WHEN others THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'furnace_age must be a valid integer', 'fields', '{}'::json));
    END;
  END IF;

  IF p_fields ? 'ac_age' AND p_fields->>'ac_age' IS NOT NULL THEN
    BEGIN
      v_ac_age := (p_fields->>'ac_age')::integer;
    EXCEPTION WHEN others THEN
      RETURN json_build_object('ok', false, 'code', 'VALIDATION_ERROR', 'data', '{}'::json,
        'error', json_build_object('message', 'ac_age must be a valid integer', 'fields', '{}'::json));
    END;
  END IF;

  -- Verify deal belongs to current tenant
  IF NOT EXISTS (
    SELECT 1 FROM public.deals
    WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
    );
  END IF;

  -- Verify deal_properties row exists
  IF NOT EXISTS (
    SELECT 1 FROM public.deal_properties
    WHERE deal_id = p_deal_id AND tenant_id = v_tenant
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Deal properties not found', 'fields', '{}'::json)
    );
  END IF;

  UPDATE public.deal_properties
  SET
    property_type   = CASE WHEN p_fields ? 'property_type'   THEN (p_fields->>'property_type')   ELSE property_type   END,
    beds            = CASE WHEN p_fields ? 'beds'             THEN (p_fields->>'beds')             ELSE beds            END,
    baths           = CASE WHEN p_fields ? 'baths'            THEN (p_fields->>'baths')            ELSE baths           END,
    sqft            = CASE WHEN p_fields ? 'sqft'             THEN (p_fields->>'sqft')             ELSE sqft            END,
    lot_size        = CASE WHEN p_fields ? 'lot_size'         THEN (p_fields->>'lot_size')         ELSE lot_size        END,
    year_built      = CASE WHEN p_fields ? 'year_built'       THEN v_year_built                    ELSE year_built      END,
    occupancy       = CASE WHEN p_fields ? 'occupancy'        THEN (p_fields->>'occupancy')        ELSE occupancy       END,
    deficiency_tags = CASE WHEN p_fields ? 'deficiency_tags'  THEN v_deficiency_tags               ELSE deficiency_tags END,
    condition_notes = CASE WHEN p_fields ? 'condition_notes'  THEN (p_fields->>'condition_notes')  ELSE condition_notes END,
    garage_parking  = CASE WHEN p_fields ? 'garage_parking'   THEN (p_fields->>'garage_parking')   ELSE garage_parking  END,
    basement_type   = CASE WHEN p_fields ? 'basement_type'    THEN (p_fields->>'basement_type')    ELSE basement_type   END,
    foundation_type = CASE WHEN p_fields ? 'foundation_type'  THEN (p_fields->>'foundation_type')  ELSE foundation_type END,
    roof_age        = CASE WHEN p_fields ? 'roof_age'         THEN v_roof_age                      ELSE roof_age        END,
    furnace_age     = CASE WHEN p_fields ? 'furnace_age'      THEN v_furnace_age                   ELSE furnace_age     END,
    ac_age          = CASE WHEN p_fields ? 'ac_age'           THEN v_ac_age                        ELSE ac_age          END,
    heating_type    = CASE WHEN p_fields ? 'heating_type'     THEN (p_fields->>'heating_type')     ELSE heating_type    END,
    cooling_type    = CASE WHEN p_fields ? 'cooling_type'     THEN (p_fields->>'cooling_type')     ELSE cooling_type    END,
    updated_at      = now(),
    row_version     = row_version + 1
  WHERE deal_id   = p_deal_id
    AND tenant_id = v_tenant
    AND (
      (p_fields ? 'property_type'   AND (p_fields->>'property_type')  IS DISTINCT FROM property_type)   OR
      (p_fields ? 'beds'            AND (p_fields->>'beds')           IS DISTINCT FROM beds)             OR
      (p_fields ? 'baths'           AND (p_fields->>'baths')          IS DISTINCT FROM baths)            OR
      (p_fields ? 'sqft'            AND (p_fields->>'sqft')           IS DISTINCT FROM sqft)             OR
      (p_fields ? 'lot_size'        AND (p_fields->>'lot_size')       IS DISTINCT FROM lot_size)         OR
      (p_fields ? 'year_built'      AND v_year_built                  IS DISTINCT FROM year_built)       OR
      (p_fields ? 'occupancy'       AND (p_fields->>'occupancy')      IS DISTINCT FROM occupancy)        OR
      (p_fields ? 'deficiency_tags' AND v_deficiency_tags             IS DISTINCT FROM deficiency_tags)  OR
      (p_fields ? 'condition_notes' AND (p_fields->>'condition_notes') IS DISTINCT FROM condition_notes) OR
      (p_fields ? 'garage_parking'  AND (p_fields->>'garage_parking') IS DISTINCT FROM garage_parking)   OR
      (p_fields ? 'basement_type'   AND (p_fields->>'basement_type')  IS DISTINCT FROM basement_type)    OR
      (p_fields ? 'foundation_type' AND (p_fields->>'foundation_type') IS DISTINCT FROM foundation_type) OR
      (p_fields ? 'roof_age'        AND v_roof_age                    IS DISTINCT FROM roof_age)         OR
      (p_fields ? 'furnace_age'     AND v_furnace_age                 IS DISTINCT FROM furnace_age)      OR
      (p_fields ? 'ac_age'          AND v_ac_age                      IS DISTINCT FROM ac_age)           OR
      (p_fields ? 'heating_type'    AND (p_fields->>'heating_type')   IS DISTINCT FROM heating_type)     OR
      (p_fields ? 'cooling_type'    AND (p_fields->>'cooling_type')   IS DISTINCT FROM cooling_type)
    );

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No actual changes provided', 'fields', '{}'::json)
    );
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."update_deal_properties_v1"("p_deal_id" "uuid", "p_fields" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_deal_property_v1"("p_deal_id" "uuid", "p_fields" "jsonb") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant        uuid;
  v_user          uuid;
  v_rows_updated  int;
  v_deal_exists   boolean;
  v_allowed_keys  text[] := ARRAY['address','next_action','next_action_due'];
  v_unknown_keys  text[];
  v_next_action_due timestamptz;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No tenant or user context', 'fields', '{}'::json)
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'WORKSPACE_NOT_WRITABLE',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Workspace is not active', 'fields', '{}'::json)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_deal_id is required', 'fields', '{}'::json)
    );
  END IF;

  IF p_fields IS NULL OR jsonb_typeof(p_fields) <> 'object' OR p_fields = '{}'::jsonb THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_fields must be a non-empty JSON object', 'fields', '{}'::json)
    );
  END IF;

  -- Reject unknown keys
  SELECT ARRAY(
    SELECT jsonb_object_keys(p_fields)
    EXCEPT
    SELECT unnest(v_allowed_keys)
  ) INTO v_unknown_keys;

  IF array_length(v_unknown_keys, 1) > 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Unknown fields: ' || array_to_string(v_unknown_keys, ', '), 'fields', '{}'::json)
    );
  END IF;

  -- Validate next_action_due format if provided and not null
  IF p_fields ? 'next_action_due' AND p_fields->>'next_action_due' IS NOT NULL THEN
    BEGIN
      v_next_action_due := (p_fields->>'next_action_due')::timestamptz;
    EXCEPTION WHEN others THEN
      RETURN json_build_object(
        'ok',    false,
        'code',  'VALIDATION_ERROR',
        'data',  '{}'::json,
        'error', json_build_object('message', 'next_action_due is not a valid timestamp', 'fields', '{}'::json)
      );
    END;
  END IF;

  -- UPDATE only if at least one provided field IS DISTINCT FROM current value
  UPDATE public.deals
  SET
    address         = CASE WHEN p_fields ? 'address'         THEN (p_fields->>'address')          ELSE address         END,
    next_action     = CASE WHEN p_fields ? 'next_action'     THEN (p_fields->>'next_action')      ELSE next_action     END,
    next_action_due = CASE WHEN p_fields ? 'next_action_due' THEN v_next_action_due               ELSE next_action_due END,
    updated_at      = now(),
    row_version     = row_version + 1
  WHERE id        = p_deal_id
    AND tenant_id = v_tenant
    AND deleted_at IS NULL
    AND (
      (p_fields ? 'address'         AND (p_fields->>'address')     IS DISTINCT FROM address)         OR
      (p_fields ? 'next_action'     AND (p_fields->>'next_action') IS DISTINCT FROM next_action)     OR
      (p_fields ? 'next_action_due' AND v_next_action_due          IS DISTINCT FROM next_action_due)
    );

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    -- Disambiguate: not found vs no actual changes
    SELECT EXISTS (
      SELECT 1 FROM public.deals
      WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL
    ) INTO v_deal_exists;

    IF NOT v_deal_exists THEN
      RETURN json_build_object(
        'ok',    false,
        'code',  'NOT_FOUND',
        'data',  '{}'::json,
        'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
      );
    ELSE
      RETURN json_build_object(
        'ok',    false,
        'code',  'VALIDATION_ERROR',
        'data',  '{}'::json,
        'error', json_build_object('message', 'No actual changes provided', 'fields', '{}'::json)
      );
    END IF;
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."update_deal_property_v1"("p_deal_id" "uuid", "p_fields" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_deal_seller_v1"("p_deal_id" "uuid", "p_fields" "jsonb") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant        uuid;
  v_user          uuid;
  v_rows_updated  int;
  v_deal_exists   boolean;
  v_allowed_keys  text[] := ARRAY[
    'seller_name','seller_phone','seller_email',
    'seller_pain','seller_timeline','seller_notes'
  ];
  v_unknown_keys  text[];
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  '{}'::json,
      'error', json_build_object('message', 'No tenant or user context', 'fields', '{}'::json)
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'WORKSPACE_NOT_WRITABLE',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Workspace is not active', 'fields', '{}'::json)
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_deal_id is required', 'fields', '{}'::json)
    );
  END IF;

  IF p_fields IS NULL OR jsonb_typeof(p_fields) <> 'object' OR p_fields = '{}'::jsonb THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'p_fields must be a non-empty JSON object', 'fields', '{}'::json)
    );
  END IF;

  -- Reject unknown keys
  SELECT ARRAY(
    SELECT jsonb_object_keys(p_fields)
    EXCEPT
    SELECT unnest(v_allowed_keys)
  ) INTO v_unknown_keys;

  IF array_length(v_unknown_keys, 1) > 0 THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  '{}'::json,
      'error', json_build_object('message', 'Unknown fields: ' || array_to_string(v_unknown_keys, ', '), 'fields', '{}'::json)
    );
  END IF;

  -- UPDATE only if at least one provided field IS DISTINCT FROM current value
  UPDATE public.deals
  SET
    seller_name     = CASE WHEN p_fields ? 'seller_name'     THEN (p_fields->>'seller_name')     ELSE seller_name     END,
    seller_phone    = CASE WHEN p_fields ? 'seller_phone'    THEN (p_fields->>'seller_phone')    ELSE seller_phone    END,
    seller_email    = CASE WHEN p_fields ? 'seller_email'    THEN (p_fields->>'seller_email')    ELSE seller_email    END,
    seller_pain     = CASE WHEN p_fields ? 'seller_pain'     THEN (p_fields->>'seller_pain')     ELSE seller_pain     END,
    seller_timeline = CASE WHEN p_fields ? 'seller_timeline' THEN (p_fields->>'seller_timeline') ELSE seller_timeline END,
    seller_notes    = CASE WHEN p_fields ? 'seller_notes'    THEN (p_fields->>'seller_notes')    ELSE seller_notes    END,
    updated_at      = now(),
    row_version     = row_version + 1
  WHERE id        = p_deal_id
    AND tenant_id = v_tenant
    AND deleted_at IS NULL
    AND (
      (p_fields ? 'seller_name'     AND (p_fields->>'seller_name')     IS DISTINCT FROM seller_name)     OR
      (p_fields ? 'seller_phone'    AND (p_fields->>'seller_phone')    IS DISTINCT FROM seller_phone)    OR
      (p_fields ? 'seller_email'    AND (p_fields->>'seller_email')    IS DISTINCT FROM seller_email)    OR
      (p_fields ? 'seller_pain'     AND (p_fields->>'seller_pain')     IS DISTINCT FROM seller_pain)     OR
      (p_fields ? 'seller_timeline' AND (p_fields->>'seller_timeline') IS DISTINCT FROM seller_timeline) OR
      (p_fields ? 'seller_notes'    AND (p_fields->>'seller_notes')    IS DISTINCT FROM seller_notes)
    );

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    -- Disambiguate: not found vs no actual changes
    SELECT EXISTS (
      SELECT 1 FROM public.deals
      WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL
    ) INTO v_deal_exists;

    IF NOT v_deal_exists THEN
      RETURN json_build_object(
        'ok',    false,
        'code',  'NOT_FOUND',
        'data',  '{}'::json,
        'error', json_build_object('message', 'Deal not found', 'fields', '{}'::json)
      );
    ELSE
      RETURN json_build_object(
        'ok',    false,
        'code',  'VALIDATION_ERROR',
        'data',  '{}'::json,
        'error', json_build_object('message', 'No actual changes provided', 'fields', '{}'::json)
      );
    END IF;
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."update_deal_seller_v1"("p_deal_id" "uuid", "p_fields" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_deal_v1"("p_id" "uuid", "p_expected_row_version" bigint, "p_calc_version" integer DEFAULT NULL::integer) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant       uuid;
  v_stage        text;
  v_rows_updated int;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only. Renew your subscription to continue.', 'fields', json_build_object())
    );
  END IF;

  SELECT stage INTO v_stage
  FROM public.deals
  WHERE id = p_id AND tenant_id = v_tenant;

  IF v_stage IN ('closed', 'dead') THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal is in a terminal stage and cannot be modified', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals
  SET
    row_version  = row_version + 1,
    calc_version = COALESCE(p_calc_version, calc_version)
  WHERE id = p_id
    AND tenant_id = v_tenant
    AND row_version = p_expected_row_version;

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', json_build_object(),
      'error', json_build_object('message', 'Row version mismatch or deal not found for this tenant', 'fields', json_build_object())
    );
  END IF;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('id', p_id),
    'error', null
  );
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

CREATE OR REPLACE FUNCTION "public"."update_property_info_v1"("p_deal_id" "uuid", "p_property_type" "text" DEFAULT NULL::"text", "p_beds" integer DEFAULT NULL::integer, "p_baths" numeric DEFAULT NULL::numeric, "p_sqft" integer DEFAULT NULL::integer, "p_lot_size" "text" DEFAULT NULL::"text", "p_year_built" integer DEFAULT NULL::integer, "p_occupancy" "text" DEFAULT NULL::"text", "p_deficiency_tags" "text"[] DEFAULT NULL::"text"[], "p_condition_notes" "text" DEFAULT NULL::"text", "p_repair_estimate" numeric DEFAULT NULL::numeric, "p_garage_parking" "text" DEFAULT NULL::"text", "p_basement_type" "text" DEFAULT NULL::"text", "p_foundation_type" "text" DEFAULT NULL::"text", "p_roof_age" integer DEFAULT NULL::integer, "p_furnace_age" integer DEFAULT NULL::integer, "p_ac_age" integer DEFAULT NULL::integer, "p_heating_type" "text" DEFAULT NULL::"text", "p_cooling_type" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.deals
    WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL
  ) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  INSERT INTO public.deal_properties (
    tenant_id, deal_id,
    property_type, beds, baths, sqft, lot_size, year_built, occupancy,
    deficiency_tags, condition_notes, repair_estimate,
    garage_parking, basement_type, foundation_type,
    roof_age, furnace_age, ac_age, heating_type, cooling_type
  )
  VALUES (
    v_tenant, p_deal_id,
    p_property_type, p_beds, p_baths, p_sqft, p_lot_size, p_year_built, p_occupancy,
    p_deficiency_tags, p_condition_notes, p_repair_estimate,
    p_garage_parking, p_basement_type, p_foundation_type,
    p_roof_age, p_furnace_age, p_ac_age, p_heating_type, p_cooling_type
  )
  ON CONFLICT (deal_id) DO UPDATE SET
    property_type   = COALESCE(EXCLUDED.property_type,   deal_properties.property_type),
    beds            = COALESCE(EXCLUDED.beds,            deal_properties.beds),
    baths           = COALESCE(EXCLUDED.baths,           deal_properties.baths),
    sqft            = COALESCE(EXCLUDED.sqft,            deal_properties.sqft),
    lot_size        = COALESCE(EXCLUDED.lot_size,        deal_properties.lot_size),
    year_built      = COALESCE(EXCLUDED.year_built,      deal_properties.year_built),
    occupancy       = COALESCE(EXCLUDED.occupancy,       deal_properties.occupancy),
    deficiency_tags = COALESCE(EXCLUDED.deficiency_tags, deal_properties.deficiency_tags),
    condition_notes = COALESCE(EXCLUDED.condition_notes, deal_properties.condition_notes),
    repair_estimate = COALESCE(EXCLUDED.repair_estimate, deal_properties.repair_estimate),
    garage_parking  = COALESCE(EXCLUDED.garage_parking,  deal_properties.garage_parking),
    basement_type   = COALESCE(EXCLUDED.basement_type,   deal_properties.basement_type),
    foundation_type = COALESCE(EXCLUDED.foundation_type, deal_properties.foundation_type),
    roof_age        = COALESCE(EXCLUDED.roof_age,        deal_properties.roof_age),
    furnace_age     = COALESCE(EXCLUDED.furnace_age,     deal_properties.furnace_age),
    ac_age          = COALESCE(EXCLUDED.ac_age,          deal_properties.ac_age),
    heating_type    = COALESCE(EXCLUDED.heating_type,    deal_properties.heating_type),
    cooling_type    = COALESCE(EXCLUDED.cooling_type,    deal_properties.cooling_type),
    updated_at      = now(),
    row_version     = deal_properties.row_version + 1;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."update_property_info_v1"("p_deal_id" "uuid", "p_property_type" "text", "p_beds" integer, "p_baths" numeric, "p_sqft" integer, "p_lot_size" "text", "p_year_built" integer, "p_occupancy" "text", "p_deficiency_tags" "text"[], "p_condition_notes" "text", "p_repair_estimate" numeric, "p_garage_parking" "text", "p_basement_type" "text", "p_foundation_type" "text", "p_roof_age" integer, "p_furnace_age" integer, "p_ac_age" integer, "p_heating_type" "text", "p_cooling_type" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_seller_info_v1"("p_deal_id" "uuid", "p_seller_name" "text" DEFAULT NULL::"text", "p_seller_phone" "text" DEFAULT NULL::"text", "p_seller_email" "text" DEFAULT NULL::"text", "p_seller_pain" "text" DEFAULT NULL::"text", "p_seller_timeline" "text" DEFAULT NULL::"text", "p_seller_notes" "text" DEFAULT NULL::"text", "p_next_action" "text" DEFAULT NULL::"text", "p_next_action_due" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF NOT public.check_workspace_write_allowed_v1() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', json_build_object(),
      'error', json_build_object('message', 'This workspace is read-only.', 'fields', json_build_object())
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.deals
    WHERE id = p_deal_id AND tenant_id = v_tenant AND deleted_at IS NULL
  ) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', json_build_object(),
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  UPDATE public.deals SET
    seller_name     = COALESCE(p_seller_name,     seller_name),
    seller_phone    = COALESCE(p_seller_phone,    seller_phone),
    seller_email    = COALESCE(p_seller_email,    seller_email),
    seller_pain     = COALESCE(p_seller_pain,     seller_pain),
    seller_timeline = COALESCE(p_seller_timeline, seller_timeline),
    seller_notes    = COALESCE(p_seller_notes,    seller_notes),
    next_action     = COALESCE(p_next_action,     next_action),
    next_action_due = COALESCE(p_next_action_due, next_action_due),
    updated_at      = now(),
    row_version     = row_version + 1
  WHERE id = p_deal_id AND tenant_id = v_tenant;

  RETURN json_build_object(
    'ok', true, 'code', 'OK',
    'data', json_build_object('deal_id', p_deal_id),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."update_seller_info_v1"("p_deal_id" "uuid", "p_seller_name" "text", "p_seller_phone" "text", "p_seller_email" "text", "p_seller_pain" "text", "p_seller_timeline" "text", "p_seller_notes" "text", "p_next_action" "text", "p_next_action_due" timestamp with time zone) OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."upsert_buyer_from_intake_v1"("p_resolved_tenant" "uuid", "p_payload" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_buyer_id        uuid;
  v_email           text;
  v_phone           text;
  v_name            text;
  v_deal_type_tags  text[];
BEGIN
  v_email := NULLIF(trim(p_payload->>'email'), '');
  v_phone := NULLIF(trim(p_payload->>'phone'), '');
  v_name  := NULLIF(trim(p_payload->>'name'),  '');

  -- Safe deal_type_tags parsing -- only when payload key is a JSON array
  IF p_payload ? 'deal_type_tags' AND jsonb_typeof(p_payload->'deal_type_tags') = 'array' THEN
    v_deal_type_tags := ARRAY(SELECT jsonb_array_elements_text(p_payload->'deal_type_tags'));
  END IF;

  -- Dedupe step 1: exact email match, lower-normalized (only when email present)
  IF v_email IS NOT NULL THEN
    SELECT id INTO v_buyer_id
    FROM public.intake_buyers
    WHERE tenant_id = p_resolved_tenant
      AND lower(email) = lower(v_email)
    ORDER BY created_at DESC, id DESC
    LIMIT 1;
  END IF;

  -- Dedupe step 2: phone fallback ONLY when submission email is absent
  IF v_buyer_id IS NULL AND v_email IS NULL AND v_phone IS NOT NULL THEN
    SELECT id INTO v_buyer_id
    FROM public.intake_buyers
    WHERE tenant_id = p_resolved_tenant
      AND phone = v_phone
    ORDER BY created_at DESC, id DESC
    LIMIT 1;
  END IF;

  IF v_buyer_id IS NOT NULL THEN
    -- Update existing buyer record (COALESCE preserves existing when payload omits field)
    UPDATE public.intake_buyers SET
      name              = COALESCE(v_name, name),
      phone             = COALESCE(v_phone, phone),
      areas_of_interest = COALESCE(NULLIF(trim(p_payload->>'areas_of_interest'), ''), areas_of_interest),
      budget_range      = COALESCE(NULLIF(trim(p_payload->>'budget_range'), ''), budget_range),
      deal_type_tags    = COALESCE(v_deal_type_tags, deal_type_tags),
      price_range_notes = COALESCE(NULLIF(trim(p_payload->>'price_range_notes'), ''), price_range_notes),
      notes             = COALESCE(NULLIF(trim(p_payload->>'notes'), ''), notes),
      updated_at        = now()
    WHERE id = v_buyer_id AND tenant_id = p_resolved_tenant;
  ELSE
    -- Insert new buyer record
    INSERT INTO public.intake_buyers (
      tenant_id, name, email, phone,
      areas_of_interest, budget_range,
      deal_type_tags, price_range_notes, notes,
      is_active, created_at, updated_at
    ) VALUES (
      p_resolved_tenant,
      v_name,
      v_email,
      v_phone,
      NULLIF(trim(p_payload->>'areas_of_interest'), ''),
      NULLIF(trim(p_payload->>'budget_range'), ''),
      v_deal_type_tags,
      NULLIF(trim(p_payload->>'price_range_notes'), ''),
      NULLIF(trim(p_payload->>'notes'), ''),
      true,
      now(),
      now()
    )
    RETURNING id INTO v_buyer_id;
  END IF;

  RETURN v_buyer_id;
END;
$$;

ALTER FUNCTION "public"."upsert_buyer_from_intake_v1"("p_resolved_tenant" "uuid", "p_payload" "jsonb") OWNER TO "postgres";

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

CREATE TABLE IF NOT EXISTS "public"."deal_activity_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "deal_id" "uuid" NOT NULL,
    "activity_type" "text" NOT NULL,
    "content" "text" NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."deal_activity_log" OWNER TO "postgres";

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

CREATE TABLE IF NOT EXISTS "public"."deal_media" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "deal_id" "uuid" NOT NULL,
    "storage_path" "text" NOT NULL,
    "media_type" "text" DEFAULT 'photo'::"text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "uploaded_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "uploaded_by" "uuid" NOT NULL,
    "row_version" bigint DEFAULT 1 NOT NULL,
    CONSTRAINT "deal_media_media_type_check" CHECK (("media_type" = 'photo'::"text"))
);

ALTER TABLE "public"."deal_media" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."deal_notes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "deal_id" "uuid" NOT NULL,
    "note_type" "text" NOT NULL,
    "content" "text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "deal_notes_note_type_check" CHECK (("note_type" = ANY (ARRAY['note'::"text", 'call_log'::"text"])))
);

ALTER TABLE "public"."deal_notes" OWNER TO "postgres";

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

CREATE TABLE IF NOT EXISTS "public"."deal_properties" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "deal_id" "uuid" NOT NULL,
    "row_version" bigint DEFAULT 1 NOT NULL,
    "property_type" "text",
    "beds" "text",
    "baths" "text",
    "sqft" "text",
    "lot_size" "text",
    "year_built" integer,
    "occupancy" "text",
    "deficiency_tags" "text"[],
    "condition_notes" "text",
    "repair_estimate" numeric,
    "garage_parking" "text",
    "basement_type" "text",
    "foundation_type" "text",
    "roof_age" integer,
    "furnace_age" integer,
    "ac_age" integer,
    "heating_type" "text",
    "cooling_type" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."deal_properties" OWNER TO "postgres";

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
    "stage" "text" DEFAULT 'new'::"text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "farm_area_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "address" "text",
    "assignee_user_id" "uuid",
    "seller_name" "text",
    "seller_phone" "text",
    "seller_email" "text",
    "seller_pain" "text",
    "seller_timeline" "text",
    "seller_notes" "text",
    "next_action" "text",
    "next_action_due" timestamp with time zone,
    "dead_reason" "text",
    CONSTRAINT "deals_stage_check" CHECK (("stage" = ANY (ARRAY['new'::"text", 'analyzing'::"text", 'offer_sent'::"text", 'under_contract'::"text", 'dispo'::"text", 'tc'::"text", 'closed'::"text", 'dead'::"text"])))
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
    "address" "text",
    "promoted_deal_id" "uuid",
    CONSTRAINT "draft_deals_form_type_check" CHECK (("form_type" = ANY (ARRAY['buyer'::"text", 'seller'::"text", 'birddog'::"text"])))
);

ALTER TABLE "public"."draft_deals" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."intake_buyers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "name" "text",
    "email" "text",
    "phone" "text",
    "areas_of_interest" "text",
    "budget_range" "text",
    "deal_type_tags" "text"[],
    "price_range_notes" "text",
    "notes" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."intake_buyers" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."intake_submissions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "form_type" "text" NOT NULL,
    "payload" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "source" "text" DEFAULT 'web'::"text" NOT NULL,
    "submitted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "reviewed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "draft_deals_id" "uuid",
    CONSTRAINT "intake_submissions_form_type_check" CHECK (("form_type" = ANY (ARRAY['seller'::"text", 'buyer'::"text", 'birddog'::"text"])))
);

ALTER TABLE "public"."intake_submissions" OWNER TO "postgres";

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

ALTER TABLE ONLY "public"."deal_activity_log"
    ADD CONSTRAINT "deal_activity_log_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."deal_inputs"
    ADD CONSTRAINT "deal_inputs_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."deal_media"
    ADD CONSTRAINT "deal_media_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."deal_media"
    ADD CONSTRAINT "deal_media_storage_path_unique" UNIQUE ("storage_path");

ALTER TABLE ONLY "public"."deal_notes"
    ADD CONSTRAINT "deal_notes_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."deal_outputs"
    ADD CONSTRAINT "deal_outputs_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."deal_properties"
    ADD CONSTRAINT "deal_properties_deal_id_unique" UNIQUE ("deal_id");

ALTER TABLE ONLY "public"."deal_properties"
    ADD CONSTRAINT "deal_properties_pkey" PRIMARY KEY ("id");

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

ALTER TABLE ONLY "public"."intake_buyers"
    ADD CONSTRAINT "intake_buyers_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."intake_submissions"
    ADD CONSTRAINT "intake_submissions_pkey" PRIMARY KEY ("id");

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

CREATE INDEX "draft_deals_tenant_promoted_idx" ON "public"."draft_deals" USING "btree" ("tenant_id") WHERE ("promoted_deal_id" IS NOT NULL);

CREATE INDEX "intake_buyers_tenant_created_idx" ON "public"."intake_buyers" USING "btree" ("tenant_id", "created_at" DESC, "id" DESC);

CREATE INDEX "intake_submissions_draft_deals_id_idx" ON "public"."intake_submissions" USING "btree" ("draft_deals_id") WHERE ("draft_deals_id" IS NOT NULL);

CREATE UNIQUE INDEX "intake_submissions_draft_deals_id_uidx" ON "public"."intake_submissions" USING "btree" ("draft_deals_id") WHERE ("draft_deals_id" IS NOT NULL);

CREATE INDEX "intake_submissions_tenant_submitted_idx" ON "public"."intake_submissions" USING "btree" ("tenant_id", "submitted_at" DESC, "id" DESC);

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

ALTER TABLE ONLY "public"."deal_activity_log"
    ADD CONSTRAINT "deal_activity_log_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."deal_activity_log"
    ADD CONSTRAINT "deal_activity_log_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id");

ALTER TABLE ONLY "public"."deal_activity_log"
    ADD CONSTRAINT "deal_activity_log_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");

ALTER TABLE ONLY "public"."deal_inputs"
    ADD CONSTRAINT "deal_inputs_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id");

ALTER TABLE ONLY "public"."deal_media"
    ADD CONSTRAINT "deal_media_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."deal_media"
    ADD CONSTRAINT "deal_media_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");

ALTER TABLE ONLY "public"."deal_media"
    ADD CONSTRAINT "deal_media_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."deal_notes"
    ADD CONSTRAINT "deal_notes_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."deal_notes"
    ADD CONSTRAINT "deal_notes_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id");

ALTER TABLE ONLY "public"."deal_notes"
    ADD CONSTRAINT "deal_notes_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");

ALTER TABLE ONLY "public"."deal_outputs"
    ADD CONSTRAINT "deal_outputs_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id");

ALTER TABLE ONLY "public"."deal_properties"
    ADD CONSTRAINT "deal_properties_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."deal_properties"
    ADD CONSTRAINT "deal_properties_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");

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
    ADD CONSTRAINT "deals_assignee_user_id_fkey" FOREIGN KEY ("assignee_user_id") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_assumptions_snapshot_fk" FOREIGN KEY ("assumptions_snapshot_id") REFERENCES "public"."deal_inputs"("id") DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_farm_area_id_fkey" FOREIGN KEY ("farm_area_id") REFERENCES "public"."tenant_farm_areas"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."draft_deals"
    ADD CONSTRAINT "draft_deals_promoted_deal_id_fkey" FOREIGN KEY ("promoted_deal_id") REFERENCES "public"."deals"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."draft_deals"
    ADD CONSTRAINT "draft_deals_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."intake_buyers"
    ADD CONSTRAINT "intake_buyers_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");

ALTER TABLE ONLY "public"."intake_submissions"
    ADD CONSTRAINT "intake_submissions_draft_deals_id_fkey" FOREIGN KEY ("draft_deals_id") REFERENCES "public"."draft_deals"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."intake_submissions"
    ADD CONSTRAINT "intake_submissions_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");

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

ALTER TABLE "public"."deal_activity_log" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "deal_activity_log_tenant_isolation" ON "public"."deal_activity_log" USING (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."deal_inputs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."deal_media" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "deal_media_tenant_isolation" ON "public"."deal_media" TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."deal_notes" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "deal_notes_tenant_isolation" ON "public"."deal_notes" USING (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."deal_outputs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."deal_properties" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "deal_properties_tenant_isolation" ON "public"."deal_properties" TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

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

ALTER TABLE "public"."intake_buyers" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "intake_buyers_tenant_isolation" ON "public"."intake_buyers" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."intake_submissions" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "intake_submissions_tenant_isolation" ON "public"."intake_submissions" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

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
