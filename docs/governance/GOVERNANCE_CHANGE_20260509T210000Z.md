# GOVERNANCE CHANGE — Build Route 10.12C6 Draft deal read path (get_draft_deal_v1)

UTC: 20260509T210000Z

## What changed

- **`supabase/migrations/20260509000001_10_12C6_get_draft_deal_read_path.sql`** — **`get_draft_deal_v1(p_draft_id uuid)`** returns **`jsonb`** envelope; **`STABLE`** **`SECURITY DEFINER`**; **`require_min_role_v1('member')`**; tenant from **`current_tenant_id()`**; **`NOT_FOUND`** for missing, cross-tenant, or **`NULL`** **`p_draft_id`**; **`NOT_AUTHORIZED`** for missing tenant / role; no workspace write lock; owner **`postgres`**, **`REVOKE`** **`PUBLIC`** + **`anon`**, **`GRANT EXECUTE`** **`authenticated`**.
- **`supabase/tests/10_12C6_get_draft_deal.test.sql`** — pgTAP coverage for OK payload, cross-tenant / missing / **`NULL`** **`NOT_FOUND`**, no-tenant **`NOT_AUTHORIZED`**, and authenticated-only **`EXECUTE`**.
- **`docs/artifacts/CONTRACTS.md`** — §17 mapping row and §64 contract subsection for **`get_draft_deal_v1`**; §64 authority and **§Registry** lines updated; §67 **§Registry** includes **`get_draft_deal_v1`**.
- **`docs/artifacts/WEWEB_ARCHITECTURE.md`** — §4.3 documents **`get_draft_deal_v1`** for Lead Intake review-route pre-fill and extends UI sequencing to **10.12C6**.
- **`docs/artifacts/BUILD_ROUTE_V2.4.md`** — **10.12D1** DoD: review form pre-fill explicitly calls **`get_draft_deal_v1`** when **`draft_id`** is present.
- **`docs/truth/rpc_contract_registry.json`** — registry entry **`get_draft_deal_v1`** (**10.12C6**).
- **`docs/truth/execute_allowlist.json`** — **`get_draft_deal_v1`**.
- **`docs/truth/expected_surface.json`** — **`get_draft_deal_v1`** (PostgREST / grant parity).
- **`docs/truth/privilege_truth.json`** — **`migration_grant_allowlist`** / **`routine_grants.authenticated`** / authority line for **`get_draft_deal_v1`** (already aligned with migration **`GRANT`**).
- **`docs/truth/definer_allowlist.json`** — **`public.get_draft_deal_v1`** (SECURITY DEFINER catalog).
- **`docs/truth/qa_claim.json`** — active item **`10.12C6`**.
- **`docs/truth/qa_scope_map.json`** — **`10.12C6`** title + proof pattern **`^docs/proofs/10\.12C6_get_draft_deal_`**.
- **`docs/truth/cloud_migration_parity.json`** — migration tip bumped to **`20260509000001`** / C6 file (human-authored pending **Phase 2** handoff idempotency).
- **`scripts/ci_robot_owned_guard.ps1`** — canonical proof log allowlist pattern for **10.12C6**.

## Alignment

- **Build Route `10.12C6`** (merge-blocking; prerequisite **10.12C5**). Proof path: **`docs/proofs/10.12C6_get_draft_deal_<UTC>.log`** (Phase 4 per **SOP_WORKFLOW.md**).
- **Phase 1** (SOP): migrations, tests, **CONTRACTS.md**, governance file, manual registries (**rpc_contract_registry**, **privilege_truth**, **execute_allowlist**, **qa_***, robot guard, **expected_surface**). **Phase 2**: **`npm run handoff`** / **`handoff:commit`** for **`generated/schema.sql`**, **`handoff_latest.txt`**, robot-owned truth sync, and idempotent **`cloud_migration_parity.json`**.

## Why safe

- Read-only path; tenant-scoped **`SELECT`** with same member+ posture as other Lead Intake KPI/list RPCs; no new table or anon surface.

## Risk

- Low. Mis-typed **`draft_id`** yields **`NOT_FOUND`**; clients must use inbox-backed or validated ids.

## Rollback

- Revert migration **10.12C6** and related test/truth/doc updates; remove **`get_draft_deal_v1`** from app allowlists if referenced.
