# Studio Mutation Policy

**Authority:** Build Route v2.4 Items 7.7, 7.11
**Status:** Enforced — operator acknowledgment required for any exception.

## Rule

All schema changes must go through migrations committed to the repository
and merged via PR. No direct schema mutations via Supabase Studio cloud
console are permitted without a compensating migration.

## Emergency Exception Protocol

If an emergency Studio write is made to the live cloud project:

1. The mutation must be immediately followed by a compensating migration
   that replicates the change in SQL form.
2. The compensating migration must be merged via PR within 24 hours.
3. A stop-the-line acknowledgment per AUTOMATION.md §6 is required before
   any further deployments are made.
4. No exceptions to this protocol are permitted without explicit stop-the-line
   acknowledgment.

## Drift Detection

Operators must run `scripts/cloud_schema_drift_check.ps1` periodically and
after any suspected out-of-band mutation. Output must be captured and
finalized via `npm run proof:finalize`.

This script is **never run in CI**. Cloud credentials must not be exposed
in workflow logs. It is operator-run only.

## Deploy-Triggered Drift Check SLA (7.11)

A drift check is **mandatory** after every deploy to the cloud project.
This is a release-triggered obligation, not optional.

Sequence after every deploy:

1. Run `scripts/cloud_schema_drift_check.ps1` against the live cloud project.
2. Capture output to a proof log: `docs/proofs/drift_check_<UTC>.log`.
3. Finalize via `npm run proof:finalize docs/proofs/drift_check_<UTC>.log`.
4. If drift is detected: stop-the-line immediately. No further deploys until resolved.

## Incident Trigger

If console edits are suspected (e.g., schema objects exist that are not
present in `generated/schema.sql`, or a team member reports a Studio edit):

1. Run `scripts/cloud_schema_drift_check.ps1` immediately.
2. If drift is confirmed: open an INCIDENT entry in `docs/threats/INCIDENTS.md`.
3. Author a compensating migration within 24 hours.
4. No deploys until the incident is resolved and drift check passes clean.

## Rationale

Supabase Studio allows direct DDL execution against the live cloud database.
Without this policy, schema drift can silently diverge from migration history,
breaking the append-only migration invariant and undermining the audit trail.