# GOVERNANCE CHANGE — 10.11A Acquisition backend truth + contracts
UTC: 20260419T220000Z

## Change Summary

Registered the fourteen Build Route **10.11A** Acquisition backend SECURITY DEFINER RPCs in all required truth registries, documented schema/stage/RPC narrative in **CONTRACTS.md** (§17 mapping table, new §55, §17A write-lock list), aligned workspace write-lock enforcement on four RPCs that previously omitted `check_workspace_write_allowed_v1`, and extended the merge-blocking write-lock coverage gate accordingly.

## Items Added / Modified

### Truth / CI
- `docs/truth/definer_allowlist.json` — fourteen `public.*` entries for 10.11A RPCs.
- `docs/truth/execute_allowlist.json` — fourteen authenticated-executable RPC names.
- `docs/truth/privilege_truth.json` — `routine_grants.authenticated` and `migration_grant_allowlist.authenticated_routines` updated to match execute allowlist.
- `docs/truth/rpc_contract_registry.json` — fourteen governed RPC entries (`build_route_owner`: 10.11A).
- `docs/truth/expected_surface.json` — `rpc` list expanded to match full `execute_allowlist` (required for 9.2 surface invariants vs allowlist subset rule).
- `scripts/ci_write_lock_coverage.ps1` — helper-required list extended for all mutating 10.11A RPCs.

### Contracts
- `docs/artifacts/CONTRACTS.md` — §17 registered RPC table rows for all 10.11A functions; §17A locked RPC bullets; new **§55** for canonical stages, `deals` extensions, `deal_properties` / `deal_media`, and RPC narrative.

### Migrations (enforcement alignment)
- `supabase/migrations/20260419000005_10_11A_rpcs.sql` — added `check_workspace_write_allowed_v1()` to `update_seller_info_v1`, `update_property_info_v1`, `return_to_acq_v1`, and `return_to_dispo_v1` (read-only workspace messaging consistent with other 10.11A mutators).

## Rationale

10.11A introduces a dedicated Acquisition RPC surface and new tenant-scoped tables. Registry and CONTRACTS updates keep **rpc-mapping-contract**, **rpc-contract-registry**, **migration-grant-lint**, **definer-safety-audit**, and **write-lock-coverage** gates consistent with deployed grants and §12/§17A policy.

## Why safe

Additive bookkeeping and documentation plus narrowing write paths to match existing subscription read-only semantics. No signature changes. Existing registrations for `get_deal_health_color` and `update_deal_v1` (corrective migration 4) unchanged.

## Risk

If cloud DB applied an earlier revision of `20260419000005` without the four write-lock inserts, operators must re-apply or patch those functions so expired workspaces cannot mutate seller/property/return paths.

## Rollback

Revert this PR’s edits to truth files, CONTRACTS.md, `ci_write_lock_coverage.ps1`, and the four function bodies in `20260419000005_10_11A_rpcs.sql` (remove the added `check_workspace_write_allowed_v1` blocks). Re-run handoff truth sync if robot-owned registries are regenerated in your lane.
