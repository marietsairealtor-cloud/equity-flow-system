# Governance Change — PR117

## What changed

Build Route v2.4 Item 10.7 Gate Promotion Protocol. Merge-blocking.
New truth file: docs/truth/gate_promotion_registry.json (version 1) —
4 entries covering all conditional named gates in Section 10.
New verifier script: scripts/ci_gate_promotion_registry.mjs.
CI job gate-promotion-registry added to ci.yml and required.needs.
scripts/ci_semantic_contract.mjs updated to allowlist
npm run gate-promotion-registry. required_checks.json regenerated
via truth:sync.

## Registry entries (initial population per DoD 5)

1. weweb-drift (10.2) — lane-only, promoted_by null
2. rpc-error-contracts (10.5) — merge-blocking, promoted_by PR115
3. frontend-contract-guard (10.20) — lane-only, promoted_by null
4. surface-enumeration (10.21) — lane-only, promoted_by null

Scope: Section 10 only. Foundation gates (Sections 1-9) are permanently
merge-blocking and do not participate in the promotion lifecycle.

## CI checks enforced

Per QA ruling 2026-03-13:
1. merge-blocking entry: must exist in required_checks.json AND required.needs
2. lane-only entry: must NOT exist in required_checks.json or required.needs
3. merge-blocking entry: promoted_by must not be null
Foundational gates absent from registry do not trigger failures.

## Promotion PR requirements (enforced going forward)

- Gate moved from lane_checks.json to required_checks.json
- Gate wired into required.needs in ci.yml
- required_checks.json regenerated via truth:sync
- gate_promotion_registry.json entry updated: status -> merge-blocking,
  promoted-by -> PR number
- Governance file required
- DEVLOG entry required after merge

## Triple-registration

1. ci_robot_owned_guard.ps1: proof log path allowlisted
2. truth_bootstrap_check.mjs: gate_promotion_registry.json in required array
3. handoff.ps1: N/A (hand-authored file)

## ci_semantic_contract.mjs edit

npm run gate-promotion-registry added to hasAllowlistedGate allowlist.

## Rollback

Remove docs/truth/gate_promotion_registry.json,
scripts/ci_gate_promotion_registry.mjs, remove gate-promotion-registry
from ci.yml and required.needs, revert truth_bootstrap_check.mjs and
ci_semantic_contract.mjs changes, run truth:sync, open revert PR with
governance file.