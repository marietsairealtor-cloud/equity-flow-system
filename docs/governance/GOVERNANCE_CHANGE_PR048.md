# Governance Change — PR048

## What changed
Added merge-blocking CI gate blocked-identifiers (Build Route 6.5). New job in ci.yml wired into required.needs. New gate script ci_blocked_identifiers.ps1 scans supabase/migrations for identifiers listed in blocked_identifiers.json. truth:sync regenerated required_checks.json.

## Why safe
Gate is additive only. No existing gates modified. Scans migrations only (not tooling scripts which legitimately reference service_role). blocked_identifiers.json already existed from truth bootstrap. Gate passes on current migrations.

## Risk
Low. Read-only lint gate. No data, schema, or privilege changes.

## Rollback
Revert the PR. Remove blocked-identifiers job from ci.yml and required.needs. Run truth:sync. No data or schema impact.
