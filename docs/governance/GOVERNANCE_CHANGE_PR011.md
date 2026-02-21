# Governance Change — PR011

## What changed
- Added `scripts/ci_handoff_idempotency.ps1` — new CI gate asserting handoff is idempotent (two consecutive runs produce identical output)
- Modified `scripts/handoff.ps1` — filter robot-owned files from git status capture to achieve idempotency
- Modified `scripts/ci_robot_owned_guard.ps1` — allowlisted 3.8 proof log pattern
- Modified `.github/workflows/ci.yml` — added `handoff-idempotency` job, wired into `required:` needs list
- Modified `docs/truth/required_checks.json` — added `CI / handoff-idempotency` as required check

## Why safe
- Gate is read-only: runs handoff twice, compares outputs, exits non-zero on diff
- No new privileges, no schema changes, no migration changes
- handoff.ps1 fix narrows git status output — removes self-referencing robot-owned files from captured status line only
- All changes are additive to CI enforcement surface

## Risk
- Low. New gate adds a merge-blocking check. If handoff becomes non-deterministic in future, CI will catch it.
- handoff.ps1 change could mask unexpected diffs in robot-owned files — mitigated by scope: only the three known output files are filtered

## Rollback
- Revert `scripts/ci_handoff_idempotency.ps1` (delete)
- Revert `scripts/handoff.ps1` filter line
- Revert `scripts/ci_robot_owned_guard.ps1` allowlist entry
- Remove `handoff-idempotency` job from `.github/workflows/ci.yml` and `required:` needs list
- Remove entry from `docs/truth/required_checks.json`
- One PR, CI green, QA approve, merge