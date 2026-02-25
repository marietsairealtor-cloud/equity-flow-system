# GOVERNANCE_CHANGE_PR040

## Item
Build Route v2.4 — 6.1A Handoff Preconditions Hardening

## Changes
- scripts/ci_handoff_preconditions.ps1 — new DB-state preconditions gate
- scripts/handoff.ps1 — 6.1A preconditions block added (runs before truth artifact generation)
- package.json — handoff:preconditions npm script added
- .github/workflows/ci.yml — handoff-preconditions job added, wired into required:
- docs/truth/required_checks.json — CI / handoff-preconditions added
- docs/truth/qa_claim.json — updated to 6.1A
- docs/truth/qa_scope_map.json — added 6.1A entry
- docs/truth/completed_items.json — added 6.1A
- scripts/ci_robot_owned_guard.ps1 — allowlisted 6.1A proof log pattern

## Rationale
Upgrades handoff preconditions from schema-text regex (must_contain) to live DB-state
catalog validation. Prevents handoff from generating truth artifacts when baseline
invariants are not satisfied in the actual database. Gate is merge-blocking for
DB/runtime lane PRs; docs-only lane may skip.

## Gate impact
New merge-blocking CI job: handoff-preconditions
