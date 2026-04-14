# GOVERNANCE CHANGE — 10.8.11O2 Entitlement Archived-State Corrective Fix
UTC: 20260414T160308Z

## What changed
- Migration 20260414000001_10_8_11O2_entitlement_archived_state_fix.sql applied
- get_user_entitlements_v1() updated to read public.tenants.archived_at
- After membership confirmed, archived_at is checked before subscription math
- If archived_at IS NOT NULL: returns app_mode = archived_unreachable immediately
- Archived branch returns:
  is_member = true, entitled = true (membership semantics preserved)
  can_manage_billing = false, renew_route = none
  days_until_deletion computed from archived_at + interval '6 months'
- CONTRACTS.md section 5A updated with O2 corrective note and derivation rules
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why this was needed
10.8.11M derived app_mode purely from subscription math.
10.8.11O introduced tenants.archived_at as the authoritative archive marker.
The RPC was never updated to read it. Archived workspaces returned app_mode = normal
when subscription was active. Discovered during 10.8.11P UI build.

## Why safe
- Additive logic only: archived_at check inserted before existing subscription block
- No return type change. No signature change. No schema changes.
- CREATE OR REPLACE acceptable: interface identical, logic corrected.
- Existing callers unaffected when archived_at is NULL (normal path unchanged)

## Risk
Low. Corrective logic addition. No schema changes.
Existing behavior preserved for all non-archived workspaces.

## Rollback
Revert this PR. Run supabase db push to restore previous function definition.
No data migrations. No schema rollback required.