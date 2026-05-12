# GOVERNANCE CHANGE — Build Route 10.13E Offer Flow — Save Deal + Reopen Deal (Phase 1 admin)

UTC: 20260514T230000Z

## What changed

- **`supabase/migrations/20260514000001_10_13E_pricing_save_activity_log.sql`** — **`update_deal_pricing_v1`**: **`require_min_role_v1('member')`** first; on successful append-only pricing save, inserts **`deal_activity_log`** (**`activity_type`** **`pricing_save`**, **`content`** **`Pricing saved`**). Signature and return envelope unchanged.
- **`supabase/tests/10_13E_save_reopen_deal.test.sql`** — pgTAP: save persistence, snapshot pointer, reopen via **`get_acq_deal_v1`**, activity row, membership guard, cross-tenant isolation.
- **`docs/artifacts/CONTRACTS.md`** — **§17** mapping + **§55** / **§56** / **§59**: **`update_deal_pricing_v1`** and **`get_acq_deal_v1`** aligned with **10.13E** (role guard ordering, activity append, ACQ reopen read path).
- **`docs/ui-workflows/WORKFLOWS.md`** — **`save-acq-pricing`** workflow; **`fetch-selected-deal`** / **`fetch-deal-activity`** triggers; **ACQ Page Variables** **`acqPricingFields`** row.
- **`docs/artifacts/WEWEB_ARCHITECTURE.md`** — Acquisition deal detail: **10.13E** pricing save / reopen governed paths.
- **`docs/truth/rpc_contract_registry.json`** — **`update_deal_pricing_v1`** **`notes`**: **10.13E** role guard + **`deal_activity_log`** behavior.
- **`docs/truth/write_path_registry.json`** — **`update_deal_pricing_v1`** tables include **`deal_activity_log`**.
- **`docs/truth/cloud_migration_parity.json`** — migration tip **`20260514000001`**; **`migration_count`** **`132`**.
- **`docs/truth/calc_version_registry.json`** — **`version`** **`26`**; **10.13E** **`calc_versions[]`** row (incidental **`pricing_`** watch token; no calc integer protocol change).
- **`docs/truth/qa_claim.json`** — active item **`10.13E`** (unchanged if already set).
- **`docs/truth/qa_scope_map.json`** — **`10.13E`** entry (proof pattern **`^docs/proofs/10\.13E_save_reopen_deal_`**) — confirm present.
- **`scripts/ci_robot_owned_guard.ps1`** — proof allowlist for **`10.13E_save_reopen_deal_<UTC>.log`** — confirm present.

## Alignment

- **Build Route `10.13E`** (**`docs/artifacts/BUILD_ROUTE_V2.4.md`**): save persists pricing + server **`mao`** + **`calc_version`**; reopen matches **`get_acq_deal_v1`**; mutation activity recorded; authenticated **ACQ deal detail** is the Hub surface (no new Hub page).
- **Phase 1 (SOP):** migrations, tests, **CONTRACTS.md**, **WORKFLOWS.md**, **WEWEB_ARCHITECTURE.md**, governance, truth registries (**rpc_contract_registry**, **write_path_registry**, **cloud_migration_parity**, **calc_version_registry**, **qa_***), robot guard. **Phase 4:** proof log **`docs/proofs/10.13E_save_reopen_deal_<UTC>.log`** + **`npm run proof:finalize`** when closing the gate.

## Why safe

- One additional append-only **`deal_activity_log`** row on an existing governed write RPC; membership guard matches RPC mapping (**min role member**).

## Risk

- Low. UI must call **`update_deal_pricing_v1`** only with allowed keys; activity list grows one row per successful save.

## Rollback

- Revert migration **`20260514000001`**, drop dependent expectations, and restore listed docs/truth files from the prior merge commit.
