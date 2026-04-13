# GOVERNANCE CHANGE — Supabase CLI Toolchain Upgrade to 2.90.0
UTC: 20260413T175741Z

## What changed
- docs/truth/toolchain.json: supabase_cli.expect updated from 2.76. to 2.90.
- Supabase CLI binary upgraded from 2.76.11 to 2.90.0 via Scoop

## Why
- 2.90.0 required to support cron schedule wiring for 10.8.11O retention-lifecycle Edge Function
- Existing 2.76.11 pin was blocking governed schedule implementation

## Why safe
- Additive toolchain version bump only
- No schema changes
- No migration changes
- No RPC changes
- CI toolchain gate will enforce 2.90. prefix going forward

## Risk
Low. CLI version bump only. No functional code changes in this PR.

## Rollback
Revert toolchain.json to 2.76. and reinstall 2.76.11 via Scoop.