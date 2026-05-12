# GOVERNANCE CHANGE — LINT_SQL_SAFETY: allow literal-template `format()` under SECURITY DEFINER (Phase 1 admin)

UTC: 20260513T180000Z

## What changed

- **`scripts/lint_sql_safety.ps1`** — Under **`SECURITY DEFINER`**, **`format(`** is flagged only when the call is **not** the safe “printf-style” shape: optional whitespace after **`(`**, then a **single-quoted** template (negative lookahead **`(?!\s*')`** immediately after **`(`**). **`EXECUTE`** handling is unchanged (still strips string literals for that branch; **`GRANT`/`REVOKE` EXECUTE ON FUNCTION`** and **`CREATE TRIGGER` … `EXECUTE FUNCTION`** exemptions preserved). **`npm run lint:sql`** still delegates to this script via **`scripts/run_lint_sql.mjs`** (unchanged).

## Alignment

- **CI / automation** only; no **`supabase/migrations/**`**, **`CONTRACTS.md`**, or truth-registry edits in this PR.
- **SOP §0.1 Phase 1** pre-checks: **`lint:sql`** must pass without rewriting merged SQL that uses **`format('literal', …)`** inside definer RPCs (e.g. **10.13A** **`refresh_deal_soft_offer_v1`** expiration clause).

## Why safe

- **Stricter than removing the check:** dynamic **`format(variable, …)`** (first arg not a leading literal template after whitespace) still fails the gate.
- **No weaker Postgres security:** migration bodies are unchanged; only the static linter’s false-positive filter is narrowed.

## Risk

- Low. Heuristic could miss a pathological dynamic **`format`** that still starts with a literal token; **`EXECUTE format(...)`** remains covered by the **`execute`** arm when applicable.

## Rollback

- Revert **`scripts/lint_sql_safety.ps1`** to the prior **`SECURITY DEFINER`** + any **`format(`** → fail behavior.
