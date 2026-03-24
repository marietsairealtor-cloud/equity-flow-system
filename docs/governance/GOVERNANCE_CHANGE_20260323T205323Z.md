# GOVERNANCE_CHANGE — CI Wiring Fix: cloud-schema-drift docs_only skip

Item: fix/docs-only-ci-skip-wiring
Date: 2026-03-23

---

## What changed

Added `needs: [changes]` and `if: needs.changes.outputs.docs_only != 'true'` to the `cloud-schema-drift` job in `.github/workflows/ci.yml`. The job previously had no `if` condition and ran unconditionally on all PRs, including docs-only and governance-only PRs. It now follows the same docs_only skip pattern as all other DB-heavy jobs in the workflow.

---

## Why safe

This is a wiring alignment fix only. No gate logic is changed — the cloud-schema-drift script is unchanged. The fix brings this job into conformance with Build Route §2.7 (docs-only CI skip contract) which requires DB-heavy jobs to be skipped mechanically on docs-only PRs. All non-docs-only PRs continue to run this job exactly as before.

---

## Risk

Low. The `changes` job and `docs_only` output are already established and used by all other DB-heavy jobs in the workflow. This job is now consistent with the rest. No required checks are affected — cloud-schema-drift is not in required_checks.json as merge-blocking.

---

## Rollback

Revert the two inserted lines (`needs: [changes]` and `if: needs.changes.outputs.docs_only != 'true'`) from the cloud-schema-drift job in `.github/workflows/ci.yml`. Job reverts to unconditional execution on all PRs.
