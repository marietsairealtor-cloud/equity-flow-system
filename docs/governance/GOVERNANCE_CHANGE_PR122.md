GOVERNANCE_CHANGE_PR122.md
What changed

docs/artifacts/WEWEB_ARCHITECTURE.md §6.2 — Renamed "Expired Subscription Banner" to "Subscription Banner". Added 5-day warning state before expiration alongside existing expired state. Warning computed client-side from subscription_expires_at.
docs/artifacts/BUILD_ROUTE_V2_4.md item 10.8 — Updated DoD to include two-state subscription banner (warning + expired).
docs/artifacts/BUILD_ROUTE_V2_4.md item 10.8.2 — Added subscription_expires_at (TIMESTAMPTZ) to get_user_entitlements_v1 return shape alongside existing subscription_status.

Why safe

No runtime changes. Specification update only.
Additive field on RPC return shape (subscription_expires_at). No breaking change to existing callers.
Banner behavior is UX polish. Server-side enforcement unchanged (RPCs still return NOT_AUTHORIZED on expired sub).

Risk
None. Specification refinement. No implementation in this PR.
Rollback
Revert PR. Banner reverts to expired-only behavior. subscription_expires_at field removed from 10.8.2 spec.