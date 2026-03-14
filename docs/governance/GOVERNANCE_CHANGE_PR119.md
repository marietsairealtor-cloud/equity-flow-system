# Governance Change — PR119

## What changed

Build Route v2.4 Item 10.7.1 Legacy Gate Promotion Retrofit.
docs/truth/gate_promotion_registry.json updated with 3 new lane-only
entries for historical gates with explicit promotion triggers:

- command-smoke-db (Build Route 4.2a): promote to merge-blocking only after stable
- surface-truth (Build Route 9.1): lane-only until stable
- ci_validator (Build Route 2.17.4): promote only if it catches real corruption

Registry entries: 4 (10.7) -> 7 (10.7.1).

## Why safe

All three new entries are lane-only with promoted_by null. Verifier
confirms none are in required_checks.json or required.needs.
No CI topology changes. No migrations. No schema changes.
gate-promotion-registry gate passes with 7 entries.

## Triple-registration

1. ci_robot_owned_guard.ps1: proof log path allowlisted
2. truth_bootstrap_check.mjs: N/A (gate_promotion_registry.json already registered in 10.7)
3. handoff.ps1: N/A (hand-authored file)

## Rollback

Remove the 3 new entries from gate_promotion_registry.json via
follow-on PR with governance file.