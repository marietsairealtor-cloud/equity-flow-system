# Governance Change PR067 — 7.3 Policy Coupling Gate

## What changed
Added merge-blocking gate `policy-coupling` that enforces: if `generated/contracts.snapshot.json` changes in a PR, `docs/artifacts/CONTRACTS.md` must also change in the same PR. Gate implemented in `scripts/ci_policy_coupling.ps1`, wired into `ci.yml` as job `policy-coupling`, registered in `docs/truth/required_checks.json` as `CI / policy-coupling`.

## Why safe
This gate is purely additive. It enforces an existing policy from CONTRACTS.md §11 (contract change policy) that was previously only a human convention. No existing migrations, schema, or RPC behavior is altered. The gate only fails when snapshot changes without accompanying documentation — a condition that should never occur in a compliant PR.

## Risk
Low. Any PR that legitimately changes the contracts snapshot will also change CONTRACTS.md as required by existing policy. The gate formalizes what was already required. No false positives expected on compliant PRs.

## Rollback
Remove the `policy-coupling` job from `ci.yml`, remove `CI / policy-coupling` from `required_checks.json`, and delete `scripts/ci_policy_coupling.ps1` via a single governance PR.
