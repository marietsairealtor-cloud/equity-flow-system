

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

CREATE OR REPLACE FUNCTION "public"."create_deal_v1"("p_id" "uuid", "p_row_version" bigint DEFAULT 1, "p_calc_version" integer DEFAULT 1) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
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

  INSERT INTO public.deals (id, tenant_id, row_version, calc_version)
  VALUES (p_id, v_tenant, p_row_version, p_calc_version);

  RETURN json_build_object(
    'ok', true,
    'code', 'OK',
    'data', json_build_object('id', p_id, 'tenant_id', v_tenant),
    'error', null
  );
EXCEPTION WHEN unique_violation THEN
  RETURN json_build_object(
    'ok', false,
    'code', 'CONFLICT',
    'data', null,
    'error', json_build_object('message', 'Deal already exists', 'fields', json_build_object())
  );
END;
$$;

ALTER FUNCTION "public"."create_deal_v1"("p_id" "uuid", "p_row_version" bigint, "p_calc_version" integer) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."current_tenant_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT COALESCE(
    nullif(current_setting('request.jwt.claim.tenant_id', true), '')::uuid,
    (nullif(current_setting('request.jwt.claims', true), '')::json ->> 'tenant_id')::uuid
  )
$$;

ALTER FUNCTION "public"."current_tenant_id"() OWNER TO "postgres";

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

SET default_tablespace = '';

SET default_table_access_method = "heap";

CREATE TABLE IF NOT EXISTS "public"."deals" (
    "id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "row_version" bigint,
    "calc_version" integer
);

ALTER TABLE "public"."deals" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."tenant_memberships" (
    "id" "uuid" NOT NULL
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

ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tenant_memberships"
    ADD CONSTRAINT "tenant_memberships_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "tenants_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."user_profiles"
    ADD CONSTRAINT "user_profiles_pkey" PRIMARY KEY ("id");

ALTER TABLE "public"."deals" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "deals_delete_own" ON "public"."deals" FOR DELETE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deals_insert_own" ON "public"."deals" FOR INSERT TO "authenticated" WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deals_select_own" ON "public"."deals" FOR SELECT TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "deals_update_own" ON "public"."deals" FOR UPDATE TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));

ALTER TABLE "public"."tenant_memberships" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."tenants" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."user_profiles" ENABLE ROW LEVEL SECURITY;

GRANT ALL ON FUNCTION "public"."list_deals_v1"("p_limit" integer) TO "authenticated";

GRANT SELECT,UPDATE ON TABLE "public"."user_profiles" TO "authenticated";
