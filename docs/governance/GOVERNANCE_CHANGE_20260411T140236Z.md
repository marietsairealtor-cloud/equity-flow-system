# GOVERNANCE CHANGE — Build Route v2.4 Addition — 10.8.11L through 10.8.11P
UTC: 20260411T140236Z

## What changed
Added five new Build Route items to BUILD_ROUTE_V2.4.md:
- 10.8.11L: Renew Now Routing Fix (lane-only) — CTA routes to billing only,
  role-aware, no onboarding language, same destination across all renewal surfaces
- 10.8.11M: Entitlement RPC Access + Retention State Extension (lane-only) —
  get_user_entitlements_v1 extended with app_mode, can_manage_billing, renew_route,
  retention_deadline, days_until_deletion; no new RPC
- 10.8.11N: Expired Subscription Server-Side Write Lock (lane-only) — expired
  workspaces become server-enforced read-only during 60-day grace window; write
  paths blocked at RPC/server layer
- 10.8.11O: Expired Workspace Retention + Archive Lifecycle (lane-only) — defines
  lifecycle from read-only to archive to hard delete; backend-driven timing only
- 10.8.11P: Expired Workspace UI Read-Only + Banner Enforcement (lane-only) —
  UI reads entitlement state from get_user_entitlements_v1 only; expired users
  remain in app during grace window with read-only access
Additive only. No existing items modified or removed.

## Why safe
Build Route additions are planning documents only. No schema changes in this PR.
No RPC changes in this PR. No gate logic changed. All five items are lane-only.
No existing items modified or removed. Items are sequenced correctly: L before M,
M before N, N before O, O before P.

## Risk
Low. Additive documentation only. No executable code changed. No migrations.
No existing CI gates affected.

## Rollback
Revert this PR. No database state to undo. No generated artifacts affected.
Re-run npm run handoff to confirm zero diffs after revert.