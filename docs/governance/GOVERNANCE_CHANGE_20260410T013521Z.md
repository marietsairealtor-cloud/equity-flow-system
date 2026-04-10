# GOVERNANCE CHANGE — Build Route v2.4 Addition — 10.8.11I8 and 10.8.11I9
UTC: 20260410T013521Z

## What changed
Added two new Build Route items to BUILD_ROUTE_V2.4.md identified during
10.8.11I7 wrap-up:
- 10.8.11I8: list_user_tenants_v1 Workspace Name Corrective Fix (merge-blocking)
  fixes list_user_tenants_v1 to join public.tenants and return workspace_name
  from tenants.name instead of hardcoded null; no schema changes; no new RPCs
- 10.8.11I9: Workspace Switcher Name Wiring (lane-only) — WeWeb workspace
  switcher updated to display workspace_name from list_user_tenants_v1;
  no direct table access; no new RPCs; no business logic in UI
Additive only. No existing items modified or removed.

## Why safe
Build Route additions are planning documents only. No schema changes in this PR.
No RPC changes in this PR. No gate logic changed. I8 is merge-blocking but its
individual PR will carry migrations, tests, and proofs. I9 is lane-only.
No existing items modified or removed.

## Risk
Low. Additive documentation only. No executable code changed. No migrations.
No existing CI gates affected. I8 corrective fix is already identified and
scoped — same pattern as 10.8.11I2.

## Rollback
Revert this PR. No database state to undo. No generated artifacts affected.
Re-run npm run handoff to confirm zero diffs after revert.