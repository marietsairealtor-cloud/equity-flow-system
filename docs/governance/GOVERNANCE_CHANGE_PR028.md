# Governance Change — PR028

## What changed
- `docs/truth/github_policy_snapshot.json` — regenerated policy drift snapshot after repo ownership change

## Why
Repo ownership transfer caused the committed snapshot to diverge from live GitHub API state. The policy-drift-attestation job detects this as drift and fails. Snapshot regenerated via WRITE_SNAPSHOT=1 against current repo state — no actual policy change occurred.

## Why safe
- No policy change — snapshot reflects the same ruleset (MAIN-BRANCH-RULES, id 12578327) that was previously committed
- Branch protection API now returns 404 (no classic protection) instead of 403 — handled by PR027 fix
- Required check context "required" is still enforced via ruleset

## Risk
- Low. Snapshot update only — governance enforcement surface unchanged.

## Rollback
- Revert docs/truth/github_policy_snapshot.json to prior version
- Regenerate correct snapshot via WRITE_SNAPSHOT=1
- One PR, CI green, merge