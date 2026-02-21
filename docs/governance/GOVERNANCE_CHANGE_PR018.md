# Governance Change — PR018

## What changed
- `docs/truth/governance_surface_definition.json` — new versioned definition of governance surface (12 path patterns, 3 documented exclusions)
- `docs/truth/governance_change_guard.json` — added BUILD_ROUTE_V2.4.md, RELEASES.md, governance_surface_definition.json to guard paths
- `scripts/ci_governance_path_coverage.ps1` — new gate asserting all governance-surface files are covered by guard
- `.github/workflows/ci.yml` — governance-path-coverage job added, wired into required:
- `docs/truth/required_checks.json` — CI / governance-path-coverage added
- `docs/truth/qa_claim.json` — updated to 3.9.2
- `docs/truth/qa_scope_map.json` — added 3.9.2 entry
- `scripts/ci_robot_owned_guard.ps1` — allowlisted 3.9.2 proof log

## Decisions declared (per DoD)
- package.json: Option B — excluded from governance scope. High-friction, low-security-risk.
- docs/governance/**: Excluded — circular. These files ARE the justification artifacts.
- docs/artifacts/BUILD_ROUTE_V2.4.md + RELEASES.md: Added to guard — governance-surface files.

## Why safe
- Gate is read-only: enumerates repo files, cross-references patterns, exits non-zero on gap
- No schema, migration, or security surface touched
- governance_surface_definition.json added to guard scope (DoD item 7 — self-registering)

## Risk
- Low. New merge-blocking gate adds coverage auditing. Cannot cause false positives on
  existing paths — only checks coverage completeness against surface definition.

## Rollback
- Remove scripts/ci_governance_path_coverage.ps1
- Remove docs/truth/governance_surface_definition.json
- Revert docs/truth/governance_change_guard.json
- Remove governance-path-coverage job from ci.yml and required: needs
- Remove CI / governance-path-coverage from required_checks.json
- One PR, CI green, QA approve, merge