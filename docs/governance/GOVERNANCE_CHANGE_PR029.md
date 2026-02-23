# Governance Change — PR029

## What changed
- `scripts/policy_drift_attest.mjs` — added BRANCH= line to stdout output

## Why
policy-drift-attestation.yml workflow validates proof log contains BRANCH= line via grep. Script was not emitting this line, causing workflow to fail after the OK: snapshot match succeeded.

## Why safe
- One-line addition: console.log(`BRANCH=...`) emitted early in script output
- No logic change to snapshot comparison, ruleset detection, or drift reporting
- Restores intended workflow behavior

## Risk
- Low. Output-only change. No governance surface, schema, or security policy changed.

## Rollback
- Revert scripts/policy_drift_attest.mjs to pre-PR029 version
- One PR, CI green, merge