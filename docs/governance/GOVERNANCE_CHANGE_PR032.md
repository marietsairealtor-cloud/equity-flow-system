# Governance Change — PR032

## What changed
- `docs/truth/ci_execution_surface.json` — new machine-readable Two-Tier CI Execution Contract
- `scripts/truth_bootstrap_check.mjs` — registered ci_execution_surface.json in required array + schema-lite check
- `scripts/ci_robot_owned_guard.ps1` — registered ci_execution_surface.json + 4.6 proof log allowlist
- `docs/truth/qa_claim.json` — updated to 4.6
- `docs/truth/qa_scope_map.json` — added 4.6 entry
- `docs/truth/completed_items.json` — added 4.6

## What the contract defines
- Tier 1 (Pooler/Stateless): banned SET, SET LOCAL, temp tables, advisory locks, prepared statements, cursors. Gates 4.4 and 4.5 grandfathered.
- Tier 2 (Direct/Sessionful): full session state. Required for RLS fallback tests and populated-data negative tests. Requires Item 5.2 IPv4 provisioning.

## Triple Registration Rule
- Robot-owned guard: registered
- Truth-bootstrap validation gate: registered
- Handoff regeneration surface: N/A (static truth file, not machine-generated)

## Authority
Advisor review 2026-02-23, GOVERNANCE_CHANGE_PR031.md.

## Risk
- Low. New truth file + registration only. No CI enforcement surface, schema, or migration modified.