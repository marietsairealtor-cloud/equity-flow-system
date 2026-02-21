# Governance Change — PR020

## What changed
- `scripts/ci_job_graph_contract.ps1` — new gate proving lane-enforcement is prerequisite of db-heavy
- `.github/workflows/ci.yml` — job-graph-ordering job added, wired into required:
- `docs/truth/required_checks.json` — CI / job-graph-ordering added
- `docs/truth/qa_claim.json` — updated to 3.9.4
- `docs/truth/qa_scope_map.json` — added 3.9.4 entry
- `docs/truth/completed_items.json` — added 3.9.4
- `scripts/ci_robot_owned_guard.ps1` — allowlisted 3.9.4 proof log

## Decisions declared (per DoD)
- Ordering option: Option A — db-heavy has lane-enforcement in direct needs: dependency
- This is proof-only — existing CI YAML already satisfies the ordering requirement
- No CI YAML job ordering changes needed

## Why safe
- Gate is read-only: parses ci.yml job graph, asserts needs: dependency, exits non-zero if missing
- No schema, migration, or security surface touched

## Risk
- Low. New merge-blocking gate asserts structural ordering invariant is maintained in perpetuity.

## Rollback
- Remove scripts/ci_job_graph_contract.ps1
- Remove job-graph-ordering job from ci.yml and required: needs
- Remove CI / job-graph-ordering from required_checks.json
- One PR, CI green, QA approve, merge