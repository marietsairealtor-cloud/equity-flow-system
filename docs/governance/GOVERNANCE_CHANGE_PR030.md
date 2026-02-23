# Governance Change — PR030

## What changed
- `.github/workflows/policy-drift-attestation.yml` — removed git push steps, changed to attestation-only
  - Removed: git config, git add, git commit, git push
  - Changed: permissions contents:write → contents:read
  - Kept: node script execution, proof log generation, grep validation checks

## Why
Workflow was attempting to push proof logs directly to main via --force-with-lease. Branch ruleset blocks all direct pushes to main — "Changes must be made through a pull request." Option 3 (remove push) is the only compliant fix per QA ruling.

## Authority
QA ruling 2026-02-23. Build Route 2.16.1 frames this as a drift detector — not a self-committing CI job. Proof logs committed via PR only.

## Why safe
- Attestation behavior unchanged — still fails loudly on drift
- Proof logs still generated in CI workspace (visible in job output)
- No bypass path to main added
- permissions downgraded from write to read

## Risk
- Low. Removes non-compliant behavior. Attestation integrity unchanged.

## Rollback
- Revert .github/workflows/policy-drift-attestation.yml to pre-PR030 version
- One PR, CI green, merge