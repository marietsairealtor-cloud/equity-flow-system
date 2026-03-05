# Studio Mutation Policy

**Authority:** Build Route v2.4 Item 7.7  
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

## Rationale

Supabase Studio allows direct DDL execution against the live cloud database.
Without this policy, schema drift can silently diverge from migration history,
breaking the append-only migration invariant and undermining the audit trail.
