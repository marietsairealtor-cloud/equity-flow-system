GOVERNANCE_CHANGE_PR123.md
What changed

docs/artifacts/BUILD_ROUTE_V2_4.md item 10.8.2 — subscription_status expanded from 3 values (active | expired | none) to 4 values (active | expiring | expired | none). subscription_expires_at replaced with subscription_days_remaining (integer). Expiration threshold (≤5 days) computed server-side in RPC, not client-side in WeWeb.
docs/artifacts/WEWEB_ARCHITECTURE.md §6.2 — Updated banner to reference server-side status check. Removed client-side date math. Added GUARDRAILS §5 citation.
docs/artifacts/WEWEB_ARCHITECTURE.md §13.1 — Updated §5A reference to document new return fields.

Why safe

Enforces GUARDRAILS §5 (no business logic in WeWeb). Moves logic from frontend to RPC where it belongs.
Additive change to RPC return shape. No breaking change.
Threshold lives server-side — changeable without frontend deployment.

Risk
None. Specification refinement before implementation.
Rollback
Revert PR. Spec reverts to client-side date math approach.