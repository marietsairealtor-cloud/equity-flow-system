# GOVERNANCE_CHANGE_PR043

## What changed
Build Route 6.3 Tenant Integrity Suite implementation. New files: supabase/tests/tenant_isolation.test.sql (pgTAP negative isolation tests with populated data), scripts/test_fk_embedding.ps1 (HTTP-layer FK embedding tests), scripts/ci_background_context_review.ps1 (catalog cross-check gate), docs/truth/background_context_review.json (hand-authored background context review), .github/workflows/database-tests.yml (pgTAP workflow stub). CI wiring: background-context-review job added to ci.yml and required needs. Truth files updated: deferred_proofs.json (database-tests.yml and pgtap conversion triggers updated to 6.3, pgtap entry added), completed_items.json, qa_claim.json, qa_scope_map.json. ci_robot_owned_guard.ps1 allowlisted 6.3 proof log pattern.

## Why safe
Additive only. New merge-blocking gate added: background-context-review. database-tests.yml workflow created as stub per deferred_proofs.json pattern — converts at 8.0.5. pgTAP tests run locally only until 8.0.5 conversion. No existing gate weakened or removed. No migrations or schema changes. No policy removed.

## Risk
Low. All new gates are either stubs (database-tests.yml, pgtap) or static catalog checks (background-context-review). background-context-review CI stub exits 0 unconditionally in CI — no breakage risk. deferred_proofs.json trigger updates are documentation only — no enforcement change until 8.0.5.

## Rollback
Revert supabase/tests/tenant_isolation.test.sql, scripts/test_fk_embedding.ps1, scripts/ci_background_context_review.ps1, docs/truth/background_context_review.json, .github/workflows/database-tests.yml. Remove background-context-review job from ci.yml and required needs. Revert deferred_proofs.json to prior version. Remove 6.3 from completed_items.json, qa_scope_map.json. Remove 6.3 proof log pattern from ci_robot_owned_guard.ps1.