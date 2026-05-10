# GOVERNANCE CHANGE — Build Route 10.13B Offer Backend — Send Offer Write Path (Phase 1 admin)

UTC: 20260509T233000Z

## What changed

- **`docs/artifacts/CONTRACTS.md`** — **`§17`** row **`send_offer_v1`** (**10.13B**); **`advance_deal_stage_v1`** purpose clarifies governed Send Offer uses **`send_offer_v1`**; **`§69`** registry pointer to **`§70`**; new **`§70`** (**`send_offer_v1`**) contract text aligned with **`20260513000004_10_13B_offer_send_write_path.sql`**.
- **`docs/truth/rpc_contract_registry.json`** — **`send_offer_v1`** entry (migration, ordering, error codes, mutation summary).
- **`docs/truth/privilege_truth.json`** — **`authenticated`** **`EXECUTE`** + inventory for **`send_offer_v1`**.
- **`docs/truth/definer_allowlist.json`** — **`public.send_offer_v1`**.
- **`docs/truth/execute_allowlist.json`** — **`send_offer_v1`**.
- **`docs/truth/expected_surface.json`** — **`send_offer_v1`** RPC surface.
- **`docs/truth/write_path_registry.json`** — **`send_offer_v1`** tables touched (**`deals`**, **`deal_reminders`**, **`deal_activity_log`**, **`rpc_idempotency_log`**).
- **`docs/truth/qa_claim.json`** — active item **`10.13B`**.
- **`docs/truth/qa_scope_map.json`** — **`10.13B`** title + proof pattern **`^docs/proofs/10\.13B_offer_send_write_path_`**.
- **`docs/truth/cloud_migration_parity.json`** — migration tip **`20260513000004`** / **`10_13B`** file; **`migration_count`** **`130`**.
- **`scripts/ci_robot_owned_guard.ps1`** — canonical proof log allowlist pattern for **10.13B**.

## Alignment

- **Build Route `10.13B`** (Offer Backend — Send Offer Write Path). Proof path (Phase 4): **`docs/proofs/10.13B_offer_send_write_path_<UTC>.log`** per **`qa_scope_map.json`**.
- **Phase 1** (SOP): migrations/tests already authored; this slice completes **CONTRACTS.md**, governance record, truth registries (**rpc_contract_registry**, **privilege_truth**, **definer_allowlist**, **execute_allowlist**, **expected_surface**, **write_path_registry**, **qa_***, **cloud_migration_parity**, robot guard). **Phase 2+**: **`npm run handoff`** / proof finalize / **`handoff_latest.txt`** / manifest hash (not in this change set).

## Why safe

- **`send_offer_v1`** is tenant-scoped (**`current_tenant_id()`**), workspace-write-gated, **`SECURITY DEFINER`** with **`authenticated`**-only **`EXECUTE`**, idempotent via **`rpc_idempotency_log`**, and covered by **`supabase/tests/10_13B_offer_send_write_path.test.sql`**.

## Risk

- Low. Registry-only alignment with merged migration; no behavioral change to SQL in this slice.

## Rollback

- Revert this governance + truth delta if **`10.13B`** is rolled back; restore **`qa_claim`** / **`cloud_migration_parity`** tip to prior **10.13A** head if applicable.
