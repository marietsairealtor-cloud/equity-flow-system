## What changed
Added triple-registration for 10.8.5 proof log pattern in `scripts/ci_robot_owned_guard.ps1`. Updated `docs/truth/execute_allowlist.json` to add `current_tenant_id` per QA ruling 2026-03-19. Updated `docs/truth/privilege_truth.json` to document the authenticated EXECUTE exception. Updated `docs/truth/tenant_table_selector.json` to register `deal_tc` and `deal_tc_checklist` as tenant-owned tables.

## Why safe
All changes are additive or narrow corrections. The `current_tenant_id` EXECUTE grant to `authenticated` is a QA-authorized remediation of an overly broad REVOKE FROM PUBLIC applied in 10.8.3B. No existing enforcement rules removed. No gates weakened.

## Risk
Low. The `current_tenant_id` EXECUTE restoration is narrowly scoped to `authenticated` only - not PUBLIC or anon. RLS isolation remains enforced. The execute_allowlist addition ensures the definer-safety-audit gate tracks this grant going forward.

## Rollback
Revert PR140. This removes all 10.8.5 migrations, tests, truth file updates, and governance registrations cleanly. The current_tenant_id EXECUTE grant would need a compensating REVOKE migration if rollback is required post-merge.