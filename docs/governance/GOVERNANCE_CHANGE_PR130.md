# GOVERNANCE_CHANGE_PR130.md

## Build Route Item
10.8.2 -- Entitlements Extension (Subscription Status)

## Governance Surface Touched
- `docs/artifacts/CONTRACTS.md` §2 -- DROP + CREATE pattern used (return shape change)
- `docs/truth/rpc_schemas/get_user_entitlements_v1.json` -- schema version bumped to 2
- `docs/truth/rpc_contract_registry.json` -- get_user_entitlements_v1 version bumped

## Justification
10.8.2 extends get_user_entitlements_v1 return shape with subscription_status
(active | expiring | expired | none) and subscription_days_remaining (integer).
Expiring threshold (5 days) computed server-side per GUARDRAILS §5 -- no date
math in WeWeb. DROP + CREATE used per CONTRACTS §2 (return shape change).
Additive change -- existing callers receive new fields without breakage.

## No Breaking Changes to Existing Callers
- ok, code, data, error envelope unchanged
- All existing data fields present (tenant_id, user_id, is_member, role, entitled)
- New fields are additive only

## Status
Implementation complete. Tests: 19/19 PASS. 10.4 tests updated: 27/27 PASS.