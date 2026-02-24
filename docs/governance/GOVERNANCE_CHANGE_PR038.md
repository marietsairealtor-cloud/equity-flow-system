# Governance Change — PR038

## What changed
- `scripts/ci_migration_schema_coupling.ps1` — new merge-blocking gate (migration lane, static analysis)
- `.github/workflows/ci.yml` — migration-schema-coupling job added, wired into required:
- `docs/truth/required_checks.json` — CI / migration-schema-coupling added
- `docs/truth/qa_claim.json` — updated to 5.3
- `docs/truth/qa_scope_map.json` — added 5.3 entry
- `docs/truth/completed_items.json` — added 5.3
- `scripts/ci_robot_owned_guard.ps1` — allowlisted 5.3 proof log

## What gate does
- Detects if any file in supabase/migrations/** changed in PR diff
- If yes: asserts generated/schema.sql is also in the diff
- If schema not updated: FAIL with clear remediation instruction
- If no migration changes: SKIP (PASS)

## Why safe
- Static diff analysis only — no DB access
- Does not block PRs that don't touch migrations
- Deliberate-failure regression confirmed

## Risk
- Low. Merge-blocking static lint. No schema, migration, or security surface modified.