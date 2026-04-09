# GOVERNANCE CHANGE — 10.8.11I4 Pending Invites UI
UTC: 20260409T004810Z

## What changed
Added pending invites management UI to Workspace Settings Members tab:
- Pending invites list displays email, role, invited_by, created_at
- Data sourced from list_pending_invites_v1 only
- Cancel invite button opens confirmation modal before calling rescind_invite_v1
- On success: invite removed from UI list and fetch-pending-invite-list refreshed
- Empty state displayed when no pending invites exist
- Visible to Admin+ only (inherited from page access gate)
- No direct table access from WeWeb
- Updated qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 for
  10.8.11I4 registration

## Why safe
WeWeb-only item. No migrations. No RPC changes. No schema changes. No new RPCs.
All data calls via existing allowlisted RPCs only. No direct table access.
Role gating enforced server-side by RPCs. UI visibility checks are display only.
Confirmation modal prevents accidental rescind. Lane-only gate.

## Risk
Low. Frontend-only changes. No backend state affected. No existing RPCs modified.
Rescind action is destructive but tenant-scoped and admin-gated server-side.
Confirmation modal adds UX protection against accidental cancellation.

## Rollback
Revert this PR. No database state to undo. WeWeb changes are independent of
backend. Pending invites remain in tenant_invites table unaffected.