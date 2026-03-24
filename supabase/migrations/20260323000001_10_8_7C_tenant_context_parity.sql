-- 10.8.7C — Tenant Context Parity Fixes (compensating migration)

-- 1. Add current_tenant_id column
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS current_tenant_id UUID NULL;

-- 2. FK to tenants (idempotent)
DO $ddl$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'user_profiles_current_tenant_id_fkey'
  ) THEN
    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_current_tenant_id_fkey
      FOREIGN KEY (current_tenant_id)
      REFERENCES public.tenants(id)
      ON DELETE SET NULL;
  END IF;
END
$ddl$;

-- 3. Fix current_tenant_id() (no DROP)
CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
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
$fn$;

-- re-apply execute grant
REVOKE ALL ON FUNCTION public.current_tenant_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_tenant_id() TO authenticated;

-- 4. reset grants on user_profiles (controlled exception)
REVOKE ALL ON public.user_profiles FROM anon, authenticated;
GRANT SELECT, UPDATE ON public.user_profiles TO authenticated;

-- 5. self-read policy (idempotent)
DO $ddl$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_profiles'
      AND policyname = 'user_profiles_select_self'
  ) THEN
    CREATE POLICY user_profiles_select_self
      ON public.user_profiles
      FOR SELECT
      TO authenticated
      USING (id = auth.uid());
  END IF;
END
$ddl$;

-- 6. self-update policy (idempotent)
DO $ddl$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_profiles'
      AND policyname = 'user_profiles_update_self'
  ) THEN
    CREATE POLICY user_profiles_update_self
      ON public.user_profiles
      FOR UPDATE
      TO authenticated
      USING (id = auth.uid())
      WITH CHECK (id = auth.uid());
  END IF;
END
$ddl$;