# Governance Change — PR080

## What changed
- Added CI job cloud-schema-drift to .github/workflows/ci.yml
- Registered cloud-schema-drift in docs/truth/required_checks.json via truth:sync
- Added cloud-schema-drift to required.needs aggregate
- Updated qa_claim.json, qa_scope_map.json, ci_robot_owned_guard.ps1

## Why safe
- Reuses existing scripts/cloud_schema_drift_check.ps1 (no new drift logic)
- Reuses existing DATABASE_URL secret (no new credentials)
- Additive CI job only

## Risk
- Job depends on cloud DB reachability from CI runner. If cloud is down, job fails.

## Rollback
- Revert PR. Remove job from ci.yml and required.needs.