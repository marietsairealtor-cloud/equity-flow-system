## What changed
Added triple-registration for `docs/truth/deal_health_thresholds.json` in `scripts/ci_robot_owned_guard.ps1`, `scripts/handoff.ps1`, and `scripts/truth_bootstrap_check.mjs`. Added proof log pattern for 10.8.4. Added `list_deals_v1.json` allowlist entry in robot-owned guard.

## Why safe
All changes are additive only. No existing guard entries, checks, or enforcement rules were removed or modified. New entries follow the exact same pattern as prior Build Route items already in these files.

## Risk
Low. Additive registration only. If deal_health_thresholds.json is missing, handoff fails loudly with a clear error message. No silent failures introduced.

## Rollback
Revert PR139. This removes the 10.8.4 migration, test, truth file, and all three registration entries from ci_robot_owned_guard.ps1, handoff.ps1, and truth_bootstrap_check.mjs cleanly.