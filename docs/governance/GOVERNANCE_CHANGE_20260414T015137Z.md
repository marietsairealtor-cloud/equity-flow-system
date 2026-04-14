# GOVERNANCE CHANGE — 10.8.11O2 Entitlement Archived-State Corrective Fix
UTC: 20260414T015137Z

## What changed
Corrective migration to get_user_entitlements_v1():
- RPC now reads public.tenants.archived_at after membership is confirmed
- If archived_at IS NOT NULL: returns app_mode = archived_unreachable immediately
- Archived state overrides subscription-derived app_mode until restore clears it
- No schema changes. No new columns. No new RPCs. No signature change. Additive logic only.

## Why this was needed
10.8.11M derived app_mode purely from subscription math (current_period_end age).
10.8.11O introduced tenants.archived_at as the authoritative archive marker.
The RPC was never updated to read it. Result: archived workspaces returned
app_mode = normal when subscription was active, making archived state invisible
to post-auth routing, UI, and write-lock logic.
Discovered during 10.8.11P UI build when archived_at had no effect on RPC output.

## Why safe
- Additive logic only: archived_at check inserted before existing subscription block
- No return type change
- No signature change
- No schema changes
- Existing callers unaffected when archived_at is NULL (normal path unchanged)
- Corrective fix, not a new feature

## Risk
Low. Single-function corrective update. No schema changes.
Existing behavior preserved for all non-archived workspaces.

## Rollback
Revert this PR. Run supabase db push to restore previous function definition.
No data migrations. No schema rollback required.