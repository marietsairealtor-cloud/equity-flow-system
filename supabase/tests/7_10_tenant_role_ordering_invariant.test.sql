-- =============================================================
-- pgTAP: 7.10 — Freeze tenant_role ordering + role-guard semantics
-- Build Route v2.4 item 7.10
-- Authority: CONTRACTS.md §9 (enum ordering: owner(0) < admin(1) < member(2))
-- GUARDRAILS §25-28: SQL-only, no DO blocks, no PL/pgSQL, named dollar tags only
-- =============================================================

BEGIN;

SELECT plan(8);

-- -----------------------------------------------------------------
-- SECTION 1: Enum label ordering invariant
-- Assert tenant_role labels are exactly: owner, admin, member
-- in that exact ordinal position.
-- -----------------------------------------------------------------

-- 1) Enum exists
SELECT has_type('public', 'tenant_role', 'Enum type public.tenant_role must exist');

-- 2) Exactly 3 labels
SELECT is(
    (SELECT count(*)::int FROM pg_enum e
     JOIN pg_type t ON e.enumtypid = t.oid
     WHERE t.typname = 'tenant_role' AND t.typnamespace = 'public'::regnamespace),
    3,
    'tenant_role must have exactly 3 labels'
);

-- 3) Labels in exact order: owner < admin < member
SELECT is(
    (SELECT array_agg(e.enumlabel::text ORDER BY e.enumsortorder)
     FROM pg_enum e
     JOIN pg_type t ON e.enumtypid = t.oid
     WHERE t.typname = 'tenant_role' AND t.typnamespace = 'public'::regnamespace),
    ARRAY['owner', 'admin', 'member'],
    'tenant_role labels must be in exact order: owner < admin < member'
);

-- 4) Ordinal position confirms owner < admin < member numerically
SELECT ok(
    (SELECT (min(e.enumsortorder) FILTER (WHERE e.enumlabel = 'owner'))
          < (min(e.enumsortorder) FILTER (WHERE e.enumlabel = 'admin'))
        AND (min(e.enumsortorder) FILTER (WHERE e.enumlabel = 'admin'))
          < (min(e.enumsortorder) FILTER (WHERE e.enumlabel = 'member'))
     FROM pg_enum e
     JOIN pg_type t ON e.enumtypid = t.oid
     WHERE t.typname = 'tenant_role' AND t.typnamespace = 'public'::regnamespace),
    'Enum sort order must satisfy: owner < admin < member'
);

-- -----------------------------------------------------------------
-- SECTION 2: require_min_role_v1() semantics (CONTRACTS.md §9)
--
-- Contract: Authorization fails when v_role > p_min
--   owner satisfies admin requirement  -> PASS (no exception)
--   admin satisfies admin requirement  -> PASS (no exception)
--   member fails admin requirement     -> NOT_AUTHORIZED
--
-- current_tenant_id() reads request.jwt.claim.tenant_id
-- auth.uid() reads request.jwt.claim.sub
-- require_min_role_v1() looks up caller role in tenant_memberships
-- -----------------------------------------------------------------

-- 5) Function exists with expected signature
SELECT has_function(
    'public',
    'require_min_role_v1',
    ARRAY['tenant_role'],
    'public.require_min_role_v1(tenant_role) must exist'
);

-- Seed test data

-- Test tenant
INSERT INTO public.tenants (id)
VALUES ('a0000000-0000-0000-0000-000000000710'::uuid);

-- Test users in auth.users
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, aud, role)
VALUES
    ('b0000000-0000-0000-0000-000000000001'::uuid, 'owner710@test.local', 'unused', now(), '{}', '{}', 'authenticated', 'authenticated'),
    ('b0000000-0000-0000-0000-000000000002'::uuid, 'admin710@test.local', 'unused', now(), '{}', '{}', 'authenticated', 'authenticated'),
    ('b0000000-0000-0000-0000-000000000003'::uuid, 'member710@test.local', 'unused', now(), '{}', '{}', 'authenticated', 'authenticated');

-- Tenant memberships with explicit id and different roles
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES
    ('c0000000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-000000000710'::uuid, 'b0000000-0000-0000-0000-000000000001'::uuid, 'owner'),
    ('c0000000-0000-0000-0000-000000000002'::uuid, 'a0000000-0000-0000-0000-000000000710'::uuid, 'b0000000-0000-0000-0000-000000000002'::uuid, 'admin'),
    ('c0000000-0000-0000-0000-000000000003'::uuid, 'a0000000-0000-0000-0000-000000000710'::uuid, 'b0000000-0000-0000-0000-000000000003'::uuid, 'member');

-- Set tenant context (shared across all three tests)
SELECT set_config('request.jwt.claim.tenant_id', 'a0000000-0000-0000-0000-000000000710', true);

-- 6) owner satisfies admin requirement (PASS)
SELECT set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-000000000001', true);
SELECT lives_ok(
    $tap$SELECT public.require_min_role_v1('admin'::public.tenant_role)$tap$,
    'owner satisfies admin requirement (PASS)'
);

-- 7) admin satisfies admin requirement (PASS)
SELECT set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-000000000002', true);
SELECT lives_ok(
    $tap$SELECT public.require_min_role_v1('admin'::public.tenant_role)$tap$,
    'admin satisfies admin requirement (PASS)'
);

-- 8) member fails admin requirement (NOT_AUTHORIZED)
SELECT set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-000000000003', true);
SELECT throws_ok(
    $tap$SELECT public.require_min_role_v1('admin'::public.tenant_role)$tap$,
    'NOT_AUTHORIZED',
    'member fails admin requirement (NOT_AUTHORIZED)'
);

SELECT finish();

ROLLBACK;