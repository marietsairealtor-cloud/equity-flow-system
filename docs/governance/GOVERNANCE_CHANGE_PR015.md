# Governance Change — PR015

## What changed
- `scripts/ci_ship_guard.ps1` — exempt `docs/handoff_latest.txt` from clean tree check
  - `git status --porcelain` now filters out `handoff_latest.txt`
  - Reason: HEAD drift in handoff_latest.txt after merge is by design (structural, not drift)

## Why safe
- ship still enforces: must be on main, clean tree (minus handoff_latest.txt), schema.sql zero diffs, contracts.snapshot.json zero diffs
- handoff_latest.txt HEAD staleness is a known structural property per QA ruling (2026-02-21)
- No security surface affected

## Risk
- Low. Narrows one exemption in ship's clean tree check. All other checks unchanged.

## Rollback
- Revert scripts/ci_ship_guard.ps1 to prior version
- One PR, CI green, QA approve, merge