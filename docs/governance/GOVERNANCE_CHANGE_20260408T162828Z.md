# GOVERNANCE CHANGE — Build Route v2.4 Addition — 10.8.11I5 and 10.8.11I6
UTC: 20260408T162828Z

## What changed
Added two new Build Route items to BUILD_ROUTE_V2.4.md identified during
10.8.11I3 authoring:
- 10.8.11I5: Seat Billing Sync on Invite Acceptance (merge-blocking) — on
  accept_pending_invites_v1, Stripe subscription quantity is updated to reflect
  active member count; server-side only; idempotent; no frontend billing logic
- 10.8.11I6: Billing Seat Count UI (lane-only) — owner-only billing section
  displays active member count from existing RPCs; no billing mutations from UI
Additive only. No existing items modified or removed.

## Why safe
Build Route additions are planning documents only. No schema changes in this PR.
No RPC changes in this PR. No gate logic changed. I5 is merge-blocking but its
individual PR will carry migrations, tests, and proofs. I6 is lane-only.
No existing items modified or removed.

## Risk
Low. Additive documentation only. No executable code changed. No migrations.
No existing CI gates affected. I5 touches billing integration but is scoped
and constrained to server-side only with idempotency requirement.

## Rollback
Revert this PR. No database state to undo. No generated artifacts affected.
Re-run npm run handoff to confirm zero diffs after revert.