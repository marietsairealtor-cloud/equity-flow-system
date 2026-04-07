# GOVERNANCE CHANGE — Build Route v2.4 Addition — 10.8.11I1 through I4
UTC: 20260407T221813Z

## What changed
Added four new Build Route items to BUILD_ROUTE_V2_4.md identified during
10.8.11I authoring:
- 10.8.11I1: Workspace Invite Email Delivery (lane-only) — email sent after
  invite_workspace_member_v1 is called; server-side only; no RPC signature changes
- 10.8.11I2: Workspace Settings Read RPC Corrective Fix (merge-blocking) — fixes
  get_workspace_settings_v1 to read name, country, currency, measurement_unit from
  public.tenants instead of returning null hardcoded placeholders
- 10.8.11I3: Pending Invites RPC Management Layer (merge-blocking) — adds
  list_pending_invites_v1 and rescind_invite_v1 RPCs
- 10.8.11I4: Pending Invites UI in Workspace Settings (lane-only) — UI to view
  and cancel pending invites
Additive only. No existing items modified.

## Why safe
Build Route additions are planning documents only. No schema changes in this PR.
No RPC changes in this PR. No gate logic changed. I2 and I3 are merge-blocking
but individual item PRs will carry migrations, tests, and proofs. I1 and I4 are
lane-only. No existing items modified or removed.

## Risk
Low. Additive documentation only. No executable code changed. No migrations.
No existing CI gates affected. I2 corrective fix is already identified and scoped.

## Rollback
Revert this PR. No database state to undo. No generated artifacts affected.
Re-run npm run handoff to confirm zero diffs after revert.