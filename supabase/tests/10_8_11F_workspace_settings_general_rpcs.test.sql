-- 10_8_11F_workspace_settings_general_rpcs.test.sql

BEGIN;

SELECT plan(13);

-- Seed data
INSERT INTO public.tenants (id)
VALUES ('d0000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES ('d0000000-0000-0000-0000-000000000001', 'ws-general-test')
ON CONFLICT (tenant_id) DO UPDATE SET slug = EXCLUDED.slug;

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES
  ('e0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'admin'),
  ('e0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'member')
ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_subscriptions (tenant_id, status, current_period_end)
VALUES ('d0000000-0000-0000-0000-000000000001'::uuid, 'active', now() + interval '1 year');

-- Second tenant for slug conflict + isolation test
INSERT INTO public.tenants (id)
VALUES ('d0000000-0000-0000-0000-000000000002')
ON CONFLICT DO NOTHING;

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES ('d0000000-0000-0000-0000-000000000002', 'ws-taken-slug')
ON CONFLICT (tenant_id) DO UPDATE SET slug = EXCLUDED.slug;

-- Test 1: function exists
SELECT has_function(
  'public',
  'update_workspace_settings_v1',
  ARRAY['text','text','text','text','text'],
  'update_workspace_settings_v1 exists in public schema'
);

-- Test 2: authenticated can execute
SELECT ok(
  has_function_privilege('authenticated', 'public.update_workspace_settings_v1(text,text,text,text,text)', 'EXECUTE'),
  'authenticated can execute update_workspace_settings_v1'
);

-- Test 3: anon cannot execute
SELECT ok(
  NOT has_function_privilege('anon', 'public.update_workspace_settings_v1(text,text,text,text,text)', 'EXECUTE'),
  'anon cannot execute update_workspace_settings_v1'
);

-- Test 4: admin success
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'd0000000-0000-0000-0000-000000000001';

SELECT is(
  (SELECT (public.update_workspace_settings_v1(p_workspace_name => 'Test Workspace') ->> 'ok')::boolean),
  true,
  'admin can update workspace settings'
);

-- Test 5: post-call state — tenant name actually changed in DB
RESET ROLE;
SELECT is(
  (SELECT name FROM public.tenants WHERE id = 'd0000000-0000-0000-0000-000000000001'),
  'Test Workspace',
  'tenant name updated in DB after admin call'
);

-- Test 6: post-call state — other tenant name unchanged
SELECT is(
  (SELECT name FROM public.tenants WHERE id = 'd0000000-0000-0000-0000-000000000002'),
  null,
  'other tenant name unchanged after update'
);

-- Test 7: blank workspace_name returns VALIDATION_ERROR
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'd0000000-0000-0000-0000-000000000001';

SELECT is(
  (SELECT public.update_workspace_settings_v1(p_workspace_name => '') ->> 'code'),
  'VALIDATION_ERROR',
  'blank workspace_name returns VALIDATION_ERROR'
);

-- Test 8: invalid slug format returns VALIDATION_ERROR
SELECT is(
  (SELECT public.update_workspace_settings_v1(p_slug => 'INVALID SLUG!!') ->> 'code'),
  'VALIDATION_ERROR',
  'invalid slug format returns VALIDATION_ERROR'
);

-- Test 9: slug conflict returns CONFLICT
SELECT is(
  (SELECT public.update_workspace_settings_v1(p_slug => 'ws-taken-slug') ->> 'code'),
  'CONFLICT',
  'slug already taken by another tenant returns CONFLICT'
);

-- Test 10: correct workspace name returned in response
SELECT is(
  (SELECT public.update_workspace_settings_v1(p_workspace_name => 'Updated Name') -> 'data' ->> 'workspace_name'),
  'Updated Name',
  'update_workspace_settings_v1 returns updated workspace_name in response'
);

-- Test 11 + 12: isolation — call RPC then verify DB state
SELECT public.update_workspace_settings_v1(p_country => 'US');

RESET ROLE;

SELECT is(
  (SELECT country FROM public.tenants WHERE id = 'd0000000-0000-0000-0000-000000000001'),
  'US',
  'tenant 1 country updated in DB after update call'
);

SELECT is(
  (SELECT country FROM public.tenants WHERE id = 'd0000000-0000-0000-0000-000000000002'),
  null,
  'tenant 2 country unchanged after tenant 1 update'
);

-- Test 13: member denied
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000002","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'd0000000-0000-0000-0000-000000000001';

SELECT throws_ok(
  $tap$SELECT public.update_workspace_settings_v1(p_workspace_name => 'Member Attempt')$tap$,
  null,
  null,
  'member cannot update workspace settings — throws exception'
);

SELECT finish();

ROLLBACK;