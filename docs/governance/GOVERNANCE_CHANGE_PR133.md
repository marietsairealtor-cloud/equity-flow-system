# GOVERNANCE_CHANGE_PR133.md

## Governance Change — Migration + pgTAP Test Integrity Discipline

**PR:** 133
**Date:** 2026-03-18
**Author:** QA

---

## What changed

GUARDRAILS.md: new section `## pgTAP + Migration Authoring Discipline` inserted between §28 and §29. Rules 29A–29M added. Authoring Law (LOCKED): migration is truth, test verifies truth, fix migration first, test is frozen until migration is correct, test that passes without the migration is dead code. Test file naming rule: test filename must match migration filename with timestamp stripped and `.test.sql` appended — item ID prefix mandatory, `.test.sql` only. Test authoring rules: RPC behavioral tests must call the RPC and inspect return value, isolation tests must prove negative outcome directly, state-change RPCs need post-call state verification, plan count must match exactly, BEGIN/ROLLBACK required. Corrective migration exception: encoding/comment-only migrations are intentionally unpaired — UNPAIRED-CORRECTIVE is acceptable in audit logs. Violation consequence (LOCKED): modifying a test to pass without fixing the migration requires PR revert, INCIDENTS.md entry, and QA remediation approval before branch may reopen. No existing rules modified or renumbered.

SOP_WORKFLOW.md: two additions only. Phase 1 Step 2 new gate pre-check: scan all migration SQL comments for non-ASCII characters before committing — no `§`, `—`, `→`, or any Unicode punctuation permitted, ASCII hyphens and alphanumeric text only, fix before first commit not after schema drift surfaces in CI. Section 13 Forbidden Actions new bullet: modify a test to achieve a passing CI run without first correcting the underlying migration. No existing rules modified.

BUILD_ROUTE_V2_4.md: items 10.8.3A (Migration + pgTAP Retrospective Audit) and 10.8.3B (Migration + pgTAP Test Remediation) inserted immediately after 10.8.3. Standing Rule — Migration-First Authoring (LOCKED) appended after 10.8.3B, effective from 10.8.3B merge forward. 10.8.3A and 10.8.3B are blocking — no item after 10.8.3 may merge until 10.8.3B is closed. No existing items modified.

---

## Why safe

All changes are additive only. No existing GUARDRAILS rules are modified or renumbered — new rules are numbered 29A–29M to sit between existing §28 and §29 without disturbing any current citations. No existing SOP sections are restructured — two bullets added only. No existing Build Route items are modified — two items inserted only. No new CI gates are introduced — enforcement uses existing `qa:verify`, `proof-commit-binding`, and the full existing gate stack. No truth files changed. No schema changes. No migration changes. The governance change guard itself is the only CI gate that fires on this PR, and it is satisfied by this file.

---

## Risk

Low. No mechanical enforcement changes — no new gates, no new required checks, no truth file modifications. The rules added to GUARDRAILS are authoring discipline rules enforced by QA review and the existing violation consequence path (INCIDENTS.md + PR revert), not by new automated gates. The SOP addition is a pre-check instruction to coders — no tooling dependency. The Build Route additions are specification only; their gates are existing infrastructure. The only risk is if a coder reads the new GUARDRAILS §29F naming rule and renames test files without going through the proper rename PR — mitigated by the fact that renaming is already scoped to a separate tracked item (test file rename map produced by QA this session).

---

## Rollback

Revert this PR. All four changes are in one file set — reverting the PR restores GUARDRAILS, SOP_WORKFLOW, and BUILD_ROUTE_V2_4 to their prior state exactly. No truth files to revert. No migrations to revert. No CI gate registrations to undo. Rollback is a single revert merge with no secondary cleanup required.