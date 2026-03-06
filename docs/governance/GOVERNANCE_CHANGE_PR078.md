# Governance Change — PR078

## What changed
- Added Build Route item 7.11A — Cloud Schema Drift CI Gate
- Converts operator-run 7.11 drift check into a merge-blocking CI job
- New CI job: cloud-schema-drift
- New required check: cloud-schema-drift

## Why safe
- Build Route amendment only. No code, no schema, no CI workflow changes in this PR.
- Implementation will follow in a separate PR per one-objective-one-PR rule.

## Risk
- None. Document change only.

## Rollback
- Revert PR. No downstream dependencies.