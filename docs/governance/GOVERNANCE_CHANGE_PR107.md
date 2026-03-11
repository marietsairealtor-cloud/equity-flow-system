# GOVERNANCE_CHANGE_PR107.md

## What changed

Build Route v2.4 Item 9.6 PostgREST data surface truth. New CI script `ci_data_surface_truth.mjs` verifies that actual PostgREST data exposure matches `expected_surface.json` for roles `anon` and `authenticated` in the `public` schema. Fields enforced: `schemas_exposed`, `tables_exposed`, `views_exposed`. `expected_surface.json` bumped to version 2 with new data surface fields added. New npm script `data-surface:truth` wired to the gate. `ci_robot_owned_guard.ps1` allowlisted for 9.6 proof log. CONTRACTS.md S22 added.

## Why safe

No DB objects are created or modified. The new gate is read-only — it queries `information_schema` and `pg_namespace` to verify existing privilege state. The expected surface reflects the actual current state (user_profiles is the only exposed table, per CONTRACTS S12). Adding enforcement of an already-correct state cannot cause regressions. All Supabase internal schemas are explicitly excluded from the check.

## Risk

Low. Gate is additive only — no migration, no function change, no RLS change. The only risk is a false positive if the local DB state diverges from expected_surface.json, which is the intended behavior of the gate. The gate will correctly fail CI if a future migration inadvertently grants SELECT on a core table to anon or authenticated.

## Rollback

Remove `ci_data_surface_truth.mjs` and the `data-surface:truth` package.json entry via a follow-up PR. Revert `expected_surface.json` to version 1 (remove schemas_exposed, tables_exposed, views_exposed fields). No DB state is affected.