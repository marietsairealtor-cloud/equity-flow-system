# Release Checklist

**Authority:** Build Route v2.4 Item 7.11
**Status:** Enforced — every item must be completed before a release is declared stable.

## Pre-Deploy

- [ ] `git checkout main && git pull` — main is clean
- [ ] `npm run pr:preflight` — PASS
- [ ] `npm run ship` — PASS, zero diffs

## Post-Deploy (mandatory)

- [ ] Run `scripts/cloud_schema_drift_check.ps1` against live cloud project
- [ ] Capture output to `docs/proofs/drift_check_<UTC>.log`
- [ ] Finalize proof: `npm run proof:finalize docs/proofs/drift_check_<UTC>.log`
- [ ] Drift check result: PASS (zero drift)
- [ ] If drift detected: stop-the-line, open INCIDENT, no further deploys

## Incident Trigger (if console edits suspected)

- [ ] Run `scripts/cloud_schema_drift_check.ps1` immediately
- [ ] If drift confirmed: INCIDENT entry in `docs/threats/INCIDENTS.md`
- [ ] Compensating migration authored within 24 hours
- [ ] Drift check re-run: PASS after migration merged