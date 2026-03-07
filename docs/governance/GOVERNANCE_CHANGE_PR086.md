# Governance Change — PR086

## What changed
Converted `handoff-idempotency` CI job from db-heavy stub to live execution. Job now boots Supabase, replays migrations, and runs `npm run handoff` twice asserting zero diffs. Removed CI stub block from `scripts/ci_handoff_idempotency.ps1`. Updated `deferred_proofs.json` to remove handoff-idempotency from the db-heavy umbrella (now covers 8.0.4-8.0.5 only).

## Why safe
Additive conversion of existing stub to live gate. No new security surface. The handoff script already contained full idempotency logic — only the CI skip block is removed. No other stub gates converted.

## Risk
Low. Job may fail if handoff generators produce nondeterministic output against the CI DB. This would block PRs but is the intended behavior — nondeterministic generators must be fixed.

## Rollback
Restore the CI stub block in ci_handoff_idempotency.ps1, revert the job steps in ci.yml, restore the db-heavy umbrella entry in deferred_proofs.json. Run truth:sync. Single-commit revert.