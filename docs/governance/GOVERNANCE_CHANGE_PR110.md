# GOVERNANCE_CHANGE_PR110.md

## What changed

Build Route v2.4 Item 10.2 WeWeb drift guard. Lane-only — not promoted to merge-blocking CI gate per Section 10 scope-control policy. New truth file docs/truth/weweb_endpoints_truth.json defines allowed RPC endpoint patterns and forbidden direct table access patterns. New script scripts/ci_weweb_drift_guard.mjs scans repo-owned files for forbidden /rest/v1/<table> direct access patterns and fails if any are detected. npm script weweb:drift wired. qa_claim.json updated to 10.2. qa_scope_map.json entry added. ci_robot_owned_guard.ps1 allowlisted for 10.2 proof log path.

## Why safe

No migration, no DB object change, no merge-blocking CI gate wiring. Verifier is read-only — scans repo files only, makes no network calls, modifies no files. The forbidden pattern list matches core tables that already have no SELECT grants to anon or authenticated (enforced by 9.6 data-surface-truth gate). This item adds detection of accidental drift in repo-owned frontend artifacts only.

## Risk

None. No runtime behavior changes. No CI topology changes. Script is additive only. test_postgrest_isolation.mjs excluded from scan as it references forbidden patterns as negative probe evidence.

## Rollback

Remove scripts/ci_weweb_drift_guard.mjs, docs/truth/weweb_endpoints_truth.json, and weweb:drift package.json entry via a follow-up PR. No DB state affected.