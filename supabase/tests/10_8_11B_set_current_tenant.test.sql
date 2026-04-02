BEGIN;

SELECT plan(9);

-- Seed data
INSERT INTO public.tenants (id) VALUES ('b0000000-0000-0000-0000-000000000001') ON CONFLICT DO NOTHING;
INSERT INTO public.tenants (id) VALUES ('b0000000-0000-0000-0000-000000000002') ON CONFLICT DO NOTHING;
INSERT INTO public.user_profiles (id, current_tenant_id)
  VALUES ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001')
  ON CONFLICT (id) DO UPDATE SET current_tenant_id = EXCLUDED.current_tenant_id;
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'owner')
  ON CONFLICT DO NOTHING;
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
  VALUES ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'member')
  ON CONFLICT DO NOTHING;

-- 1. Function exists
SELECT has_function(
  'public', 'set_current_tenant_v1', ARRAY['uuid'],
  '10.8.11B: set_current_tenant_v1 exists'
);

-- 2. Valid switch returns OK
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;

SELECT is(
  public.set_current_tenant_v1('b0000000-0000-0000-0000-000000000002'::uuid)->>'code',
  'OK',
  '10.8.11B: valid switch returns OK'
);

-- 3. Returns correct tenant_id
SELECT is(
  (public.set_current_tenant_v1('b0000000-0000-0000-0000-000000000002'::uuid)->'data'->>'tenant_id'),
  'b0000000-0000-0000-0000-000000000002',
  '10.8.11B: returns correct tenant_id in data'
);

-- 4. current_tenant_id actually updated in user_profiles
RESET ROLE;
SELECT is(
  (SELECT current_tenant_id::text FROM public.user_profiles WHERE id = 'a0000000-0000-0000-0000-000000000001'),
  'b0000000-0000-0000-0000-000000000002',
  '10.8.11B: current_tenant_id updated in user_profiles'
);
SET LOCAL ROLE authenticated;

-- 5. Non-member tenant rejected
SELECT is(
  public.set_current_tenant_v1('b0000000-0000-0000-0000-000000000099'::uuid)->>'code',
  'NOT_AUTHORIZED',
  '10.8.11B: non-member tenant returns NOT_AUTHORIZED'
);

-- 6. Null tenant_id rejected
SELECT is(
  public.set_current_tenant_v1(NULL::uuid)->>'code',
  'VALIDATION_ERROR',
  '10.8.11B: null tenant_id returns VALIDATION_ERROR'
);

RESET ROLE;
RESET "request.jwt.claims";

-- 7. anon cannot execute
SELECT ok(
  NOT has_function_privilege('anon', 'public.set_current_tenant_v1(uuid)', 'EXECUTE'),
  '10.8.11B: anon cannot EXECUTE set_current_tenant_v1'
);

-- 8. authenticated can execute
SELECT ok(
  has_function_privilege('authenticated', 'public.set_current_tenant_v1(uuid)', 'EXECUTE'),
  '10.8.11B: authenticated can EXECUTE set_current_tenant_v1'
);

-- 9. NOT_AUTHORIZED with no auth context
SELECT is(
  public.set_current_tenant_v1('b0000000-0000-0000-0000-000000000001'::uuid)->>'code',
  'NOT_AUTHORIZED',
  '10.8.11B: returns NOT_AUTHORIZED with no auth context'
);

SELECT * FROM finish();

ROLLBACK;