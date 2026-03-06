# Governance Change — PR077

## What changed
- Updated docs/ops/STUDIO_MUTATION_POLICY.md with deploy-triggered drift check SLA and incident trigger (7.11)
- Created docs/ops/RELEASE_CHECKLIST.md with mandatory drift check checkbox
- Updated docs/truth/qa_claim.json to 7.11
- Updated docs/truth/qa_scope_map.json with 7.11 entry
- Updated scripts/ci_robot_owned_guard.ps1 with 7.11 proof allowlist

## Why safe
- No CI, schema, RLS, or privilege changes. Ops docs and truth bookkeeping only.

## Risk
- None. Additive operational policy only.

## Rollback
- Revert PR. No downstream dependencies.