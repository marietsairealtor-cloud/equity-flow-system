# Governance Change PR100 - 8.10 Share Token Scope Enforcement

## What changed
Added p_deal_id uuid parameter to lookup_share_token_v1. Caller must now
assert the expected deal_id. RPC verifies token.deal_id = p_deal_id via
WHERE clause - mismatch returns NOT_FOUND (no existence leak). Old
single-arg signature dropped. All callers and tests updated.

## Why safe
Token scope was already enforced at storage time via FK. This change
closes the gap where a token for deal A could be used to look up deal B
within the same tenant. Cross-resource misuse now fails deterministically
with the same response shape as an invalid token.

## Risk
Breaking change - all callers of lookup_share_token_v1 must pass deal_id.
Internal tests all updated. External callers must be updated before
deploying this migration.

## Rollback
Revert migration 20260310000003 to restore single-arg lookup_share_token_v1.
