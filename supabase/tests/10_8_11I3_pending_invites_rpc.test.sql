-- 10.8.11I3: Pending Invites RPC Management Layer
BEGIN;

SELECT plan(8);
SET LOCAL session_replication_role = replica;

-- Seed tenant A
INSERT INTO public.tenants (id, name)
VALUES ('c1000000-0000-0000-0000-000000000001', 'pgTAP Tenant I3 A');

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (
  'c1000000-0000-0000-0000-000000000011',
  'c1000000-0000-0000-0000-000000000001',
  '866998e1-cce3-4902-b5b1-b01ddd2fa785',
  'admin'
);

-- Seed tenant B (cross-tenant)
INSERT INTO public.tenants (id, name)
VALUES ('c1000000-0000-0000-0000-000000000002', 'pgTAP Tenant I3 B');

INSERT INTO public.tenant_memberships (id, tenant_id, user_id, role)
VALUES (
  'c1000000-0000-0000-0000-000000000022',
  'c1000000-0000-0000-0000-000000000002',
  '8a2b5fd0-42a4-48da-95a5-792e2b1c9bb7',
  'admin'
);

-- Seed pending invite for tenant A
INSERT INTO public.tenant_invites
  (id, tenant_id, invited_email, role, token, invited_by, expires_at)
VALUES (
  'e1000000-0000-0000-0000-000000000001',
  'c1000000-0000-0000-0000-000000000001',
  'pending@example.com',
  'member',
  'token-pending-001',
  '866998e1-cce3-4902-b5b1-b01ddd2fa785',
  now() + interval '7 days'
);

-- Seed accepted invite for tenant A
INSERT INTO public.tenant_invites
  (id, tenant_id, invited_email, role, token, invited_by, expires_at, accepted_at)
VALUES (
  'e1000000-0000-0000-0000-000000000002',
  'c1000000-0000-0000-0000-000000000001',
  'accepted@example.com',
  'member',
  'token-accepted-001',
  '866998e1-cce3-4902-b5b1-b01ddd2fa785',
  now() + interval '7 days',
  now()
);

SET LOCAL "request.jwt.claims" TO '{"sub":"866998e1-cce3-4902-b5b1-b01ddd2fa785","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'c1000000-0000-0000-0000-000000000001';

-- 1. list returns ok=true
SELECT is(
  (SELECT (public.list_pending_invites_v1() ->> 'ok')::boolean),
  true,
  'list_pending_invites_v1 returns ok=true'
);

-- 2. list returns only pending invites (1 pending, 1 accepted — only 1 in items)
SELECT is(
  (SELECT jsonb_array_length(public.list_pending_invites_v1() -> 'data' -> 'items')),
  1,
  'list_pending_invites_v1 returns only pending invites'
);

-- 3. list excludes accepted invites
SELECT is(
  (SELECT COUNT(*)::int FROM jsonb_array_elements(
    public.list_pending_invites_v1() -> 'data' -> 'items'
  ) el WHERE el ->> 'email' = 'accepted@example.com'),
  0,
  'list_pending_invites_v1 excludes accepted invites'
);

-- 4. list returns empty array when no pending invites exist (use tenant B context)
RESET ROLE;
SET LOCAL "request.jwt.claims" TO '{"sub":"8a2b5fd0-42a4-48da-95a5-792e2b1c9bb7","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'c1000000-0000-0000-0000-000000000002';

SELECT is(
  (SELECT public.list_pending_invites_v1() -> 'data' -> 'items'),
  '[]'::jsonb,
  'list_pending_invites_v1 returns empty array when no pending invites'
);

-- 5. rescind removes pending invite
RESET ROLE;
SET LOCAL "request.jwt.claims" TO '{"sub":"866998e1-cce3-4902-b5b1-b01ddd2fa785","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'c1000000-0000-0000-0000-000000000001';

SELECT is(
  (SELECT (public.rescind_invite_v1('e1000000-0000-0000-0000-000000000001') ->> 'ok')::boolean),
  true,
  'rescind_invite_v1 returns ok=true for pending invite'
);

-- 6. after rescind, invite no longer in list
SELECT is(
  (SELECT jsonb_array_length(public.list_pending_invites_v1() -> 'data' -> 'items')),
  0,
  'after rescind, invite no longer appears in list'
);

-- 7. rescind fails on already accepted invite
SELECT is(
  (SELECT public.rescind_invite_v1('e1000000-0000-0000-0000-000000000002') ->> 'code'),
  'NOT_FOUND',
  'rescind_invite_v1 returns NOT_FOUND for accepted invite'
);

-- 8. rescind fails cross-tenant
RESET ROLE;
INSERT INTO public.tenant_invites
  (id, tenant_id, invited_email, role, token, invited_by, expires_at)
VALUES (
  'e1000000-0000-0000-0000-000000000003',
  'c1000000-0000-0000-0000-000000000002',
  'other@example.com',
  'member',
  'token-other-001',
  '8a2b5fd0-42a4-48da-95a5-792e2b1c9bb7',
  now() + interval '7 days'
);

SET LOCAL "request.jwt.claims" TO '{"sub":"866998e1-cce3-4902-b5b1-b01ddd2fa785","role":"authenticated"}';
SET LOCAL ROLE authenticated;
SET LOCAL "app.tenant_id" TO 'c1000000-0000-0000-0000-000000000001';

SELECT is(
  (SELECT public.rescind_invite_v1('e1000000-0000-0000-0000-000000000003') ->> 'code'),
  'NOT_FOUND',
  'rescind_invite_v1 returns NOT_FOUND for cross-tenant invite'
);

SELECT finish();
ROLLBACK;
