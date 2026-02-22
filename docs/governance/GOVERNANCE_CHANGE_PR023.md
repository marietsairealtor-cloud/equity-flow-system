# Governance Change — PR023

## What changed
- `docs/truth/toolchain.json` — extended with postgrest_version and supabase_auth_version fields (lane: cloud-inventory)
- `scripts/ci_cloud_version_pin.ps1` — new lane-only gate asserting PostgREST and Auth versions match pinned truth
- `docs/truth/qa_claim.json` — updated to 4.3
- `docs/truth/qa_scope_map.json` — added 4.3 entry
- `docs/truth/completed_items.json` — added 4.3
- `scripts/ci_robot_owned_guard.ps1` — allowlisted 4.3 proof log

## Why safe
- cloud-version-pin is lane-only — not merge-blocking, not wired into required:
- Gate self-skips if SUPABASE_URL or SUPABASE_ANON_KEY not set
- toolchain.json extension is additive — existing fields unchanged
- No schema, migrations, or CI enforcement surface modified

## Versions pinned
- PostgREST: 14.1 (captured from live cloud project upnelewdvbicxvfgzojg)
- Auth (GoTrue): v2.186.0 (captured from live cloud project)

## Risk
- Low. Lane-only gate, no merge-blocking surface added.

## Rollback
- Remove scripts/ci_cloud_version_pin.ps1
- Revert docs/truth/toolchain.json to remove postgrest_version and supabase_auth_version
- One PR, CI green, QA approve, merge