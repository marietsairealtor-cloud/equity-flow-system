# Governance Change — PR063

## Build Route Item
7.1A Preflight Hook Wiring (Remove Optional Skips)

## What changed
Added three script entries to package.json: "lint" aliasing node scripts/lint_bom_gate.mjs, "test" aliasing supabase test db, "truth:check" aliasing npm run truth-bootstrap && npm run required-checks-contract. All three point to existing scripts — no new infrastructure. pr:preflight now executes lint, test, and truth:check with zero skip:missing output.

## Why safe
All three aliases point to pre-existing, proven scripts. No new code introduced. No CI jobs added or modified. No migrations, RLS, privileges, or RPCs touched. package.json has exactly one "scripts" block confirmed by JSON parse validation.

## Risk
Low. "test" requires local Supabase running — if not available, npm run test will fail locally. This is expected and documented. CI runs its own test surface independently.

## Rollback
Remove the three script entries from package.json. pr:preflight reverts to skip:missing behavior.
