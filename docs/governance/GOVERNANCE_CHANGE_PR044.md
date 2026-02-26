# Governance Change — PR044

## What changed
Added merge-blocking CI gate unregistered-table-access (Build Route 6.3A). New job in ci.yml wired into required.needs. New gate script ci_unregistered_table_access.ps1 enumerates authenticated privileges on public schema tables and cross-references against tenant_table_selector.json. truth:sync regenerated required_checks.json. tenant_table_selector.json updated to version 2 with explicit tenant_tables array.

## Why safe
Gate is additive only. No existing gates modified. CI stub pattern used in CI (no live DB). Local gate passes against live DB. Only user_profiles is accessible to authenticated (CONTRACTS.md section 12 controlled exception). No privilege changes, no migration changes, no RLS changes.

## Risk
Low. Gate is a new read-only check. Stub in CI means no new failure mode in CI pipeline. Local execution validated against live Supabase instance.

## Rollback
Revert the PR. Remove unregistered-table-access job from ci.yml and required.needs. Run truth:sync to regenerate required_checks.json. No data or schema impact.
