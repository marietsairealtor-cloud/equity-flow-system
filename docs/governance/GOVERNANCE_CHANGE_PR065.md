# GOVERNANCE_CHANGE — Build Route 7.2 — Privilege Truth + Migration Grant Lint

## What changed

1. `docs/truth/privilege_truth.json` — populated with declarative expected end-state for `anon` and `authenticated` grants (table, routine, sequence, default ACL). Absence of `anon` entries is now stated explicitly. Added `migration_grant_allowlist` section as the single authority for the new lint gate.
2. `scripts/lint_migration_grants.mjs` — new static migration lint gate. Scans `supabase/migrations/**/*.sql` for any `GRANT` or `ALTER DEFAULT PRIVILEGES` targeting `anon` or `authenticated`. Fails on any grant not in `privilege_truth.json → migration_grant_allowlist`. No live DB required.
3. `.github/workflows/ci.yml` — new job `migration-grant-lint` added; added to `required.needs`.
4. `docs/truth/required_checks.json` — `migration-grant-lint` added.
5. `scripts/ci_robot_owned_guard.ps1` — proof log pattern for 7.2 allowlisted.
6. `docs/truth/qa_claim.json`, `docs/truth/qa_scope_map.json` — updated to 7.2.

## Why safe

- `privilege_truth.json` change is data-only (populating empty `rules:[]` and adding explicit declarative truth). No enforcement logic is changed in `ci_anon_privilege_audit.ps1`.
- `lint_migration_grants.mjs` is a static file scan — it never connects to a database, cannot regress live DB gates, and cannot false-positive on non-migration files. The allowlist is derived directly from the existing live DB state captured in the debrief.
- CI job `migration-grant-lint` is merge-blocking only for PRs containing migration changes; it exits 0 (vacuous PASS) if no migration files are found.
- No existing required check is renamed or removed.

## Risk

Low. New gate is additive. The allowlist exactly matches the current live DB state (verified via live DB query output in debrief). No migration currently in the repo contains an unauthorized GRANT — the gate will pass on the existing migration set.

## Rollback

Remove `migration-grant-lint` job from `.github/workflows/ci.yml` and `required.needs`, remove from `docs/truth/required_checks.json`, revert `privilege_truth.json` to `{"version":1,"roles":["anon","authenticated"],"rules":[]}`. One PR, CI green, merge.