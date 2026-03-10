# Governance Change PR099 — 8.9 Share Token Expiration Invariant

## What changed
Made expires_at NOT NULL on share_tokens. All tokens must include
expiration at creation time. Updated create_share_token_v1 to require
expires_at (no default). Updated lookup_share_token_v1 — expired tokens
now return NOT_FOUND instead of TOKEN_EXPIRED (no existence leak).
Revocation check still occurs before expiration check.
TOKEN_EXPIRED removed from valid response code set in CONTRACTS.md.

## Why safe
Expiration was already enforced in lookup logic. Making the column NOT
NULL closes the gap where tokens could be inserted without expiration.
Changing expired token response from TOKEN_EXPIRED to NOT_FOUND
eliminates an existence oracle. Existing callers treating TOKEN_EXPIRED
as a failure case will continue to handle NOT_FOUND as failure.

## Risk
Medium. Breaking change for callers checking for TOKEN_EXPIRED code
specifically. All internal tests updated. External callers must treat
NOT_FOUND as the canonical failure for invalid/expired/nonexistent tokens.

## Rollback
Revert migration 20260310000001 and restore previous lookup_share_token_v1
and create_share_token_v1 bodies.
