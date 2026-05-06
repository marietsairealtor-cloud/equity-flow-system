# GOVERNANCE CHANGE — Build Route 10.12C5 KPI unreviewed_count correction

UTC: 20260508T160000Z

## What changed

- **`supabase/migrations/20260508000001_10_12C5_kpi_unreviewed_count_fix.sql`** — **`DROP FUNCTION IF EXISTS`** + **`CREATE FUNCTION`** for **`get_lead_intake_kpis_v1(p_date_from timestamptz, p_date_to timestamptz)`** with the **only** behavioral change: **`unreviewed_count`** counts rows where **`review_status = unreviewed`** **and** **`form_type IN ('seller', 'birddog')`** (buyer submissions excluded from Lead Intake queue metric). Owner / revoke / grant unchanged (**`postgres`**, **`REVOKE`** **`PUBLIC`** + **`anon`**, **`GRANT EXECUTE`** **`authenticated`**).
- **`supabase/tests/10_12C5_kpi_unreviewed_count_fix.test.sql`** — pgTAP coverage for seller/birddog inclusion, buyer exclusion, window independence, and tenant isolation.
- **`supabase/tests/10_12C2_lead_intake_kpis.test.sql`** — expectation for **`unreviewed_count`** aligned with **10.12C5** (seller/birddog-only queue depth).
- **`docs/artifacts/CONTRACTS.md`** — §64 **`get_lead_intake_kpis_v1`**: documents **10.12C5** migration and **`unreviewed_count`** scope; registered RPC table and §Registry line updated.
- **`docs/truth/rpc_contract_registry.json`** — **`get_lead_intake_kpis_v1`** **`input_contract`** / **`notes`** include **10.12C5** and migration **`20260508000001_10_12C5_kpi_unreviewed_count_fix.sql`**.
- **`docs/truth/privilege_truth.json`** — **`get_lead_intake_kpis_v1`** authority line references **10.12C5** queue scope.
- **`docs/truth/qa_claim.json`** — active item **`10.12C5`**.
- **`docs/truth/qa_scope_map.json`** — **`10.12C5`** title + proof pattern **`^docs/proofs/10\.12C5_kpi_unreviewed_count_fix_`**.
- **`scripts/ci_robot_owned_guard.ps1`** — allowlist canonical proof log pattern for **10.12C5**.

## Alignment

- **Build Route `10.12C5`** (merge-blocking; prerequisite **10.12C4**). Proof path: **`docs/proofs/10.12C5_kpi_unreviewed_count_fix_<UTC>.log`** (Phase 4 per **SOP_WORKFLOW.md**).
- **WEWEB_ARCHITECTURE** / **BUILD_ROUTE** already describe **`unreviewed_count`** seller/birddog scope after **10.12C5**; no doc-only conflict.

## Why safe

- No new RPC surface, tables, or grants. Single predicate tightening on an existing metric; other KPI fields unchanged by contract.

## Risk

- Low. Any client that assumed **`unreviewed_count`** included **buyer** rows will see a lower number (intended).

## Rollback

- Revert migration **10.12C5** and related test/truth updates; redeploy prior **`get_lead_intake_kpis_v1`** body from **10.12C4** migration.
