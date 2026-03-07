# Governance Change — PR088

## What changed
Converted `definer-safety-audit` CI job from db-heavy stub to live execution. Job now boots Supabase, replays migrations, and runs the full SECURITY DEFINER safety audit against live catalog (pg_proc.proconfig search_path, no dynamic SQL, tenant membership enforcement per CONTRACTS.md §8). Removed CI stub block from `scripts/ci_definer_safety_audit.ps1`. Updated `deferred_proofs.json` to remove definer-safety-audit from the db-heavy umbrella (now covers pgtap 8.0.5 only).

## Why safe
Additive conversion of existing stub to live gate. No new security surface. The audit script already contained full live DB logic — only the CI skip block is removed. No other stub gates converted.

## Risk
Low. Job may fail if a SECURITY DEFINER function is missing search_path in proconfig or fails other checks. This is intended behavior — the gate catches real violations.

## Rollback
Restore the CI stub block in ci_definer_safety_audit.ps1, revert job steps in ci.yml, restore the db-heavy umbrella entry in deferred_proofs.json. Run truth:sync. Single-commit revert.