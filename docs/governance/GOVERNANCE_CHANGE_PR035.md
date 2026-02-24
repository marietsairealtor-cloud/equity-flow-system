# Governance Change — PR035

## What changed
- `docs/truth/qa_claim.json` — updated to 5.0
- `docs/truth/qa_scope_map.json` — added 5.0 entry
- `docs/truth/completed_items.json` — added 5.0
- `scripts/ci_robot_owned_guard.ps1` — allowlisted 5.0 proof log

## What 5.0 establishes
Hardened DoD for required gates inventory. Rules for future gate registrations:
- Gates registered in required_checks.json only in the PR that creates the corresponding CI job — no batch updates
- No gate registered before its CI job exists string-exact in .github/workflows/**
- Each registration PR triggers governance-change-guard and must include GOVERNANCE_CHANGE_PR<NNN>.md
- npm run truth:sync must be run in each registration PR

## Current state
- anon-privilege-audit: registered in 4.4 PR ✓
- rls-strategy-consistent: registered in 4.5 PR ✓
- migration-rls-colocation: not yet registered — CI job does not exist yet (5.1)
- unregistered-table-access: not yet registered — CI job does not exist yet (6.3A)
- calc-version-registry: not yet registered — CI job does not exist yet (7.6)

## Why safe
- No CI logic, enforcement semantics, or required check contexts modified
- Proof-only + DoD recording item

## Authority
Build Route v2.4 Item 5.0 hardened DoD.