# GOVERNANCE CHANGE — Build Route 10.13A Offer Backend — Data Contract + Soft Offer Copy (Phase 1 admin)

UTC: 20260514T160000Z

## What changed

- **`supabase/migrations/20260513000003_10_13A_offer_data_contract_soft_offer.sql`** — **`deal_soft_offers`** tenant-scoped table (FK **`deals`**, FK **`deal_inputs`**, RLS, revoked **`anon`**/**`authenticated`** table grants); **`get_offer_payload_v1(p_deal_id uuid)`** **`jsonb`** read (**`require_min_role_v1('member')`** first, explicit-column **`SELECT`**); **`refresh_deal_soft_offer_v1(p_deal_id uuid, p_idempotency_key text)`** (**`require_min_role_v1('member')`** first executable statement; early **`rpc_idempotency_log`** replay after **`auth.uid()`** + key validation; **`get_offer_payload_v1`**-derived **`copy_text`**/**`copy_email`** + 48h UTC clause; ASCII hyphen email subject).
- **`supabase/tests/10_13A_offer_data_contract_soft_offer.test.sql`** — pgTAP: SECURITY DEFINER posture, **`get_offer_payload_v1`** OK / MAO / invalid mao / cross-tenant; **`refresh_deal_soft_offer_v1`** idempotency + payload-derived copy assertions + orphan FK guard + EXECUTE grants.
- **`docs/artifacts/CONTRACTS.md`** — **`§17`** mapping rows **`get_offer_payload_v1`**, **`refresh_deal_soft_offer_v1`**; **`§69`** full contracts aligned with migration ordering (role guard **→** replay **→** business path).
- **`docs/truth/rpc_contract_registry.json`** — registry entries + **`notes`** for both RPCs.
- **`docs/truth/privilege_truth.json`** — **`routine_grants.authenticated`** for **`get_offer_payload_v1`** / **`refresh_deal_soft_offer_v1`**; **`authenticated_routines`** mirror list.
- **`docs/truth/execute_allowlist.json`** — **`get_offer_payload_v1`**, **`refresh_deal_soft_offer_v1`**.
- **`docs/truth/definer_allowlist.json`** — **`public.get_offer_payload_v1`**, **`public.refresh_deal_soft_offer_v1`**.
- **`docs/truth/expected_surface.json`** — **`rpc`** surface entries for both names (subset parity with execute_allowlist).
- **`docs/truth/tenant_table_selector.json`** — **`deal_soft_offers`** added to **`tenant_owned_tables`** (**`tenant_id`** scoped).
- **`docs/truth/write_path_registry.json`** — **`refresh_deal_soft_offer_v1`** → **`deal_soft_offers`**, **`rpc_idempotency_log`**.
- **`docs/truth/cloud_migration_parity.json`** — migration tip **`20260513000003`**; **`migration_count`** **129**.
- **`docs/truth/qa_claim.json`** — active item **`10.13A`**.
- **`docs/truth/qa_scope_map.json`** — **`10.13A`** title + proof pattern **`^docs/proofs/10\.13A_offer_data_contract_soft_copy_`**.
- **`scripts/ci_robot_owned_guard.ps1`** — finalized proof log filename pattern for **`10.13A`**.

## Alignment

- **Build Route `10.13A`** (merge-blocking). Proof path: **`docs/proofs/10.13A_offer_data_contract_soft_copy_<UTC>.log`** (Phase 4 per **SOP_WORKFLOW.md** — not authored here).
- **Phase 1** (SOP): migrations, tests, **CONTRACTS.md**, this governance file, truth registries (**rpc_contract_registry**, **privilege_truth**, **execute_allowlist**, **definer_allowlist**, **expected_surface**, **tenant_table_selector**, **write_path_registry**, **qa_***, **cloud_migration_parity**, robot guard). **Phase 2+**: **`npm run handoff`**, **`handoff_latest.txt`**, **`generated/schema.sql`**, proof finalize (run separately).

## Why safe

- Governed read/write paths only; no **`anon`** EXECUTE on app RPCs; **`deal_soft_offers`** no direct role grants; **`refresh`** uses established **`rpc_idempotency_log`** replay semantics after mandatory role guard.

## Risk

- Low. Additive schema + RPCs; **`deal_soft_offers`** CASCADE-deletes with **`deals`**.

## Rollback

- Revert migration **`20260513000003`**, drop dependents in reverse dependency order if needed, and restore truth files / **`qa_claim`** prior active item from the prior merge commit.
