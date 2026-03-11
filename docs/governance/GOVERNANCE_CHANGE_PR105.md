# GOVERNANCE_CHANGE_PR105.md

## What changed

Build Route v2.4 Item 9.5 token cardinality guard. Migration 20260311000001 drops and recreates create_share_token_v1 with a cardinality check that fires after deal ownership verification and before token generation. Guard counts active tokens per deal (revoked_at IS NULL AND expires_at > now()) and returns CONFLICT when count >= 50. New test file 9_5_token_cardinality_guard.test.sql added with 5 tests.

## Why safe

Signature of create_share_token_v1(uuid, timestamptz) is unchanged. The cardinality guard only adds a pre-generation count check. All prior validation logic (NOT_AUTHORIZED, VALIDATION_ERROR, NOT_FOUND) is preserved in identical order. Revoked and expired tokens are explicitly excluded from the active count so legitimate token rotation is unaffected. No RLS, privilege, or tenancy logic changed.

## Risk

Low. The only behavioral change is that creation returns CONFLICT when a deal already has 50 or more active tokens. No existing callers are affected unless they attempt to create more than 50 active tokens per deal simultaneously. The limit of 50 is well above any expected production usage for a single deal resource.

## Rollback

Revert migration 20260311000001_9_5_token_cardinality_guard.sql via a new forward migration that drops and recreates the prior function body from 20260310000001. No data migration required. No existing tokens are affected by rollback.