-- 10.8.11I2: Corrective fix tests for get_workspace_settings_v1
-- Proves workspace_name, country, currency, measurement_unit read from public.tenants
BEGIN;

SELECT plan(5);

-- Seed tenant with actual values
INSERT INTO public.tenants (id, name, country, currency, measurement_unit)
VALUES (
  'b0000000-0000-0000-0000-000000000002',
  'Test Workspace',
  'CA',
  'CAD',
  'sqft'
);

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (
  'd0000000-0000-0000-0000-000000000022',
  'b0000000-0000-0000-0000-000000000002',
  'a0000000-0000-0000-0000-000000000001',
  'admin'
);

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES ('b0000000-0000-0000-0000-000000000002', 'ws-beta')
ON CONFLICT (tenant_id) DO UPDATE SET slug = EXCLUDED.slug;

SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'b0000000-0000-0000-0000-000000000002';

-- 1. workspace_name matches tenant row
SELECT is(
  (SELECT public.get_workspace_settings_v1() -> 'data' ->> 'workspace_name'),
  'Test Workspace',
  'workspace_name sourced from public.tenants.name'
);

-- 2. country matches tenant row
SELECT is(
  (SELECT public.get_workspace_settings_v1() -> 'data' ->> 'country'),
  'CA',
  'country sourced from public.tenants.country'
);

-- 3. currency matches tenant row
SELECT is(
  (SELECT public.get_workspace_settings_v1() -> 'data' ->> 'currency'),
  'CAD',
  'currency sourced from public.tenants.currency'
);

-- 4. measurement_unit matches tenant row
SELECT is(
  (SELECT public.get_workspace_settings_v1() -> 'data' ->> 'measurement_unit'),
  'sqft',
  'measurement_unit sourced from public.tenants.measurement_unit'
);

-- 5. no tenant context returns NOT_AUTHORIZED
RESET ROLE;
RESET "app.tenant_id";
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;

SELECT is(
  (SELECT public.get_workspace_settings_v1() ->> 'code'),
  'NOT_AUTHORIZED',
  'returns NOT_AUTHORIZED with no tenant context'
);

SELECT finish();
ROLLBACK;