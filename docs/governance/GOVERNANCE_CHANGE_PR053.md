# Governance Change — PR053

## What changed
Corrective migration 20260219000022: schema-qualify gen_random_bytes default on share_tokens.token column from gen_random_bytes(32) to extensions.gen_random_bytes(32). CI clean-room DB has pgcrypto in extensions schema, not public — migration 000018 fails in CI without this fix.

## Why safe
Single ALTER COLUMN SET DEFAULT change. No schema structure, privilege, or policy changes. Existing data unaffected. All tests pass after db reset with corrective migration applied.

## Risk
None. Default expression fix only. No behavioral change for token generation.

## Rollback
Revert the PR. Drop migration 000022. No data or schema impact.
