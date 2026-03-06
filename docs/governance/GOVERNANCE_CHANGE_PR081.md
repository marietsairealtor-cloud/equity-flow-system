# Governance Change — PR081

## What changed
- Hardened scripts/cloud_schema_drift_check.ps1 normalization to handle pg_dump v16 vs v17 formatting differences
- Added identifier quote stripping and whitespace collapsing before comparison
- No new CI jobs, no schema changes, no truth file changes

## Why safe
- Script logic change only. Normalization is additive — strips cosmetic differences, does not mask real drift.
- Existing drift detection behavior preserved for actual schema divergence.

## Risk
- Over-normalization could mask real drift. Mitigated by limiting normalization to identifier quoting and whitespace only.

## Rollback
- Revert PR. Drift check reverts to strict byte comparison.