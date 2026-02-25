# GOVERNANCE_CHANGE_PR041

## What changed
docs/artifacts/BUILD_ROUTE_V2.4.md updated for item 6.2: original DoD clauses restored (SD functions allowlisted, audit passes, pgTAP negative proof exists), explicit proof artifact path added (docs/proofs/6.2_definer_audit_<UTC>.log), gate name made explicit (definer-safety-audit, merge-blocking). Prior version was missing the base DoD and proof path.

## Why safe
Additive only. No gate weakened. No policy removed. No enforcement changed. Documentation correction restoring omitted DoD clauses. Build Route is a policy document — this change adds clarity, not new constraints that could break existing passing gates.

## Risk
Low. Documentation-only change to Build Route. No scripts, migrations, CI jobs, or truth files modified. No executable behavior changed. Worst case: downstream coders have a more complete DoD to satisfy, which is the correct outcome.

## Rollback
Revert docs/artifacts/BUILD_ROUTE_V2.4.md to prior commit. Original DoD clauses would be missing again but no CI gate would break since the gate implementation is in the execution PR (6.2).