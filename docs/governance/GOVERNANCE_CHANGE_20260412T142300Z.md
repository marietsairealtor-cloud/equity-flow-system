# GOVERNANCE CHANGE — 10.8.11L Renew Now Routing Fix
UTC: 20260412T142300Z

## What changed
Fixed Renew Now CTA routing and role-aware visibility for 10.8.11L:
- Renew Now CTA now routes to Workspace Settings Billing section, not onboarding
- CTA changed from button to link element
- Owner: actionable Renew Now link visible, routes to Workspace Settings Billing
- Admin/member: no actionable CTA, informational Contact workspace owner shown
- Same billing destination used across expired banner, expiring banner
- No onboarding language in CTA copy
- Workspace Settings shell accessible to Admin+; Billing section owner-only
- Updated qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1

## Why safe
WeWeb-only item. No migrations. No RPC changes. No schema changes. No new RPCs.
Role-aware visibility enforced via entitlements.data.role check on display binding.
Authority remains server-side -- UI visibility is display only, not authorization.
Lane-only gate.

## Risk
Low. Frontend-only changes. No backend state affected. Display-only role check.
Worst case: wrong role sees banner but cannot access billing -- server enforces.

## Rollback
Revert this PR. No database state to undo. WeWeb changes are independent of
backend. No dependent items blocked.