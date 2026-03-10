# Governance Change PR097 — 8.7 Share Token Usage Logging

## What changed
Updated lookup_share_token_v1 to log every lookup attempt to the
append-only activity log via foundation_log_activity_v1. Logging is
best-effort — wrapped in EXCEPTION WHEN OTHERS so logging failures
never interrupt lookup RPC execution. Log entries store only token_hash
(never raw token). All failure categories logged: not_found, revoked,
expired.

## Why safe
Logging is additive and best-effort. No change to RPC return values or
error codes. Existing callers unaffected. foundation_log_activity_v1
already exists and is tested. EXCEPTION handler ensures lookup never
fails due to logging.

## Risk
Low. Best-effort logging means a broken activity_log table will silently
drop log entries but not affect token lookup behavior.

## Rollback
Revert migration 20260309000001 to restore previous lookup_share_token_v1
body without logging calls.
