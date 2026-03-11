# Governance Change PR103 - 9.3 Reload Mechanism Contract

## What changed
Established canonical reload contract for PostgREST schema cache.
- docs/artifacts/RELOAD_CONTRACT.md: canonical reload path documented.
  SIGUSR1 is the only approved reload mechanism. Reload is deploy-lane
  only. Local harnesses do not claim or depend on reload.
- docs/truth/lane_policy.json: added deploy lane and release lane stubs.
  Deploy lane requires reload evidence in proof logs. Release lane
  requires ci_surface_invariants.mjs to pass after reload.
- docs/truth/lane_checks.json: added deploy and release lane checks.

## Why safe
Documentation and contract only. No schema changes. No RPC changes.
No new CI gates wired to required_checks yet — lanes are stubs that
will be enforced when deploy pipeline is formally defined.

## Non-contradiction statement
Local harnesses do not claim reload. test_postgrest_isolation.mjs
sends SIGUSR1 as test setup (grandfathered, pre-9.3). New harnesses
must not add reload calls outside deploy lane.

## Rollback
Remove RELOAD_CONTRACT.md, revert lane_policy.json and lane_checks.json.
