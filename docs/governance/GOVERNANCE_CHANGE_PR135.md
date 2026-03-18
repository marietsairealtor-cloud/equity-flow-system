# GOVERNANCE_CHANGE_PR135.md

## Governance Change -- Migration + pgTAP Test Integrity Discipline + Design Audit

**PR:** 135
**Date:** 2026-03-18
**Author:** QA

---

## What changed

GUARDRAILS.md: new section ## pgTAP + Migration Authoring Discipline inserted between SS28 and SS29. Rules 29A-29M added. Authoring Law (LOCKED): migration is truth, test verifies truth, fix migration first, test is frozen until migration correct, test passing without migration is dead code. Test file naming rule (29F): test filename must match migration filename with timestamp stripped and .test.sql appended -- item ID prefix mandatory, .test.sql only. Test authoring rules (29G-29K): RPC behavioral tests must call RPC and inspect return value, isolation tests must prove negative outcome directly, state-change RPCs need post-call state verification, plan count must match exactly, BEGIN/ROLLBACK required. Corrective migration exception (29L): encoding/comment-only migrations are intentionally unpaired -- UNPAIRED-CORRECTIVE acceptable in audit logs. Violation consequence (29M, LOCKED): test modified to pass without fixing migration = PR revert + INCIDENTS.md entry + QA remediation approval required. No existing rules modified or renumbered.

SOP_WORKFLOW.md: two additions only. Phase 1 Step 2: new gate pre-check bullet -- scan all migration SQL comments for non-ASCII characters before committing. No section signs, em dashes, arrows, or any Unicode punctuation permitted in SQL comments. ASCII hyphens and alphanumeric text only. Fix before first commit -- do not wait for schema drift to surface in CI. Section 13 Forbidden Actions: new bullet -- modify a test to achieve a passing CI run without first correcting the underlying migration. No existing rules modified.

BUILD_ROUTE_V2_4.md: items 10.8.3A, 10.8.3B, and 10.8.3C inserted immediately after 10.8.3. 10.8.3A: retrospective audit of all migrations and test files -- coder draft plus QA independent validation plus signed sign-off, both required. Checklist M1-M11 (migration) plus T1-T8 (test). Gate: qa:verify plus proof-commit-binding. 10.8.3B: remediation of all FAIL findings from 10.8.3A -- migration fixed first, CI confirmed, then test rewritten. Includes explicit DoD item for consolidating REVOKE EXECUTE FROM PUBLIC forward migration (single atomic file, not split across PRs) and explicit DoD item for tenant_subscriptions row_version fix (B9-F04). FIXED requires CI run link. WAIVED requires waiver file plus QA sign-off plus expiry. Gate: full existing suite. 10.8.3C: QA-independent design correctness audit of 13 security-critical items (6.7, 7.4, 7.8, 7.9, 8.4, 8.6, 8.7, 8.8, 8.9, 8.10, 9.4, 9.5, 9.7). QA reads Build Route DoD per item and independently verifies migration implements it and test suite proves it. Three verdicts: PASS, PASS-WITH-NOTES, FAIL. FAIL findings require tracking PR but do not block 10.8.3C close. Gate: lane-only, required before Section 10 close verification. 10.8.3A and 10.8.3B are merge-blocking on all subsequent items. 10.8.3C is not merge-blocking but is a Section 10 close prerequisite.

Test file rename map produced: 11 test files renamed per GUARDRAILS SS29F to match migration filename pattern. Rename PR is a prerequisite for 10.8.3A audit log finalization.

---

## Why safe

All changes are additive only. No existing GUARDRAILS rules modified or renumbered -- new rules are numbered 29A-29M to sit between existing SS28 and SS29 without disturbing any current citations. No existing SOP sections restructured -- two bullets added only. No existing Build Route items modified -- three items inserted only. No new CI gates introduced -- enforcement uses existing qa:verify, proof-commit-binding, and full existing gate stack. No truth files changed. No schema changes. No migration changes. The governance change guard itself is the only CI gate that fires on this PR, and it is satisfied by this file. The three new Build Route items (10.8.3A/B/C) do not require new gate registrations -- all enforcement uses existing infrastructure.

---

## Risk

Low. No mechanical enforcement changes -- no new gates, no new required checks, no truth file modifications. GUARDRAILS rules 29A-29M are authoring discipline rules enforced by QA review and the existing violation consequence path, not by new automated gates. The SOP addition is a pre-check instruction to coders with no tooling dependency. The Build Route additions are specification only. The consolidating REVOKE FROM PUBLIC migration (10.8.3B DoD item 9) closes a genuine privilege gap identified by the audit but introduces no behavioral change to the application -- it only enforces what was already the stated policy. The tenant_subscriptions row_version addition (B9-F04) is a schema hardening fix with no breaking change to existing callers. The only risk is if the test file rename PR (11 renames) introduces a path mismatch in qa_scope_map.json entries -- mitigated by requiring those entries to be updated in the same rename PR.

---

## Rollback

Revert this PR. All changes are in one file set -- reverting restores GUARDRAILS, SOP_WORKFLOW, and BUILD_ROUTE_V2_4 to their prior state exactly. No truth files to revert. No migrations to revert. No CI gate registrations to undo. Rollback is a single revert merge with no secondary cleanup required. The test file rename PR is separate and can be independently reverted if needed without touching this PR.
