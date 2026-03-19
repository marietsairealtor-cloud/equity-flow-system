## What changed
Added proof log pattern for 10.8.6 in scripts/ci_robot_owned_guard.ps1. Added list_farm_areas_v1, create_farm_area_v1, delete_farm_area_v1 to docs/truth/definer_allowlist.json, execute_allowlist.json, rpc_contract_registry.json, and privilege_truth.json authenticated routines and migration_grant_allowlist. Added tenant_farm_areas to docs/truth/tenant_table_selector.json.

## Why safe
All changes are additive. Three new SECURITY DEFINER RPCs registered following the exact same pattern as existing RPCs. No existing enforcement rules modified or removed. Role gating enforced at DB level via require_min_role_v1.

## Risk
Low. New table and RPCs only. No existing RPC signatures changed. The farm_area_id FK on deals is nullable and uses ON DELETE SET NULL - no data loss risk. All registrations follow established patterns.

## Rollback
Revert PR141. Removes 10.8.6 migration, test, and all registration entries from definer_allowlist, execute_allowlist, rpc_contract_registry, privilege_truth, tenant_table_selector, and ci_robot_owned_guard cleanly.