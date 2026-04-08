# GOVERNANCE CHANGE — 10.8.11I2 Workspace Settings Read RPC Corrective Fix
UTC: 20260408T145722Z

## What changed
Corrective fix for get_workspace_settings_v1 which previously returned null for
workspace_name, country, currency, and measurement_unit. Migration updates the
existing RPC to read these four fields from public.tenants for the current tenant
context. No schema changes. No new columns. No new RPCs. No interface changes.
CONTRACTS.md section 41 updated to remove null-placeholder language and reflect
actual returned fields. qa_scope_map.json, qa_claim.json, and
ci_robot_owned_guard.ps1 updated for 10.8.11I2 registration.

## Why safe
Corrective migration only. No schema changes. No new columns. No new RPCs.
CREATE OR REPLACE FUNCTION used — interface is identical, internal logic only.
All four corrected fields were already in the return envelope as null; callers
that handle null gracefully are unaffected. pgTAP tests prove correct field
sourcing and NOT_AUTHORIZED path. Merge-blocking gate enforced.

## Risk
Low. No interface change. No privilege change. No tenant boundary change.
Only behavioral correction — fields that returned null now return actual values
from public.tenants. WeWeb bindings already expect these fields; null was the bug.

## Rollback
Revert this PR. Re-run supabase db push to restore previous function definition.
No data migrations. No schema rollback required.