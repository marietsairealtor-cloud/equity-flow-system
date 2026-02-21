# Governance Change — PR019

## What changed
- `docs/truth/completed_items.json` — new hand-authored registry of completed Build Route items (63 items)
- `scripts/ci_qa_scope_coverage.ps1` — new gate asserting every completed item has a qa_scope_map.json entry
- `.github/workflows/ci.yml` — qa-scope-coverage job added, wired into required:
- `docs/truth/required_checks.json` — CI / qa-scope-coverage added
- `docs/truth/qa_claim.json` — updated to 3.9.3
- `docs/truth/qa_scope_map.json` — added 3.9.3 entry
- `scripts/ci_robot_owned_guard.ps1` — allowlisted 3.9.3 proof log

## Decisions declared (per DoD)
- DEVLOG format: Option B — separate registry file (completed_items.json). DEVLOG remains human-readable prose. No retroactive edits to existing entries.
- completed_items.json is hand-authored, §3.0.4c exemption applies.

## Why safe
- Gate is read-only: cross-references completed_items.json against qa_scope_map.json
- No schema, migration, or security surface touched
- Deliberate-failure regression test confirms gate names missing items explicitly

## Risk
- Low. New merge-blocking gate closes blind spot where unmapped items trivially pass qa:verify.

## Rollback
- Remove scripts/ci_qa_scope_coverage.ps1
- Remove docs/truth/completed_items.json
- Remove qa-scope-coverage job from ci.yml and required: needs
- Remove CI / qa-scope-coverage from required_checks.json
- One PR, CI green, QA approve, merge