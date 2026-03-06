# Governance Change — PR082

## What changed
- Added §17 Public RPC Mapping table to docs/artifacts/CONTRACTS.md
- Created scripts/ci_rpc_mapping_contract.ps1 gate script
- Added CI job rpc-mapping-contract to .github/workflows/ci.yml
- Registered rpc-mapping-contract in required_checks.json via truth:sync
- Updated qa_claim.json, qa_scope_map.json, ci_robot_owned_guard.ps1

## Why safe
- Additive policy enforcement. No schema, RLS, or privilege changes.
- Gate triggers only when migrations contain RPC definitions.
- All existing RPCs mapped in CONTRACTS.md §17.

## Risk
- False positives if migration contains internal helper matching _v1 pattern. Mitigated by explicit exclusion list in script.

## Rollback
- Revert PR. Remove job from ci.yml and §17 from CONTRACTS.md.