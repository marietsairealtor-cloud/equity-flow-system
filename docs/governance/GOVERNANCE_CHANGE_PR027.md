# Governance Change — PR027

## What changed
- `scripts/policy_drift_attest.mjs` — catch 403 on branch protection API in addition to 404

## Why
Repo ownership transfer caused GitHub API to return 403 (forbidden) instead of 404 (not found) on the classic branch protection endpoint. Script only handled 404 — causing policy-drift-attestation to fail on every scheduled run. Fix treats 403 as "no classic branch protection configured" — same as 404 — and falls through to ruleset-based detection which was already working correctly (HTTP 200).

## Why safe
- One-line change: `e.status === 404` → `e.status === 404 || e.status === 403`
- No logic change when classic branch protection exists
- Ruleset detection path unchanged and already working
- Fix restores intended behavior — not a security weakening

## Risk
- Low. Defensive error handling fix. No governance surface, schema, or security policy changed.

## Rollback
- Revert scripts/policy_drift_attest.mjs to pre-PR027 version
- One PR, CI green, merge