# Governance Change — PR037

## What changed
- `.github/workflows/5.2-ipv6-test.yml` — temporary one-off workflow to test direct IPv6 DB connectivity from GitHub Actions runner

## Why
5.2 DoD requires direct DB connectivity smoke test before deciding whether to provision Supabase IPv4 add-on. This workflow tests whether GitHub Actions Ubuntu runner can reach the direct DB host (db.upnelewdvbicxvfgzojg.supabase.co:5432) via IPv6. Result determines next step: pin host (free) or provision IPv4 add-on (paid).

## Temporary
This workflow will be removed after 5.2 proof is finalized. It is not a permanent CI gate.

## Risk
- Low. Read-only connectivity test. No schema, migration, or security surface modified.