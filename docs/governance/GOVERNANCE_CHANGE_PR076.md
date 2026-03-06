# Governance Change — PR076

## What changed
- Added pgTAP test: 7.10 tenant_role ordering + role-guard semantics invariant
- Updated docs/truth/qa_claim.json to 7.10
- Updated docs/truth/qa_scope_map.json with 7.10 entry
- Updated scripts/ci_robot_owned_guard.ps1 with 7.10 proof log allowlist

## Why safe
- No enforcement logic changed. Additive test + truth bookkeeping only.
- All existing gates remain unchanged.

## Risk
- None. No schema, RLS, privilege, or CI workflow changes.

## Rollback
- Revert PR. No downstream dependencies.