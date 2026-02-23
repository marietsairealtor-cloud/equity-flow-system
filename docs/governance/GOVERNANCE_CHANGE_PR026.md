# Governance Change — PR026

## What changed
- `scripts/ci_rls_strategy_lint.ps1` — new merge-blocking gate detecting forbidden tenant resolution patterns in migrations
- `.github/workflows/ci.yml` — rls-strategy-consistent job added, wired into required:
- `docs/truth/required_checks.json` — CI / rls-strategy-consistent added
- `docs/truth/qa_claim.json` — updated to 4.5
- `docs/truth/qa_scope_map.json` — added 4.5 entry
- `docs/truth/completed_items.json` — added 4.5
- `scripts/ci_robot_owned_guard.ps1` — allowlisted 4.5 proof log

## What gate detects
- Raw auth.uid() used directly in RLS policy body (forbidden per CONTRACTS.md §3)
- Raw auth.jwt() used directly in RLS policy body (forbidden per CONTRACTS.md §3)
- Inline JWT claim parsing for tenant ID within a policy body (forbidden per CONTRACTS.md §3)

## What gate does NOT do
- Does not validate full resolution logic structure
- Does not re-adjudicate CONTRACTS.md §3 resolution order
- Authority on resolution order: CONTRACTS.md §3 only

## Why safe
- Static analysis only — reads migration files, no live DB access
- Gate fails naming file, policy name, line number, and CONTRACTS.md §3
- Deliberate-failure regression confirmed: auth.uid() in policy body → FAIL with exact location

## Risk
- Low. Merge-blocking static lint. No schema, migration, or security surface modified.

## Rollback
- Remove scripts/ci_rls_strategy_lint.ps1
- Remove rls-strategy-consistent job from ci.yml and required: needs
- Remove CI / rls-strategy-consistent from required_checks.json
- One PR, CI green, QA approve, merge