# GOVERNANCE CHANGE — 10.8.11I9 Workspace Switcher Name Wiring
UTC: 20260410T151125Z

## What changed
Updated workspace switcher in hamburger popup to display workspace_name from
list_user_tenants_v1 instead of slug:
- Text binding changed to context.item.data.workspace_name with fallback to
  'Unnamed Workspace' when workspace_name is null
- Data source remains list_user_tenants_v1 only (no direct table access)
- No new RPCs. No business logic added in UI. No schema changes.
- Updated qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 for
  10.8.11I9 registration

## Why safe
WeWeb-only item. No migrations. No RPC changes. No schema changes. No new RPCs.
Display-only change. Fallback to 'Unnamed Workspace' handles null gracefully.
Data sourced from existing allowlisted RPC only. Lane-only gate.

## Risk
Low. Frontend-only change. No backend state affected. Display-only field.
Fallback string prevents null from rendering in UI.

## Rollback
Revert this PR. No database state to undo. WeWeb changes are independent of
backend. No dependent items blocked.