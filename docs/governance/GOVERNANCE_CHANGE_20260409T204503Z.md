# GOVERNANCE CHANGE — 10.8.11I6 Billing Seat Count UI
UTC: 20260409T204503Z

## What changed
Added active seat count display to owner-only billing section in Workspace
Settings General tab:
- Active seats field added showing count of active workspace members
- Data sourced from existing list_workspace_members_v1 response items length
- No new RPCs. No direct table access. No billing mutations from UI.
- Owner-only visibility enforced via existing entitlements role check
- Updated qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 for
  10.8.11I6 registration

## Why safe
WeWeb-only item. No migrations. No RPC changes. No schema changes. No new RPCs.
Data sourced from existing allowlisted RPC response already loaded on page.
No billing mutations possible from UI. Owner-only gate enforced server-side.
Lane-only gate.

## Risk
Low. Frontend-only change. No backend state affected. Display-only field.
Seat count derived from existing member list already fetched on page load.

## Rollback
Revert this PR. No database state to undo. WeWeb changes are independent of
backend. No dependent items blocked.