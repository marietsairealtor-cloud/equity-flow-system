# GOVERNANCE CHANGE — Build Route 10.12C7 Money input normalizer

UTC: 20260510T180000Z

## What changed

- **`supabase/migrations/20260510000001_10_12C7_money_input_normalizer.sql`** — **`_parse_money_input_v1(text)`** and **`_intake_canonicalize_pricing_assumptions_v1(jsonb)`** (**STABLE**, **SECURITY DEFINER**, **REVOKE ALL** from **PUBLIC**, **anon**, **authenticated**); **`_intake_validate_pricing_assumptions_v1`**, **`_intake_apply_mao_to_assumptions_v1`**, **`create_deal_from_intake_v1`**, **`promote_draft_deal_v1`**, **`update_deal_pricing_v1`** DROP+CREATE; **`submit_form_v1`** unchanged.
- **`supabase/tests/10_12C7_money_input_normalizer.test.sql`** — pgTAP coverage for parse/canonicalize rejection, formatted **`create_deal_from_intake_v1`** assumptions + MAO, **`update_deal_pricing_v1`** formatted **arv** / **`%`** multiplier / **`""`** clears **repair_estimate**, birddog **`promote_draft_deal_v1`** payload **asking_price**, and **`EXECUTE`** posture on helpers vs public RPCs.
- **`docs/artifacts/CONTRACTS.md`** — §17 mapping rows (**`create_deal_from_intake_v1`**, **`promote_draft_deal_v1`**, **`update_deal_pricing_v1`**); §59 **10.12C7** money-string merge semantics; §67 authority + internal helpers (**`10.12C7`**); §Registry lines.
- **`docs/truth/rpc_contract_registry.json`** — extended **`notes`** on **`create_deal_from_intake_v1`**, **`promote_draft_deal_v1`**, **`update_deal_pricing_v1`** for **10.12C7** parsing/canonicalize.
- **`docs/truth/privilege_truth.json`** — **`internal_definer_helpers`** entries **`_parse_money_input_v1`**, **`_intake_canonicalize_pricing_assumptions_v1`**; **`_intake_validate_pricing_assumptions_v1`** authority updated for **10.12C7** recreate.
- **`docs/truth/definer_allowlist.json`** — per-routine blocks for **`_parse_money_input_v1`** and **`_intake_canonicalize_pricing_assumptions_v1`** (not PostgREST-callable).
- **`docs/truth/qa_claim.json`** — active item **`10.12C7`**.
- **`docs/truth/qa_scope_map.json`** — **`10.12C7`** title + proof pattern **`^docs/proofs/10\.12C7_money_input_normalizer_`**.
- **`docs/truth/cloud_migration_parity.json`** — migration tip **`20260510000001`** / C7 file; **`migration_count`** incremented.
- **`scripts/ci_robot_owned_guard.ps1`** — canonical proof log allowlist pattern for **10.12C7**.
## Alignment

- **Build Route `10.12C7`** (merge-blocking; prerequisite **`10.12C6`**). Proof path: **`docs/proofs/10.12C7_money_input_normalizer_<UTC>.log`** (Phase 4 per **SOP_WORKFLOW.md**).
- **Phase 1** (SOP): migrations, tests, **CONTRACTS.md**, governance file, truth registries (**rpc_contract_registry** notes, **privilege_truth**, **definer_allowlist**, **qa_***, robot guard). **Phase 2+**: **`npm run handoff`** / proof finalize / **`handoff_latest.txt`** / manifest hash (not in this change set).

## Why safe

- No new client-callable RPCs; helpers **REVOKE**’d from app roles; parsing runs only inside existing **SECURITY DEFINER** intake and pricing paths; **`submit_form_v1`** remains raw-payload storage.

## Risk

- Low. Malformed money strings surface existing **`VALIDATION_ERROR`** envelopes; canonicalize **NULL** maps to **Invalid monetary value** on intake paths.

## Rollback

- Revert migration **10.12C7** and related test/truth/doc updates; restore prior **`create_deal_from_intake_v1`**, **`promote_draft_deal_v1`**, **`update_deal_pricing_v1`**, and helper definitions from earlier migrations if re-applying piecemeal.
