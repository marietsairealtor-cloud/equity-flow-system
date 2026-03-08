# Governance Change PR090 — 8.1 Local Clean-Room Replay Proof

## What changed
Updated qa_claim.json to 8.1, added 8.1 entry to qa_scope_map.json,
and allowlisted 8.1 proof log path in ci_robot_owned_guard.ps1.
No migrations, schema, RPC, or CI behavior changes.

## Why safe
Proof-only PR per SOP §3. The clean-room-replay gate already exists and
is merge-blocking from 8.0.1. This item produces a proof artifact showing
the current migration set (including 7.9 migration 20260305000000) replays
deterministically against a clean local DB.

## Risk
None. Truth file updates only. No behavioral change to any gate or code path.

## Rollback
Revert qa_claim.json, qa_scope_map.json, and ci_robot_owned_guard.ps1
entries via a single governance PR.
