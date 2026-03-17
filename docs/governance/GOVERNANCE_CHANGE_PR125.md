# GOVERNANCE_CHANGE_PR125.md

## Build Route Item
10.8 — Authenticated Shell + Navbar

## Governance Surface Touched
- `docs/artifacts/WEWEB_ARCHITECTURE.md` — authoritative UI architecture document introduced
- `docs/artifacts/BUILD_ROUTE_V2.4.md` — 10.8 DoD updated (switch workspace deferred to 10.8.11, subscription banner two-state model)

## Justification
10.8 establishes the authenticated shell, persistent navbar, subscription banner, and mobile bottom nav for the Wholesale Hub. WEWEB_ARCHITECTURE.md is a new governance artifact defining the complete UI architecture, page inventory, access tiers, deal stages, and boundary lines. It is locked and changes only via PR + governance file per its own authority statement.

Switch workspace live wiring deferred to 10.8.11 pending `list_user_tenants_v1` RPC (gap identified during implementation, QA-approved deferral).

Subscription banner amended to two-state model (expiring ≤5 days / expired) with server-side threshold computation per GUARDRAILS §5 (no business logic in WeWeb).

## No Breaking Changes
- No RPC signature changes
- No migration changes
- No schema changes
- No CONTRACTS envelope changes

## Status
Implementation complete. Proof pending.