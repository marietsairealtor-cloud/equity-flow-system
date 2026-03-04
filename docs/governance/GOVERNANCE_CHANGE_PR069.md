# Governance Change PR069 — 7.5 RLS Negative Suite for Product Tables

## What changed
Added pgTAP test file `supabase/tests/7_5_rls_negative_suite.test.sql` with 12 tests proving product tables are tenant-isolated and negative-tested. Tests cover: direct SELECT/INSERT blocked by privilege firewall on deal_inputs, deal_outputs, activity_log; cross-tenant RPC write blocked on activity_log; share-link cannot bypass tenant boundaries; anon has zero access to deals.

## Why safe
Tests are purely additive. No migrations, schema, RPC, or policy changes. All tests run inside a ROLLBACK transaction — no persistent state. The privilege firewall and RLS policies being tested already exist; this PR only proves they work as intended.

## Risk
None. Read-only test addition. No behavioral change to any production code path.

## Rollback
Delete `supabase/tests/7_5_rls_negative_suite.test.sql` via a single PR. No DB or CI wiring changes required.
