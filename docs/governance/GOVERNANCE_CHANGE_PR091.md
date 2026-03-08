# Governance Change — PR091

## What changed
Updated truth bookkeeping files for Build Route 8.2 (Local DB tests proof). Updated qa_claim.json to 8.2, added 8.2 entry to qa_scope_map.json, allowlisted 8.2 proof log pattern in ci_robot_owned_guard.ps1.

## Why safe
Proof-only item. No CI workflow changes. No gate logic changes. No migrations. No schema changes. Only truth bookkeeping updates to support proof generation for 8.2.

## Risk
None. No enforcement surface modified. Only truth file updates for proof tracking.

## Rollback
Revert qa_claim.json, qa_scope_map.json, and ci_robot_owned_guard.ps1 changes. Single-commit revert.