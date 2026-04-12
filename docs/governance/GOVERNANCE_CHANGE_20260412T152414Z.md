# GOVERNANCE CHANGE — 10.8.11M Entitlement RPC Access + Retention State Extension
UTC: 20260412T152414Z

## What changed
Extended get_user_entitlements_v1 with access-state and retention-state fields:
- app_mode: normal | read_only_expired | archived_unreachable
- can_manage_billing: true for owner only, false for admin/member/archived
- renew_route: billing | none (semantic enum, not URL)
- retention_deadline: timestamptz -- end of 60-day grace window from current_period_end
- days_until_deletion: integer -- countdown after archive begins
Derivation rules:
- active/expiring → app_mode=normal
- expired within 60 days → app_mode=read_only_expired
- expired beyond 60 days → app_mode=archived_unreachable
- membership + no subscription → app_mode=read_only_expired
- no membership → early return, is_member=false
No new RPC. No schema changes. No new columns. Interface additive only.
CONTRACTS.md section 5A updated to reflect new fields and derivation rules.
qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered.

## Why safe
Additive return fields only. No signature change. No return type change.
CREATE OR REPLACE acceptable. No schema changes. No new RPCs. No privilege
changes. Existing callers that ignore new fields are unaffected.
Derivation is server-side only -- no frontend date math. Lane-only gate.

## Risk
Low-medium. New fields change post-auth routing behavior when consumed by UI.
10.8.11N and 10.8.11P will wire UI to these fields. Until then new fields are
returned but not yet consumed -- no behavioral change in UI.

## Rollback
Revert this PR. Re-run supabase db push to restore previous function definition.
No data migrations. No schema rollback required.