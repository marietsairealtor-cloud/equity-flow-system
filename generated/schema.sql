

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

CREATE OR REPLACE FUNCTION "public"."activity_log_append_only"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RAISE EXCEPTION 'activity_log_append_only: mutations are not permitted on activity_log';
END;
$$;

ALTER FUNCTION "public"."activity_log_append_only"() OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."complete_reminder_v1"("p_reminder_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
BEGIN
  -- Role enforcement first (CONTRACTS S8, Build Route 7.8)
  -- Caught and returned as JSON envelope per RPC contract
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
    );
  END;

  v_tenant := public.current_tenant_id();

  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF p_reminder_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  null,
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('reminder_id', 'Required'))
    );
  END IF;

  UPDATE public.deal_reminders
  SET completed_at = now()
  WHERE id = p_reminder_id
    AND tenant_id = v_tenant
    AND completed_at IS NULL;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('id', p_reminder_id),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."complete_reminder_v1"("p_reminder_id" "uuid") OWNER TO "postgres";

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
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  -- Generate snapshot id
  v_snapshot_id := gen_random_uuid();

  -- Step 1: Insert deal with snapshot id up-front (FK is DEFERRABLE; deal_inputs row may be inserted later in txn)
INSERT INTO public.deals (id, tenant_id, row_version, calc_version, assumptions_snapshot_id)
VALUES (p_id, v_tenant, 1, p_calc_version, v_snapshot_id);
  INSERT INTO public.deal_inputs (id, tenant_id, deal_id, calc_version, row_version, assumptions)
  VALUES (v_snapshot_id, v_tenant, p_id, p_calc_version, 1, p_assumptions);

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'id',                    p_id,
      'tenant_id',             v_tenant,
      'assumptions_snapshot_id', v_snapshot_id
    ),
    'error', null
  );
EXCEPTION WHEN unique_violation THEN
  RETURN json_build_object(
    'ok',    false,
    'code',  'CONFLICT',
    'data',  null,
    'error', json_build_object('message', 'Deal already exists', 'fields', json_build_object())
  );
END;
$$;

ALTER FUNCTION "public"."create_deal_v1"("p_id" "uuid", "p_calc_version" integer, "p_assumptions" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_reminder_v1"("p_deal_id" "uuid", "p_reminder_date" timestamp with time zone, "p_reminder_type" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant      uuid;
  v_reminder_id uuid;
BEGIN
  -- Role enforcement first (CONTRACTS S8, Build Route 7.8)
  -- Caught and returned as JSON envelope per RPC contract
  BEGIN
    PERFORM public.require_min_role_v1('member');
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'Not authorized', 'fields', json_build_object())
    );
  END;

  v_tenant := public.current_tenant_id();

  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  null,
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('deal_id', 'Required'))
    );
  END IF;

  IF p_reminder_date IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  null,
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('reminder_date', 'Required'))
    );
  END IF;

  IF p_reminder_type IS NULL OR trim(p_reminder_type) = '' THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  null,
      'error', json_build_object('message', 'Invalid input', 'fields', json_build_object('reminder_type', 'Required'))
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = p_deal_id AND d.tenant_id = v_tenant
  ) THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  null,
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;

  INSERT INTO public.deal_reminders (deal_id, tenant_id, reminder_date, reminder_type)
  VALUES (p_deal_id, v_tenant, p_reminder_date, p_reminder_type)
  RETURNING id INTO v_reminder_id;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('id', v_reminder_id),
    'error', null
  );
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
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;
  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'deal_id is required', 'fields', json_build_object())
    );
  END IF;
  IF p_expires_at IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'expires_at is required', 'fields', json_build_object())
    );
  END IF;
  IF p_expires_at <= now() THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'expires_at must be in the future', 'fields', json_build_object())
    );
  END IF;
  -- 9.7: Maximum lifetime invariant - tokens cannot exceed 90 days
  IF p_expires_at > now() + interval '90 days' THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object(
        'message', 'expires_at exceeds maximum allowed lifetime of 90 days',
        'fields', json_build_object('expires_at', 'Maximum token lifetime is 90 days')
      )
    );
  END IF;
  -- Verify deal belongs to tenant
  IF NOT EXISTS (
    SELECT 1 FROM public.deals
    WHERE id = p_deal_id AND tenant_id = v_tenant_id
  ) THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Deal not found', 'fields', json_build_object())
    );
  END IF;
  -- 9.5: Cardinality guard - count active tokens for this deal
  SELECT count(*)::int
  INTO v_active_count
  FROM public.share_tokens
  WHERE deal_id   = p_deal_id
    AND tenant_id = v_tenant_id
    AND revoked_at IS NULL
    AND expires_at > now();
  IF v_active_count >= v_max_tokens THEN
    RETURN json_build_object(
      'ok', false, 'code', 'CONFLICT', 'data', null,
      'error', json_build_object(
        'message', 'Active token limit reached for this resource',
        'fields', json_build_object()
      )
    );
  END IF;
  -- Generate token: shr_ prefix + 32 random bytes as hex (256 bits entropy)
  v_token := 'shr_' || encode(extensions.gen_random_bytes(32), 'hex');
  v_hash  := extensions.digest(v_token, 'sha256');
  INSERT INTO public.share_tokens (tenant_id, deal_id, token_hash, expires_at)
  VALUES (v_tenant_id, p_deal_id, v_hash, p_expires_at);
  -- Return raw token to caller - only time it is ever seen in plaintext
  RETURN json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object(
      'token',      v_token,
      'expires_at', p_expires_at
    ),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."create_share_token_v1"("p_deal_id" "uuid", "p_expires_at" timestamp with time zone) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."current_tenant_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT COALESCE(
    nullif(current_setting('request.jwt.claim.tenant_id', true), '')::uuid,
    (nullif(current_setting('request.jwt.claims', true), '')::json ->> 'tenant_id')::uuid
  )
$$;

ALTER FUNCTION "public"."current_tenant_id"() OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."get_user_entitlements_v1"() RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant              uuid;
  v_user                uuid;
  v_role                public.tenant_role;
  v_member              boolean;
  v_sub_status          text;
  v_sub_days_remaining  integer;
  v_period_end          timestamptz;
  v_expiring_threshold  integer := 5;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user   := auth.uid();

  IF v_tenant IS NULL OR v_user IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object(
        'message', 'No tenant or user context',
        'fields',  json_build_object()
      )
    );
  END IF;

  -- Resolve tenant membership
  SELECT tm.role INTO v_role
  FROM public.tenant_memberships tm
  WHERE tm.tenant_id = v_tenant
    AND tm.user_id   = v_user;

  v_member := FOUND;

  -- Resolve subscription status (server-side computation)
  SELECT ts.status, ts.current_period_end
  INTO v_sub_status, v_period_end
  FROM public.tenant_subscriptions ts
  WHERE ts.tenant_id = v_tenant;

  IF NOT FOUND THEN
    -- No subscription record
    v_sub_status         := 'none';
    v_sub_days_remaining := null;
  ELSIF v_sub_status = 'canceled' OR v_period_end <= now() THEN
    -- Canceled or past period end -- expired
    v_sub_status         := 'expired';
    v_sub_days_remaining := EXTRACT(DAY FROM (v_period_end - now()))::integer;
  ELSIF v_sub_status IN ('active', 'expiring') THEN
    -- Compute days remaining
    v_sub_days_remaining := GREATEST(0, EXTRACT(DAY FROM (v_period_end - now()))::integer);
    -- Expiring threshold: active AND <=5 days remain
    IF v_sub_days_remaining <= v_expiring_threshold THEN
      v_sub_status := 'expiring';
    ELSE
      v_sub_status := 'active';
    END IF;
  ELSE
    -- Fallback for any other stored status
    v_sub_status         := 'none';
    v_sub_days_remaining := null;
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'tenant_id',                v_tenant,
      'user_id',                  v_user,
      'is_member',                v_member,
      'role',                     v_role,
      'entitled',                 v_member,
      'subscription_status',      v_sub_status,
      'subscription_days_remaining', v_sub_days_remaining
    ),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."get_user_entitlements_v1"() OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."lookup_share_token_v1"("p_token" "text", "p_deal_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_tenant_id uuid;
  v_row       record;
  v_hash      bytea;
  v_result    json;
BEGIN
  v_tenant_id := public.current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_AUTHORIZED', 'data', null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;
  IF p_deal_id IS NULL THEN
    RETURN json_build_object(
      'ok', false, 'code', 'VALIDATION_ERROR', 'data', null,
      'error', json_build_object('message', 'deal_id is required', 'fields', json_build_object())
    );
  END IF;
  -- 9.4: Format validation - occurs BEFORE hashing.
  -- Rule 1: prefix must be 'shr_'
  -- Rule 2: body after prefix must be exactly 64 lowercase hex chars
  -- Rule 3: total length >= 68
  -- Returns NOT_FOUND - identical shape to nonexistent token (no format leak).
  IF p_token IS NULL
     OR length(p_token) < 68
     OR left(p_token, 4) <> 'shr_'
     OR substring(p_token FROM 5) !~ '^[0-9a-f]{64}$'
  THEN
    BEGIN
      PERFORM public.foundation_log_activity_v1(
        'share_token_lookup',
        json_build_object('token_hash', null, 'success', false, 'failure_category', 'format_invalid')::jsonb,
        null
      );
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object())
    );
  END IF;
  v_hash := extensions.digest(p_token, 'sha256');
  SELECT st.deal_id, st.expires_at, st.revoked_at, d.calc_version
  INTO v_row
  FROM public.share_tokens st
  JOIN public.deals d ON d.id = st.deal_id AND d.tenant_id = st.tenant_id
  WHERE st.token_hash = v_hash
    AND st.tenant_id  = v_tenant_id
    AND st.deal_id    = p_deal_id;
  IF NOT FOUND THEN
    v_result := json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object())
    );
    BEGIN
      PERFORM public.foundation_log_activity_v1(
        'share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'not_found')::jsonb,
        null
      );
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN v_result;
  END IF;
  -- Revocation check first (overrides expiration per 8.6)
  IF v_row.revoked_at IS NOT NULL THEN
    v_result := json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object())
    );
    BEGIN
      PERFORM public.foundation_log_activity_v1(
        'share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'revoked')::jsonb,
        null
      );
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN v_result;
  END IF;
  -- Expiration check - returns NOT_FOUND (no existence leak per 8.9)
  IF v_row.expires_at <= now() THEN
    v_result := json_build_object(
      'ok', false, 'code', 'NOT_FOUND', 'data', null,
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object())
    );
    BEGIN
      PERFORM public.foundation_log_activity_v1(
        'share_token_lookup',
        json_build_object('token_hash', encode(v_hash, 'hex'), 'success', false, 'failure_category', 'expired')::jsonb,
        null
      );
    EXCEPTION WHEN OTHERS THEN NULL; END;
    RETURN v_result;
  END IF;
  v_result := json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object(
      'deal_id',      v_row.deal_id,
      'calc_version', v_row.calc_version,
      'expires_at',   v_row.expires_at
    ),
    'error', null
  );
  BEGIN
    PERFORM public.foundation_log_activity_v1(
      'share_token_lookup',
      json_build_object('token_hash', encode(v_hash, 'hex'), 'success', true, 'failure_category', null)::jsonb,
      null
    );
  EXCEPTION WHEN OTHERS THEN NULL; END;
  RETURN v_result;
END;
$_$;

ALTER FUNCTION "public"."lookup_share_token_v1"("p_token" "text", "p_deal_id" "uuid") OWNER TO "postgres";

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
BEGIN
  -- Validate form_type
  IF p_form_type IS NULL OR NOT (p_form_type = ANY(v_valid_types)) THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', null,
      'error', json_build_object(
        'message', 'Invalid form type',
        'fields', json_build_object('form_type', 'Must be buyer, seller, or birddog')
      )
    );
  END IF;

  -- Validate slug
  IF p_slug IS NULL OR p_slug !~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$' THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', null,
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json)
    );
  END IF;

  -- Validate payload present
  IF p_payload IS NULL THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', null,
      'error', json_build_object(
        'message', 'Payload required',
        'fields', json_build_object('payload', 'Required')
      )
    );
  END IF;

  -- Validate spam token present (Turnstile/reCAPTCHA)
  v_spam_token := p_payload->>'spam_token';
  IF v_spam_token IS NULL OR length(trim(v_spam_token)) = 0 THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'VALIDATION_ERROR',
      'data', null,
      'error', json_build_object(
        'message', 'Spam protection token required',
        'fields', json_build_object('spam_token', 'Required')
      )
    );
  END IF;

  -- Resolve slug to tenant
  SELECT ts.tenant_id INTO v_tenant_id
  FROM public.tenant_slugs ts
  WHERE ts.slug = p_slug;

  IF v_tenant_id IS NULL THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'NOT_FOUND',
      'data', null,
      'error', json_build_object('message', 'Not found', 'fields', '{}'::json)
    );
  END IF;

  -- Extract MAO pre-fill fields from seller submissions
  IF p_form_type = 'seller' THEN
    v_asking_price := (p_payload->>'asking_price')::numeric;
    v_repair_est   := (p_payload->>'repair_estimate')::numeric;
  END IF;

  -- Insert draft deal record
  INSERT INTO public.draft_deals (
    tenant_id,
    slug,
    form_type,
    payload,
    asking_price,
    repair_estimate
  ) VALUES (
    v_tenant_id,
    p_slug,
    p_form_type,
    p_payload,
    v_asking_price,
    v_repair_est
  )
  RETURNING id INTO v_draft_id;

  RETURN json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object('draft_id', v_draft_id),
    'error', null
  );
END;
$_$;

ALTER FUNCTION "public"."submit_form_v1"("p_slug" "text", "p_form_type" "text", "p_payload" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_deal_v1"("p_id" "uuid", "p_expected_row_version" bigint, "p_calc_version" integer DEFAULT NULL::integer) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant      uuid;
  v_rows_updated int;
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

  UPDATE public.deals
  SET
    row_version  = row_version + 1,
    calc_version = COALESCE(p_calc_version, calc_version)
  WHERE id         = p_id
    AND tenant_id  = v_tenant
    AND row_version = p_expected_row_version;

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    -- Either row does not exist for this tenant, or row_version mismatch
    RETURN json_build_object(
      'ok',    false,
      'code',  'CONFLICT',
      'data',  null,
      'error', json_build_object('message', 'Row version mismatch or deal not found', 'fields', json_build_object())
    );
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object('id', p_id, 'row_version', p_expected_row_version + 1),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."update_deal_v1"("p_id" "uuid", "p_expected_row_version" bigint, "p_calc_version" integer) OWNER TO "postgres";

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

CREATE TABLE IF NOT EXISTS "public"."deals" (
    "id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "row_version" bigint DEFAULT 1 NOT NULL,
    "calc_version" integer DEFAULT 1 NOT NULL,
    "assumptions_snapshot_id" "uuid",
    "stage" "text" DEFAULT 'New'::"text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "deals_stage_check" CHECK (("stage" = ANY (ARRAY['New'::"text", 'Analyzing'::"text", 'Offer Sent'::"text", 'Under Contract (UC)'::"text", 'Dispo'::"text", 'Closed'::"text", 'Dead'::"text"])))
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
    CONSTRAINT "tenant_subscriptions_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'expiring'::"text", 'expired'::"text", 'canceled'::"text"])))
);

ALTER TABLE "public"."tenant_subscriptions" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."tenants" (
    "id" "uuid" NOT NULL
);

ALTER TABLE "public"."tenants" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."user_profiles" (
    "id" "uuid" NOT NULL
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

ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."draft_deals"
    ADD CONSTRAINT "draft_deals_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."share_tokens"
    ADD CONSTRAINT "share_tokens_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tenant_memberships"
    ADD CONSTRAINT "tenant_memberships_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tenant_memberships"
    ADD CONSTRAINT "tenant_memberships_tenant_user_unique" UNIQUE ("tenant_id", "user_id");

ALTER TABLE ONLY "public"."tenant_slugs"
    ADD CONSTRAINT "tenant_slugs_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tenant_slugs"
    ADD CONSTRAINT "tenant_slugs_slug_unique" UNIQUE ("slug");

ALTER TABLE ONLY "public"."tenant_subscriptions"
    ADD CONSTRAINT "tenant_subscriptions_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tenant_subscriptions"
    ADD CONSTRAINT "tenant_subscriptions_tenant_id_unique" UNIQUE ("tenant_id");

ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "tenants_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."user_profiles"
    ADD CONSTRAINT "user_profiles_pkey" PRIMARY KEY ("id");

CREATE UNIQUE INDEX "share_tokens_token_hash_unique" ON "public"."share_tokens" USING "btree" ("token_hash");

CREATE OR REPLACE TRIGGER "activity_log_no_delete" BEFORE DELETE ON "public"."activity_log" FOR EACH ROW EXECUTE FUNCTION "public"."activity_log_append_only"();

CREATE OR REPLACE TRIGGER "activity_log_no_update" BEFORE UPDATE ON "public"."activity_log" FOR EACH ROW EXECUTE FUNCTION "public"."activity_log_append_only"();

CREATE OR REPLACE TRIGGER "deal_inputs_tenant_match" BEFORE INSERT OR UPDATE ON "public"."deal_inputs" FOR EACH ROW EXECUTE FUNCTION "public"."check_deal_tenant_match"();

CREATE OR REPLACE TRIGGER "deal_outputs_tenant_match" BEFORE INSERT OR UPDATE ON "public"."deal_outputs" FOR EACH ROW EXECUTE FUNCTION "public"."check_deal_tenant_match"();

CREATE CONSTRAINT TRIGGER "deals_snapshot_not_null" AFTER INSERT OR UPDATE ON "public"."deals" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION "public"."check_deal_snapshot_not_null"();

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

ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_assumptions_snapshot_fk" FOREIGN KEY ("assumptions_snapshot_id") REFERENCES "public"."deal_inputs"("id") DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY "public"."draft_deals"
    ADD CONSTRAINT "draft_deals_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."share_tokens"
    ADD CONSTRAINT "share_tokens_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id");

ALTER TABLE ONLY "public"."tenant_memberships"
    ADD CONSTRAINT "tenant_memberships_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");

ALTER TABLE ONLY "public"."tenant_slugs"
    ADD CONSTRAINT "tenant_slugs_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."tenant_subscriptions"
    ADD CONSTRAINT "tenant_subscriptions_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE "public"."activity_log" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "activity_log_insert_own" ON "public"."activity_log" FOR INSERT TO "authenticated" WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "activity_log_select_own" ON "public"."activity_log" FOR SELECT TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."calc_versions" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."deal_inputs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."deal_outputs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."deal_reminders" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."deals" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "deals_delete_own" ON "public"."deals" FOR DELETE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deals_insert_own" ON "public"."deals" FOR INSERT TO "authenticated" WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deals_select_own" ON "public"."deals" FOR SELECT TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deals_update_own" ON "public"."deals" FOR UPDATE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."draft_deals" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."share_tokens" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."tenant_memberships" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant_memberships_delete_own" ON "public"."tenant_memberships" FOR DELETE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "tenant_memberships_insert_own" ON "public"."tenant_memberships" FOR INSERT TO "authenticated" WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "tenant_memberships_select_own" ON "public"."tenant_memberships" FOR SELECT TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "tenant_memberships_update_own" ON "public"."tenant_memberships" FOR UPDATE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."tenant_slugs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."tenant_subscriptions" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."tenants" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."user_profiles" ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON FUNCTION "public"."current_tenant_id"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "public"."get_user_entitlements_v1"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_user_entitlements_v1"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."list_deals_v1"("p_limit" integer, "p_cursor" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_deals_v1"("p_limit" integer, "p_cursor" "text") TO "authenticated";

GRANT SELECT,UPDATE ON TABLE "public"."user_profiles" TO "authenticated";
