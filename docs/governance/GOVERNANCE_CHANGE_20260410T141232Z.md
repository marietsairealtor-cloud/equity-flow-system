# GOVERNANCE CHANGE — 10.8.11I8 list_user_tenants_v1 Workspace Name Corrective Fix
UTC: 20260410T141232Z

## What changed
Corrective fix for list_user_tenants_v1 which previously returned null for
workspace_name. Migration updates the existing RPC to JOIN public.tenants and
return workspace_name from tenants.name for each tenant membership.
No schema changes. No new columns. No new RPCs. Interface unchanged.
CONTRACTS.md section 17 mapping row updated to reflect workspace_name is returned.
qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered for 10.8.11I8.

## Why safe
Corrective migration only. No schema changes. No new columns. No new RPCs.
CREATE OR REPLACE FUNCTION used — interface is identical, internal logic only.
workspace_name was previously null in the return envelope; callers that handle
null gracefully are unaffected. pgTAP tests prove correct field sourcing.
Merge-blocking gate enforced. Same pattern as 10.8.11I2.

## Risk
Low. No interface change. No privilege change. No tenant boundary change.
Only behavioral correction — workspace_name that returned null now returns
actual value from public.tenants.name. WeWeb bindings already expect this field.

## Rollback
Revert this PR. Re-run supabase db push to restore previous function definition.
No data migrations. No schema rollback required.