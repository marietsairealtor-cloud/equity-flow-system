

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

CREATE OR REPLACE FUNCTION "public"."current_tenant_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT COALESCE(
    nullif(current_setting('request.jwt.claim.tenant_id', true), '')::uuid,
    (nullif(current_setting('request.jwt.claims', true), '')::json ->> 'tenant_id')::uuid
  )
$$;

ALTER FUNCTION "public"."current_tenant_id"() OWNER TO "postgres";

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

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."deals" TO "authenticated";

GRANT SELECT,UPDATE ON TABLE "public"."user_profiles" TO "authenticated";
