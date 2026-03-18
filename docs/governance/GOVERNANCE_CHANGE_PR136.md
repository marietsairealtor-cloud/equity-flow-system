# GOVERNANCE_CHANGE_PR136.md

## Build Route Item
10.8.3B -- Migration + pgTAP Test Remediation

## Governance Surface Touched
- `docs/artifacts/CONTRACTS.md` -- §25 privilege firewall closure, §26 tenant_subscriptions row_version
- `docs/truth/privilege_truth.json` -- no change (end-state already correct after 9.1)
- `docs/waivers/WAIVER_PR417.md` -- consolidated waiver for 8 historical M4 retro-edit findings

## Justification
10.8.3B closes all FAIL findings from the 10.8.3A audit:
- Forward migration 000003: REVOKE EXECUTE FROM PUBLIC on current_tenant_id() and
  foundation_log_activity_v1() -- historical privilege gaps identified in audit.
- Forward migration 000004: row_version added to tenant_subscriptions per GUARDRAILS S8.
- 19 test files: Non-ASCII characters replaced with ASCII equivalents.
- 6_3 and 6_4 test files: wrapped in BEGIN/ROLLBACK per GUARDRAILS S29K.
- 10_8_1A test file: row_version column assertion added.
- 8 historical M4 retro-edit findings: consolidated waiver WAIVER_PR417.md.
- 6_11 and 7_10 test files: Non-ASCII fixed (late findings not in 10.8.3A audit).

## No Breaking Changes
- No existing RPC signature changes
- No schema changes to existing tables (only column addition to tenant_subscriptions)
- All test changes are content fixes only

## Status
Implementation complete. Tests: 329/329 PASS. CI green.