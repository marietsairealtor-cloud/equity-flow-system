# GOVERNANCE_CHANGE_PR129.md

## Build Route Item
10.8.1A -- Subscriptions Table (Billing Data Source)

## Governance Surface Touched
- `docs/artifacts/CONTRACTS.md` §12 -- tenant_subscriptions added to core table list
- `docs/truth/privilege_truth.json` -- table appears with zero grants
- `docs/truth/tenant_table_selector.json` -- table added as tenant-scoped

## Justification
10.8.1A introduces tenant_subscriptions as the data source for subscription
status computation in get_user_entitlements_v1 (10.8.2). Table is schema-only --
no RPC, no Stripe webhook. RLS ON, REVOKE from anon/authenticated per CONTRACTS §12.
Unique constraint on tenant_id enforces one active subscription per tenant.

## No Breaking Changes
- No RPC changes
- No existing table changes
- New table only: tenant_subscriptions

## Status
Implementation complete. Tests: 12/12 PASS.