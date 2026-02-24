# Governance Change — PR036

## What changed
- `supabase/migrations/20260219000006_rls_colocation_corrective.sql` — corrective migration per 5.1 pre-check
- `scripts/ci_migration_rls_lint.ps1` — new merge-blocking gate (migration lane, static analysis)
- `.github/workflows/ci.yml` — migration-rls-colocation job added, wired into required:
- `docs/truth/required_checks.json` — CI / migration-rls-colocation added
- `docs/truth/qa_claim.json` — updated to 5.1
- `docs/truth/qa_scope_map.json` — added 5.1 entry
- `docs/truth/completed_items.json` — added 5.1
- `scripts/ci_robot_owned_guard.ps1` — allowlisted 5.1 proof log

## Pre-check finding
All 4 baseline tables (tenants, tenant_memberships, user_profiles, deals) failed co-location rule — RLS and REVOKEs applied in later migrations, not same-file as CREATE TABLE. Corrective migration 20260219000006 authored and merged before gate activation per Build Route 5.1 DoD.

## Gate design
- Enforces same-file co-location only for migrations >= 20260219000006 (baseline remediation boundary)
- Pre-cutoff migrations skipped — documented exemption
- Fails naming: migration file, table name, missing statement
- Deliberate-failure regression confirmed

## Controlled exception preserved
CONTRACTS.md §12: authenticated retains SELECT, UPDATE on user_profiles — re-granted in corrective migration.

## Risk
- Medium. New corrective migration modifies privilege posture (idempotent). New merge-blocking gate on all future migrations.