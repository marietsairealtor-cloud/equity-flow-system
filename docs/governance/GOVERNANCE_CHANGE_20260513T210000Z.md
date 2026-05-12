# GOVERNANCE CHANGE — Build Route 10.13E Save Deal + Reopen Deal (Phase 1 admin — QA scope + robot guard)

UTC: 20260513T210000Z

## What changed

- **`docs/truth/qa_claim.json`** — active QA item **`10.13E`** (Save Deal + Reopen Deal).
- **`docs/truth/qa_scope_map.json`** — **`10.13E`** entry: title **Offer Flow — Save Deal + Reopen Deal**; **`proof_pattern`** **`^docs/proofs/10\.13E_save_reopen_deal_`** (merge-blocking proof log per **BUILD_ROUTE v2.4** **10.13E**).
- **`scripts/ci_robot_owned_guard.ps1`** — finalized proof log allowlist for **`10.13E_save_reopen_deal_<UTC>.log`**.

## Alignment

- **Build Route `10.13E`** — **Phase 1** (SOP): register QA active item, scope map, and robot-owned proof path before Phase 4 proof finalize. Backend DoD already satisfied by merged **`update_deal_pricing_v1`** / **`get_offer_payload_v1`** / **`get_acq_deal_v1`** behavior; this commit is **registry + guard only**.

## Why safe

- Truth and CI allowlist only; no migrations, no privilege changes.

## Risk

- Low. **`qa_claim.json`** must match the item under test until the **10.13E** gate is closed.

## Rollback

- Restore **`qa_claim.json`**, **`qa_scope_map.json`**, and **`ci_robot_owned_guard.ps1`** from the prior merge commit.
