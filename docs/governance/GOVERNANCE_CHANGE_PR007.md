# GOVERNANCE_CHANGE_PR007.md

## What changed
Added merge-blocking gate `governance-change-template-contract`. Gate runs only on governance-touch PRs (same matcher as 2.15) and validates a structured justification template.

## Why safe
Change is format-only enforcement. It does not alter system architecture, data paths, or permissions. It tightens traceability and blocks empty governance justifications.

## Risk
Risk is false failures if matcher diverges or template parsing is incorrect. Mitigation: reuse identical 2.15 matcher and enforce only presence/headings/length floor.

## Rollback
Revert the CI job and required check entry for `governance-change-template-contract`, and delete the new gate scripts. Governance-change-guard remains intact.
