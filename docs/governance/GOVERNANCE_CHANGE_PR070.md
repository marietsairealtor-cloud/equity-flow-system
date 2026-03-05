# Governance Change PR070 — 7.6 calc_version Change Protocol

## What changed
Added calc_version change protocol gate. New files: docs/truth/calc_version_registry.json (authoritative registry of all calc_version values), scripts/ci_calc_version_lint.ps1 (gate script). Wired calc-version-registry job into ci.yml as merge-blocking. Registered CI / calc-version-registry in required_checks.json. Triple-registered calc_version_registry.json: robot-owned guard, truth-bootstrap validation, handoff existence check. Added pgTAP test proving deal seeded at calc_version=1 returns identical inputs on reopen after version context changes.

## Why safe
Purely additive gate. No existing migrations, schema, RPC, or policy changes. The gate only fails when calculation logic files change without an accompanying registry update — a condition that should never occur in a compliant PR. The registry correctly documents the existing baseline calc_version=1.

## Risk
Low. Any PR that legitimately changes calc logic will also update the registry as required. The triple-registration ensures the registry cannot drift silently. No false positives expected on compliant PRs that do not touch calc logic files.

## Rollback
Remove calc-version-registry job from ci.yml, remove CI / calc-version-registry from required_checks.json, remove calc_version_registry.json from truth-bootstrap and robot-owned guard, delete scripts/ci_calc_version_lint.ps1 via a single governance PR.
