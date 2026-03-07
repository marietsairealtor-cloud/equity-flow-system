# Governance Change — PR084

## What changed
- Converted clean-room-replay from db-heavy stub to live CI job
- New CI job: clean-room-replay (runs supabase db reset against live CI DB)
- Registered clean-room-replay in required_checks.json via truth:sync
- Added clean-room-replay to required.needs
- Split deferred_proofs.json umbrella db-heavy entry into individual stub entries
- Removed clean-room-replay from deferred registry (first stub conversion)
- Updated qa_claim.json, qa_scope_map.json, ci_robot_owned_guard.ps1

## Why safe
- First stub-to-live conversion. Replays existing migrations on empty CI DB.
- No schema, RLS, or privilege changes. CI infrastructure only.

## Risk
- CI runner memory/time for supabase start + db reset. Mitigated: ubuntu-24.04 provides 7GB (8.0 proven).

## Rollback
- Revert PR. Restore db-heavy umbrella stub entry.