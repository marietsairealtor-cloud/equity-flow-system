

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

CREATE OR REPLACE FUNCTION "public"."current_tenant_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT COALESCE(
    nullif(current_setting('request.jwt.claim.tenant_id', true), '')::uuid,
    (nullif(current_setting('request.jwt.claims', true), '')::json ->> 'tenant_id')::uuid
  )
$$;

ALTER FUNCTION "public"."current_tenant_id"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."foundation_log_activity_v1"("p_tenant_id" "uuid", "p_action" "text", "p_meta" "jsonb" DEFAULT '{}'::"jsonb", "p_actor_id" "uuid" DEFAULT NULL::"uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;

ALTER FUNCTION "public"."foundation_log_activity_v1"("p_tenant_id" "uuid", "p_action" "text", "p_meta" "jsonb", "p_actor_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_deals_v1"("p_limit" integer DEFAULT 25) RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
  v_items json;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    RETURN json_build_object(
      'ok', false,
      'code', 'NOT_AUTHORIZED',
      'data', null,
      'error', json_build_object('message', 'No tenant context', 'fields', json_build_object())
    );
  END IF;

  IF p_limit IS NULL OR p_limit < 1 THEN p_limit := 25; END IF;
  IF p_limit > 100 THEN p_limit := 100; END IF;

  SELECT json_agg(row_to_json(d))
  INTO v_items
  FROM (
    SELECT id, tenant_id, row_version, calc_version
    FROM public.deals
    WHERE tenant_id = v_tenant
    ORDER BY id
    LIMIT p_limit
  ) d;

  RETURN json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object('items', COALESCE(v_items, '[]'::json), 'next_cursor', null),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."list_deals_v1"("p_limit" integer) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."lookup_share_token_v1"("p_tenant_id" "uuid", "p_token" "text") RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_row record;
BEGIN
  -- Validate caller context matches requested tenant (satisfies definer-safety-audit)
  IF p_tenant_id IS NULL OR p_token IS NULL THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'VALIDATION_ERROR',
      'data',  null,
      'error', json_build_object('message', 'tenant_id and token are required', 'fields', json_build_object())
    );
  END IF;

  -- Enforce: caller must have context for requested tenant
  IF public.current_tenant_id() IS DISTINCT FROM p_tenant_id THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_AUTHORIZED',
      'data',  null,
      'error', json_build_object('message', 'Tenant context mismatch', 'fields', json_build_object())
    );
  END IF;

  SELECT st.token, st.deal_id, st.expires_at, d.calc_version
  INTO v_row
  FROM public.share_tokens st
  JOIN public.deals d ON d.id = st.deal_id AND d.tenant_id = st.tenant_id
  WHERE st.token = p_token
    AND st.tenant_id = p_tenant_id;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'NOT_FOUND',
      'data',  null,
      'error', json_build_object('message', 'Token not found for this tenant', 'fields', json_build_object())
    );
  END IF;

  IF v_row.expires_at IS NOT NULL AND v_row.expires_at < now() THEN
    RETURN json_build_object(
      'ok',    false,
      'code',  'TOKEN_EXPIRED',
      'data',  null,
      'error', json_build_object('message', 'Share token has expired', 'fields', json_build_object())
    );
  END IF;

  RETURN json_build_object(
    'ok',   true,
    'code', 'OK',
    'data', json_build_object(
      'token',        v_row.token,
      'deal_id',      v_row.deal_id,
      'calc_version', v_row.calc_version,
      'expires_at',   v_row.expires_at
    ),
    'error', null
  );
END;
$$;

ALTER FUNCTION "public"."lookup_share_token_v1"("p_tenant_id" "uuid", "p_token" "text") OWNER TO "postgres";

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

CREATE TABLE IF NOT EXISTS "public"."deals" (
    "id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "row_version" bigint DEFAULT 1 NOT NULL,
    "calc_version" integer DEFAULT 1 NOT NULL,
    "assumptions_snapshot_id" "uuid"
);

ALTER TABLE "public"."deals" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."share_tokens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "deal_id" "uuid" NOT NULL,
    "token" "text" DEFAULT "encode"("extensions"."gen_random_bytes"(32), 'hex'::"text") NOT NULL,
    "expires_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."share_tokens" OWNER TO "postgres";

CREATE OR REPLACE VIEW "public"."share_token_packet" AS
 SELECT "st"."token",
    "st"."deal_id",
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

ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."share_tokens"
    ADD CONSTRAINT "share_tokens_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."share_tokens"
    ADD CONSTRAINT "share_tokens_tenant_token_unique" UNIQUE ("tenant_id", "token");

ALTER TABLE ONLY "public"."tenant_memberships"
    ADD CONSTRAINT "tenant_memberships_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tenant_memberships"
    ADD CONSTRAINT "tenant_memberships_tenant_user_unique" UNIQUE ("tenant_id", "user_id");

ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "tenants_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."user_profiles"
    ADD CONSTRAINT "user_profiles_pkey" PRIMARY KEY ("id");

CREATE OR REPLACE TRIGGER "deal_inputs_tenant_match" BEFORE INSERT OR UPDATE ON "public"."deal_inputs" FOR EACH ROW EXECUTE FUNCTION "public"."check_deal_tenant_match"();

CREATE OR REPLACE TRIGGER "deal_outputs_tenant_match" BEFORE INSERT OR UPDATE ON "public"."deal_outputs" FOR EACH ROW EXECUTE FUNCTION "public"."check_deal_tenant_match"();

CREATE CONSTRAINT TRIGGER "deals_snapshot_not_null" AFTER INSERT OR UPDATE ON "public"."deals" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION "public"."check_deal_snapshot_not_null"();

ALTER TABLE ONLY "public"."activity_log"
    ADD CONSTRAINT "activity_log_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");

ALTER TABLE ONLY "public"."deal_inputs"
    ADD CONSTRAINT "deal_inputs_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id");

ALTER TABLE ONLY "public"."deal_outputs"
    ADD CONSTRAINT "deal_outputs_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id");

ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_assumptions_snapshot_fk" FOREIGN KEY ("assumptions_snapshot_id") REFERENCES "public"."deal_inputs"("id") DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY "public"."share_tokens"
    ADD CONSTRAINT "share_tokens_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id");

ALTER TABLE ONLY "public"."tenant_memberships"
    ADD CONSTRAINT "tenant_memberships_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");

ALTER TABLE "public"."activity_log" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "activity_log_insert_own" ON "public"."activity_log" FOR INSERT TO "authenticated" WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "activity_log_select_own" ON "public"."activity_log" FOR SELECT TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."calc_versions" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."deal_inputs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."deal_outputs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."deals" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "deals_delete_own" ON "public"."deals" FOR DELETE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deals_insert_own" ON "public"."deals" FOR INSERT TO "authenticated" WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deals_select_own" ON "public"."deals" FOR SELECT TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deals_update_own" ON "public"."deals" FOR UPDATE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."share_tokens" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."tenant_memberships" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant_memberships_delete_own" ON "public"."tenant_memberships" FOR DELETE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "tenant_memberships_insert_own" ON "public"."tenant_memberships" FOR INSERT TO "authenticated" WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "tenant_memberships_select_own" ON "public"."tenant_memberships" FOR SELECT TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "tenant_memberships_update_own" ON "public"."tenant_memberships" FOR UPDATE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."tenants" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."user_profiles" ENABLE ROW LEVEL SECURITY;

GRANT ALL ON FUNCTION "public"."list_deals_v1"("p_limit" integer) TO "authenticated";

GRANT SELECT,UPDATE ON TABLE "public"."user_profiles" TO "authenticated";

