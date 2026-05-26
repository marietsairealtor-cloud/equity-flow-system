# GOVERNANCE CHANGE -- fix/10.14B7 -- Correct SET search_path Syntax in Original Migration
UTC: 20260526T001515Z

## What changed
- supabase/migrations/20260525000001_10_14B7_dispo_buyer_packet_fields.sql amended
- Changed SET search_path TO 'public' to SET search_path = public
  on lookup_share_token_public_v1 function definition
- No behavior change. No schema change. No privilege change.
- This is a disk-only fix to ensure supabase db reset reliably lands both RPCs locally.
- Cloud is already correct via 10.14B7A corrective migration.

## Why safe
Syntax-only fix to existing merged migration file.
Function body, grants, and behavior are identical.
10.14B7A corrective migration already handles cloud parity.
This fix ensures local db reset produces clean handoff output.

## Risk
Minimal. No migration runner change. No new migration. No schema impact.

## Rollback
Revert PR.