# GOVERNANCE CHANGE — Build Route 10.14A Dispo Backend — Dashboard Data Contract + KPI Read Path (Phase 1 admin)

UTC: 20260515T180000Z

## What changed

- **`supabase/migrations/20260515000001_10_14A_dispo_dashboard_read_path.sql`** — **`get_dispo_kpis_v1`**, **`list_dispo_dashboard_deals_v1`**; **`handoff_to_tc_v1`** recreated with **`require_min_role_v1('member')`** first, **`auth.uid()`** + tenant checks, workspace write lock, and **`deal_activity_log`** append (**`handoff`**, **`Deal handed off to TC`**) on success.
- **`supabase/tests/10_14A_dispo_dashboard.test.sql`** — pgTAP: KPI window + invalid range, list shape (dispo-only, share link, buyer_interest v1, activity teaser), **`handoff_to_tc_v1`**, membership **`NOT_AUTHORIZED`**, tenant isolation.
- **`docs/artifacts/CONTRACTS.md`** — **§17** mapping; **§62** **`handoff_to_tc_v1`** overlay; new **§71** Dispo dashboard RPC contract.
- **`docs/ui-workflows/WORKFLOWS.md`** — **`fetch-dispo-kpis`**, **`fetch-dispo-dashboard`** workflows (**10.14A**).
- **`docs/artifacts/WEWEB_ARCHITECTURE.md`** — **§8.2** governed read paths + **§8.7** Dispo KPI bullets aligned with **`get_dispo_kpis_v1`** semantics.
- **`docs/truth/rpc_contract_registry.json`** — **`get_dispo_kpis_v1`**, **`list_dispo_dashboard_deals_v1`**; **`handoff_to_tc_v1`** notes (**10.14A**).
- **`docs/truth/write_path_registry.json`** — **`handoff_to_tc_v1`** **`tables`** include **`deal_activity_log`**.
- **`docs/truth/cloud_migration_parity.json`** — migration tip **`20260515000001`**; **`migration_count`** **`133`**; **`pinned_at`** **`2026-05-15`**.
- **`docs/truth/calc_version_registry.json`** — **`version`** **`27`**; **10.14A** **`calc_versions[]`** row (read/KPI migration; no calc integer protocol change).
- **`docs/truth/qa_claim.json`** — active item **`10.14A`**.
- **`docs/truth/qa_scope_map.json`** — **`10.14A`** entry (proof pattern **`^docs/proofs/10\.14A_dispo_data_contract_`**).
- **`docs/truth/execute_allowlist.json`**, **`docs/truth/expected_surface.json`**, **`docs/truth/definer_allowlist.json`**, **`docs/truth/privilege_truth.json`** — new RPC names (alphabetical / registry parity).
- **`scripts/ci_robot_owned_guard.ps1`** — proof allowlist for **`10.14A_dispo_data_contract_<UTC>.log`**.

## Alignment

- **Build Route `10.14A`:** Dispo KPI read path + dashboard list contract; no buyer matching engine; no buyer CRM expansion; no direct table reads from authenticated UI (**RPC-only**).
- **Phase 1 (SOP):** migrations, tests, **CONTRACTS.md**, **WORKFLOWS.md**, **WEWEB_ARCHITECTURE.md**, governance, truth registries (**rpc_contract_registry**, **write_path_registry**, **cloud_migration_parity**, **calc_version_registry**, **qa_***), robot guard. **Phase 4:** proof log **`docs/proofs/10.14A_dispo_data_contract_<UTC>.log`** + **`npm run proof:finalize`** when closing the gate.

## Why safe

- Read RPCs are **STABLE** **`SECURITY DEFINER`** with **`require_min_role_v1('member')`** before tenant resolution; write path **`handoff_to_tc_v1`** matches existing handoff + workspace-lock patterns and adds a single auditable **`deal_activity_log`** row.

## Risk

- Low. **`get_dispo_kpis_v1`** **`deposit_collected`** / **`avg_assignment_fee`** semantics are version-1 counts/snapshot averages (see **§71**); product copy on **WEWEB §8.7** updated to match backend until richer money rollups exist.

## Rollback

- Revert migration **`20260515000001`**, drop dependent expectations, and restore listed docs/truth files from the prior merge commit.
