# Governance Change — PR128

## What changed

Build Route v2.4 amended: item 10.8.1A (Subscriptions Table — Billing Data Source) added between 10.8.1 and 10.8.2.

10.8.2 (Entitlements Extension) requires computing `subscription_status` and `subscription_days_remaining` from subscription records. No subscriptions table exists in the current schema. Without a data source, 10.8.2 cannot implement the computation specified in its DoD. 10.8.1A creates `tenant_subscriptions` with the minimum fields needed: `tenant_id`, `status`, `current_period_end`. No RPC introduced. No Stripe wiring. Schema and privilege enforcement only.

Execution order updated: 10.8.1 → 10.8.1A → 10.8.2.

No existing items modified. No renumbering. No gate changes.

## Why safe

Additive only — one new item inserted into an existing dependency chain. No merged items affected. No gate names changed. No truth file semantics altered. The table follows the identical pattern as every other tenant-scoped table in Section 6 (RLS ON, REVOKE ALL, privilege firewall, pgTAP negative tests). 10.8.2 DoD is unchanged — it gains a dependency predecessor, not a scope change. All existing CI gates remain green because no implementation ships in this PR.

## Risk

Low. Specification addition only — no code, no migrations, no schema changes in this PR. Risk is limited to incorrect DoD specification (e.g., missing a required field that 10.8.2 needs). Mitigated by the DoD explicitly listing the fields 10.8.2 will read: `status` for `subscription_status` derivation, `current_period_end` for `subscription_days_remaining` computation.

## Rollback

Revert this PR. 10.8.1A disappears from Build Route. 10.8.2 remains blocked on the same dependency gap until an alternative is proposed. No schema, code, or truth file changes to unwind.