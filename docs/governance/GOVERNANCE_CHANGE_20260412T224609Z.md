# GOVERNANCE CHANGE — Build Route v2.4 Addition — 10.8.11N and 10.8.11N1
UTC: 20260412T224609Z

## What changed
Added two new Build Route items to BUILD_ROUTE_V2.4.md:
- 10.8.11N: Expired Subscription Server-Side Write Lock (lane-only) — adds
  check_workspace_write_allowed_v1() internal helper and retrofits all existing
  workspace-write RPCs to enforce read-only during expired grace window. Billing
  path and profile settings remain exempt.
- 10.8.11N1: Workspace Write Lock Coverage Gate (merge-blocking) — adds a
  merge-blocking CI gate that verifies every workspace-write RPC calls
  check_workspace_write_allowed_v1(); prevents future write RPCs from bypassing
  read-only enforcement.
Additive only. No existing items modified or removed.

## Why safe
Build Route additions are planning documents only. No schema changes in this PR.
No RPC changes in this PR. No gate logic changed. N is lane-only. N1 is
merge-blocking but its individual PR will carry the gate script and proof.
No existing items modified or removed.

## Risk
Low. Additive documentation only. No executable code changed. No migrations.
No existing CI gates affected.

## Rollback
Revert this PR. No database state to undo. No generated artifacts affected.
Re-run npm run handoff to confirm zero diffs after revert.