## What changed
Added scripts/sync_truth_registries.mjs integrated into npm run handoff. Wired into handoff.ps1 after existing generators. Updated docs/truth/robot_owned_paths.json to version 2 adding tenant_table_selector.json, definer_allowlist.json, and execute_allowlist.json as robot-owned paths. Updated scripts/ci_governance_change_guard.ps1 to accept both GOVERNANCE_CHANGE_PR<NNN>.md and GOVERNANCE_CHANGE_<UTC>.md naming formats. SOP_WORKFLOW.md updated to define manual vs robot responsibilities and commit sequence. Build Route 10.8.12 absorbed into this item.

## Why safe
sync_truth_registries.mjs exits 0 gracefully when DATABASE_URL is absent - docs-only CI runs are unaffected. The governance guard change is backward compatible - legacy PR<NNN> format still accepted. robot_owned_paths.json version bump is additive. No enforcement gates removed or weakened.

## Risk
Medium. Four truth files (tenant_table_selector, definer_allowlist, execute_allowlist, cloud_migration_parity) transition from hand-authored to machine-derived. If the Postgres catalog query returns unexpected results, these files could be incorrectly overwritten. Mitigated by: determinism test (double handoff produces zero diffs), graceful DB skip, and CI schema-drift gate catching any surface divergence.

## Rollback
Revert PR implementing 10.8.6A. Remove sync_truth_registries.mjs, revert handoff.ps1, robot_owned_paths.json, ci_governance_change_guard.ps1, and SOP_WORKFLOW.md to prior state. Manually restore the four truth files to their last known good values.