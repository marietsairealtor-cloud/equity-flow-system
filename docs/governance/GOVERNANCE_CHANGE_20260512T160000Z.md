# GOVERNANCE CHANGE — calc_version_registry alignment for 10.13A LINT_SQL_SAFETY migration edit (Phase 1 admin)

UTC: 20260512T160000Z

## What changed

- **`docs/truth/calc_version_registry.json`** — **`version`** **25** → **26**; **`10.13A offer payload + soft offer copy`** row (**`migration`**: **`20260513000003_10_13A_offer_data_contract_soft_offer.sql`**) **`description`** extended to record that **`refresh_deal_soft_offer_v1`** builds **`expiration_clause`** with **`||`** concatenation instead of **`format()`** so **`npm run lint:sql`** (**LINT_SQL_SAFETY**: no **`SECURITY DEFINER`** + **`format(`** in the same migration file). Displayed clause text unchanged. **No** new **`calc_version`** integer; **no** MAO / pricing protocol change.
- **`supabase/migrations/20260513000003_10_13A_offer_data_contract_soft_offer.sql`** — same functional clause string; implementation-only edit (paired with registry bump so **`scripts/ci_calc_version_lint.ps1`** passes when that migration path matches **`watch_surface.migration_tokens`**).

## Alignment

- **Build Route `10.13A`** already merged; this is a **corrective / CI gate** amendment on the same migration filename (fresh **`supabase db reset`** applies the edited body).
- **`ci_calc_version_lint.ps1`** requires **`calc_version_registry.json`** to change in the same PR as any touched migration that matches **`calc_version`** (or other watch tokens).

## Why safe

- Truth registry documents the migration touch and explicitly rules **no** calc-version protocol drift; SQL behavior for operators is unchanged.

## Risk

- Low. Registry-only semantics plus non-functional SQL shape change already covered by existing pgTAP for **10.13A**.

## Rollback

- Revert the migration edit and restore **`calc_version_registry.json`** **`version`** / **10.13A** row text from the prior commit; rerun **`npm run lint:sql`** and **`ci_calc_version_lint.ps1`** as needed.
