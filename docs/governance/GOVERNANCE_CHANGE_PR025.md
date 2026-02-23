# Governance Change — PR025

## What changed
- `supabase/migrations/20260219000004_default_acl_lockdown.sql` — revoke default privileges for anon/authenticated on schema public (postgres role, forward-only)
- `supabase/migrations/20260219000005_privilege_remediation.sql` — stop-the-line fix: revoke materialized object-level grants + re-apply CONTRACTS.md §12 controlled exception
- `docs/truth/anon_privilege_truth.json` — new machine-derived privilege truth file
- `scripts/ci_anon_privilege_audit.ps1` — new merge-blocking gate (psql, DB/runtime lane)
- `.github/workflows/ci.yml` — anon-privilege-audit job added, wired into required:
- `docs/truth/required_checks.json` — CI / anon-privilege-audit added
- `docs/truth/qa_claim.json` — updated to 4.4
- `docs/truth/qa_scope_map.json` — added 4.4 entry
- `docs/truth/completed_items.json` — added 4.4
- `scripts/ci_robot_owned_guard.ps1` — allowlisted 4.4 proof log
- `generated/schema.sql` — regenerated via handoff after migrations applied

## Stop-the-line
CONTRACTS.md §12 privilege firewall violation detected during pre-implementation catalog audit. `anon` and `authenticated` had full object-level grants on all core tables (materialized from supabase_admin default ACL). Remediated via migration 20260219000005.

## Decisions declared
- supabase_% roles excluded from default ACL cleanliness requirement per GOVERNANCE_CHANGE_PR024.md
- Carve-out invalidated by materialization — remediation migration required before 4.4 could proceed
- Gate uses psql via CI (Ubuntu runner) — local IPv6 network cannot reach cloud DB

## Why safe
- Migrations are forward-only plain SQL, no DO blocks, no dynamic SQL
- Gate self-skips if DATABASE_URL not set
- anon_privilege_truth.json is machine-derived — Triple Registration Rule applies

## Risk
- Medium. Two new migrations modify privilege posture on live cloud DB. Remediation is correct per CONTRACTS.md §12 + §13.

## Rollback
- Not safe to rollback privilege remediation — would re-expose CONTRACTS.md §12 violation
- Remove gate + job from ci.yml if needed for CI unblocking only