# Governance Change — PR083

## What changed
Added new CI job `ci-db-smoke` to `.github/workflows/ci.yml` that starts Supabase in the GitHub Actions runner and confirms database connectivity via psql smoke query. Job added to `required.needs` block making it merge-blocking.

## Why safe
This is additive-only. No existing jobs are modified. The new job runs only on non-docs-only PRs (gated by lane-enforcement). No stub gates are converted. No deferred_proofs.json entries are touched. The only new enforcement surface is the CI DB smoke job per Section 3.0 constraints.

## Risk
Low. Job may fail if Supabase CLI install or Docker pull times out in the runner. This would block PRs but is recoverable by re-running CI. No security surface is weakened.

## Rollback
Remove the `ci-db-smoke` job from ci.yml and remove `ci-db-smoke` from `required.needs`. Run `npm run truth:sync` to regenerate required_checks.json. Single-commit revert.