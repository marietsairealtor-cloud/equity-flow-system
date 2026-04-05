-- 10_8_11G_workspace_members_rpcs.test.sql

BEGIN;

SELECT plan(22);

-- Seed auth.users
INSERT INTO auth.users (id, email)
VALUES
  ('a0000000-0000-0000-0000-000000000001', 'admin1@test.com'),
  ('a0000000-0000-0000-0000-000000000002', 'member2@test.com'),
  ('a0000000-0000-0000-0000-000000000003', 'admin3@test.com'),
  ('a0000000-0000-0000-0000-000000000004', 'member4@test.com')
ON CONFLICT DO NOTHING;

-- Seed tenants
INSERT INTO public.tenants (id)
VALUES ('f0000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO public.tenants (id)
VALUES ('f0000000-0000-0000-0000-000000000002')
ON CONFLICT DO NOTHING;

-- Seed memberships
INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES
  ('f1000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'admin'),
  ('f1000000-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'member'),
  ('f1000000-0000-0000-0000-000000000003', 'f0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000003', 'admin'),
  ('f1000000-0000-0000-0000-000000000004', 'f0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000004', 'member')
ON CONFLICT DO NOTHING;

-- Seed tenant slugs
INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES ('f0000000-0000-0000-0000-000000000001', 'ws-members-test')
ON CONFLICT (tenant_id) DO UPDATE SET slug = EXCLUDED.slug;

INSERT INTO public.tenant_slugs (tenant_id, slug)
VALUES ('f0000000-0000-0000-0000-000000000002', 'ws-members-test-2')
ON CONFLICT (tenant_id) DO UPDATE SET slug = EXCLUDED.slug;

-- Test 1: list_workspace_members_v1 exists
SELECT has_function(
  'public', 'list_workspace_members_v1', ARRAY[]::text[],
  'list_workspace_members_v1 exists'
);

-- Test 2: invite_workspace_member_v1 exists
SELECT has_function(
  'public', 'invite_workspace_member_v1', ARRAY['text','public.tenant_role'],
  'invite_workspace_member_v1 exists'
);

-- Test 3: update_member_role_v1 exists
SELECT has_function(
  'public', 'update_member_role_v1', ARRAY['uuid','public.tenant_role'],
  'update_member_role_v1 exists'
);

-- Test 4: remove_member_v1 exists
SELECT has_function(
  'public', 'remove_member_v1', ARRAY['uuid'],
  'remove_member_v1 exists'
);

-- Test 5: authenticated can execute list
SELECT ok(
  has_function_privilege('authenticated', 'public.list_workspace_members_v1()', 'EXECUTE'),
  'authenticated can execute list_workspace_members_v1'
);

-- Test 6: anon cannot execute list
SELECT ok(
  NOT has_function_privilege('anon', 'public.list_workspace_members_v1()', 'EXECUTE'),
  'anon cannot execute list_workspace_members_v1'
);

-- Test 7: list members success
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'f0000000-0000-0000-0000-000000000001';

SELECT is(
  (SELECT (public.list_workspace_members_v1() ->> 'ok')::boolean),
  true,
  'list_workspace_members_v1 returns ok=true for member'
);

-- Test 8: list returns correct member count
SELECT is(
  (SELECT jsonb_array_length(public.list_workspace_members_v1() -> 'data' -> 'items')),
  2,
  'list_workspace_members_v1 returns correct number of members'
);

-- Test 9: invite success
SELECT is(
  (SELECT (public.invite_workspace_member_v1('newmember@test.com', 'member') ->> 'ok')::boolean),
  true,
  'admin can invite new member'
);

-- Test 10: duplicate invite rejected
SELECT is(
  (SELECT public.invite_workspace_member_v1('newmember@test.com', 'member') ->> 'code'),
  'CONFLICT',
  'duplicate pending invite returns CONFLICT'
);

-- Test 11: already-member rejected
SELECT is(
  (SELECT public.invite_workspace_member_v1('member2@test.com', 'member') ->> 'code'),
  'CONFLICT',
  'inviting existing member returns CONFLICT'
);

-- Test 12: blank email returns VALIDATION_ERROR
SELECT is(
  (SELECT public.invite_workspace_member_v1('', 'member') ->> 'code'),
  'VALIDATION_ERROR',
  'blank email returns VALIDATION_ERROR'
);

-- Test 13: role update success
SELECT is(
  (SELECT (public.update_member_role_v1('a0000000-0000-0000-0000-000000000002'::uuid, 'admin') ->> 'ok')::boolean),
  true,
  'admin can update member role'
);

-- Test 14: post-call state — role updated in DB
RESET ROLE;
SELECT is(
  (SELECT role::text FROM public.tenant_memberships
   WHERE tenant_id = 'f0000000-0000-0000-0000-000000000001'
   AND user_id = 'a0000000-0000-0000-0000-000000000002'),
  'admin',
  'member role updated in DB after update_member_role_v1'
);

-- Test 15: remove member success
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'f0000000-0000-0000-0000-000000000001';

SELECT is(
  (SELECT (public.remove_member_v1('a0000000-0000-0000-0000-000000000002'::uuid) ->> 'ok')::boolean),
  true,
  'admin can remove member'
);

-- Test 16: post-call state — member removed from DB
RESET ROLE;
SELECT is(
  (SELECT COUNT(*)::int FROM public.tenant_memberships
   WHERE tenant_id = 'f0000000-0000-0000-0000-000000000001'
   AND user_id = 'a0000000-0000-0000-0000-000000000002'),
  0,
  'member removed from DB after remove_member_v1'
);

-- Test 17: cross-tenant protection — only current tenant members returned
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'f0000000-0000-0000-0000-000000000001';

SELECT is(
  (SELECT jsonb_array_length(public.list_workspace_members_v1() -> 'data' -> 'items')),
  1,
  'list only returns members of current tenant after removal'
);

-- Test 18: member denied on invite
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000004","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'f0000000-0000-0000-0000-000000000002';

SELECT throws_ok(
  $tap$SELECT public.invite_workspace_member_v1('someone@test.com', 'member')$tap$,
  null, null,
  'member cannot invite — throws exception'
);

-- Test 19: member denied on role update
SELECT throws_ok(
  $tap$SELECT public.update_member_role_v1('a0000000-0000-0000-0000-000000000003'::uuid, 'admin')$tap$,
  null, null,
  'member cannot update role — throws exception'
);

-- Test 20: member denied on remove
SELECT throws_ok(
  $tap$SELECT public.remove_member_v1('a0000000-0000-0000-0000-000000000003'::uuid)$tap$,
  null, null,
  'member cannot remove — throws exception'
);

-- Test 21: null role on invite returns VALIDATION_ERROR
SET LOCAL "request.jwt.claims" TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'f0000000-0000-0000-0000-000000000001';

SELECT is(
  (SELECT public.invite_workspace_member_v1('someone@test.com', NULL) ->> 'code'),
  'VALIDATION_ERROR',
  'null role on invite returns VALIDATION_ERROR'
);

-- Test 22: null role on update returns VALIDATION_ERROR
SELECT is(
  (SELECT public.update_member_role_v1('a0000000-0000-0000-0000-000000000001'::uuid, NULL) ->> 'code'),
  'VALIDATION_ERROR',
  'null role on update returns VALIDATION_ERROR'
);

SELECT finish();

ROLLBACK;