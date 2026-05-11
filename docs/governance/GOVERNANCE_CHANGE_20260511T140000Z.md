# GOVERNANCE CHANGE — Build Route 10.13B1 Offer Backend — Activity Log Copy Correction (Phase 1 admin)

UTC: 20260511T140000Z

## What changed

- **`supabase/migrations/20260513000005_10_13B1_offer_activity_log_copy_correction.sql`** — redefines **`send_offer_v1`** and updates only the user-facing `deal_activity_log.content` text written on successful send to **`Offer sent to seller`**.
- **`supabase/tests/10_13B1_offer_activity_log_copy_correction.test.sql`** — adds focused pgTAP coverage for corrected activity copy plus idempotent replay no-duplicate guarantees.
- **`supabase/tests/10_13B_offer_send_write_path.test.sql`** — updates legacy stage-change content assertion to the corrected user-facing copy.
- **`docs/artifacts/CONTRACTS.md`** — **`§17`** row for **`send_offer_v1`** now maps to **`10.13B, 10.13B1`** and records corrected activity-log copy semantics.
- **`docs/truth/qa_claim.json`** — active item set to **`10.13B1`**.
- **`docs/truth/qa_scope_map.json`** — adds **`10.13B1`** title + proof pattern **`^docs/proofs/10\.13B1_offer_activity_log_copy_correction_`**.
- **`docs/truth/cloud_migration_parity.json`** — migration tip advanced to **`20260513000005`** with **`migration_count`** **`131`**.
- **`scripts/ci_robot_owned_guard.ps1`** — canonical proof allowlist pattern added for **10.13B1** proof logs.

## Alignment

- **Build Route `10.13B1`** (Offer Backend — Activity Log Copy Correction). Phase 4 proof path: **`docs/proofs/10.13B1_offer_activity_log_copy_correction_<UTC>.log`**.
- Phase 1 scope here covers governance/truth/contracts/test alignment for the merged migration and test behavior.

## Why safe

- The RPC signature, authorization model, idempotency behavior, stage transition behavior, reminder creation behavior, and return envelope remain unchanged.
- Correction is limited to user-facing activity-log copy content.

## Rollback

- Revert migration **`20260513000005_10_13B1_offer_activity_log_copy_correction.sql`** and corresponding test/governance/truth updates in this record.
