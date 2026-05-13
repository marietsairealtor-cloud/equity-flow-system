# GOVERNANCE CHANGE — Build Route 10.14B Dispo Backend — Share Link + Handoff Control (Phase 1 admin)

UTC: 20260516T180000Z

## What changed

- **`supabase/migrations/20260516000001_10_14B_dispo_share_link_handoff.sql`** — **`deals.assignment_agreement_signed_at`**, **`deals.earnest_money_received_at`**; table **`workspace_handoff_notifications`** (append-only, no app role table grants); **`handoff_to_tc_v1`** gated on both timestamps, **`INSERT workspace_handoff_notifications`** when **`p_assignee_user_id`** set; **`return_to_acq_v1`** with **`require_min_role_v1('member')`**, **`auth.uid()`**, and **`deal_activity_log`** (**`Deal returned to Acq from Dispo`**).
- **`supabase/tests/10_14B_dispo_share_link_handoff.test.sql`** — pgTAP: milestone gates, assignee notification row, invalid assignee, **`return_to_acq_v1`** activity; **`create_share_token_v1`**, **`revoke_share_token_v1`**, **`lookup_share_token_v1`** envelope parity (**invalid / expired / revoked** vs unknown token).
- **`supabase/tests/10_14A_dispo_dashboard.test.sql`** — seeds TC milestone timestamps on handoff deal so **`handoff_to_tc_v1`** success path matches **10.14B** prerequisites.
- **`docs/artifacts/CONTRACTS.md`** — **§17** mapping; **§62** / **§71** overlays; new **§72** Dispo share-link + handoff control contract.
- **`docs/ui-workflows/WORKFLOWS.md`** — **`dispo-share-link`**, **`dispo-return-to-acq`**, **`dispo-send-to-tc`** workflows (**10.14B**).
- **`docs/artifacts/WEWEB_ARCHITECTURE.md`** — **§8.2** Dispo to TC backend alignment (**10.14B** migration authority for assignee notification persistence).
- **`docs/truth/rpc_contract_registry.json`** — **`handoff_to_tc_v1`**, **`return_to_acq_v1`**, **`create_share_token_v1`**, **`lookup_share_token_v1`**, **`revoke_share_token_v1`** notes (**10.14B**).
- **`docs/truth/write_path_registry.json`** — **`handoff_to_tc_v1`** **`tables`** include **`workspace_handoff_notifications`**; **`return_to_acq_v1`** **`tables`** include **`deal_activity_log`**.
- **`docs/truth/cloud_migration_parity.json`** — migration tip **`20260516000001`**; **`migration_count`** **`134`**; **`pinned_at`** **`2026-05-16`**.
- **`docs/truth/calc_version_registry.json`** — **`calc_versions[]`** row (**10.14B**; incidental **`deals`** references only).
- **`docs/truth/qa_claim.json`** — active item **`10.14B`**.
- **`docs/truth/qa_scope_map.json`** — **`10.14B`** entry (proof pattern **`^docs/proofs/10\.14B_dispo_share_link_handoff_`**).
- **`docs/truth/tenant_table_selector.json`** — **`workspace_handoff_notifications`** in **`tenant_owned_tables`**; **`version`** **`4`**.
- **`docs/truth/privilege_truth.json`** — **`handoff_to_tc_v1`**, **`return_to_acq_v1`** authority strings (**10.14B**).
- **`scripts/ci_robot_owned_guard.ps1`** — proof allowlist for **`10.14B_dispo_share_link_handoff_<UTC>.log`**.

## Alignment

- **Build Route `10.14B`:** Share link generation/revocation and lookup envelope parity (existing RPCs); **`Send to TC`** prerequisites; **`Return to Acq`** governed path with activity; assignee notification row on TC handoff; no direct table access from UI (**RPC-only**).
- **Phase 1 (SOP):** migrations, tests, **CONTRACTS.md**, **WORKFLOWS.md**, **WEWEB_ARCHITECTURE.md**, governance, truth registries (**rpc_contract_registry**, **write_path_registry**, **cloud_migration_parity**, **calc_version_registry**, **tenant_table_selector**, **qa_***), robot guard. **Phase 4:** proof log **`docs/proofs/10.14B_dispo_share_link_handoff_<UTC>.log`** + **`npm run proof:finalize`** when closing the gate.

## Why safe

- **10.14B** extends **10.14A** handoff discipline with explicit milestone columns and a private notification outbox; **`return_to_acq_v1`** matches the same audit pattern as other handoff RPCs. Share-token RPC signatures unchanged; pgTAP locks **NOT_FOUND** parity for Dispo lane regression.

## Risk

- Low. Milestone columns are nullable until a future governed setter lands; **`handoff_to_tc_v1`** **CONFLICT** is backward-compatible for deals without timestamps until UI seeds them.

## Rollback

- Revert migration **`20260516000001`**, drop dependent expectations, and restore listed docs/truth files from the prior merge commit.
