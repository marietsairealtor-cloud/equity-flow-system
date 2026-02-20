# GOVERNANCE_CHANGE_PR008

## What Changed
- Made governance-change-guard merge-blocking by adding it to required.needs in CI.

## Why
- Enforce hard merge-blocking on governance-scoped mutations.

## Impact
- CI now blocks merges if governance paths change without justification.

## Rollback
- Remove governance-change-guard from required.needs in .github/workflows/ci.yml.
