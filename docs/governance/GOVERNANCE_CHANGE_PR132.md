# GOVERNANCE_CHANGE_PR132.md

## Build Route Item
10.8.3 -- Reminder Engine

## Governance Surface Touched
- `docs/artifacts/CONTRACTS.md` §12 -- deal_reminders added to core table list
- `docs/artifacts/CONTRACTS.md` §17 -- three new RPCs registered
- `docs/truth/definer_allowlist.json` -- three RPCs added
- `docs/truth/execute_allowlist.json` -- three RPCs added
- `docs/truth/privilege_truth.json` -- three RPCs added to routine_grants.authenticated and migration_grant_allowlist
- `docs/truth/rpc_contract_registry.json` -- three RPCs registered
- `docs/truth/tenant_table_selector.json` -- deal_reminders added

## Justification
10.8.3 introduces deal_reminders table and three authenticated RPCs for reminder
management. All RPCs follow CONTRACTS §8 safety rules. require_min_role_v1
exception caught and returned as JSON envelope per RPC contract consistency.
No anon access -- authenticated only per GUARDRAILS §11-13.

## No Breaking Changes
- No existing RPC changes
- New table and RPCs only

## Status
Implementation complete. Tests: 18/18 PASS.