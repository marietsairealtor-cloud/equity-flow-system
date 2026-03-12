# GOVERNANCE_CHANGE_PR108.md

## What changed

Build Route v2.4 Item 9.7 share token maximum lifetime invariant. Migration 20260311000002 drops and recreates create_share_token_v1 with a 90-day maximum lifetime check inserted after the existing expires_at > now() guard. Violations return VALIDATION_ERROR with field-level error on expires_at. New test file 9_7_token_lifetime_invariant.test.sql added with 7 tests. New merge-blocking CI job token-lifetime added to ci.yml and required.needs. CONTRACTS S17 updated to document the invariant.

## Why safe

Signature of create_share_token_v1(uuid, timestamptz) is unchanged. All prior validation logic is preserved in identical order. The 90-day upper bound is additive — only tokens with expires_at > now() + 90 days are rejected. No existing tokens are affected. No RLS, privilege, or tenancy logic changed. The cardinality guard from 9.5 is preserved verbatim.

## Risk

Low. The only behavioral change is that creation returns VALIDATION_ERROR when expires_at exceeds 90 days from now. Callers using reasonable expiry windows (hours, days, weeks) are unaffected. The 90-day limit is well above any expected production token lifetime. No data migration required.

## Rollback

Revert migration 20260311000002_9_7_token_lifetime_invariant.sql via a new forward migration restoring the prior function body from 20260311000001. Remove token-lifetime CI job from ci.yml and required.needs, regenerate required_checks.json via truth:sync. No DB state affected.