# GOVERNANCE CHANGE — 10.11A5 Acquisition Backend — Deal Properties Schema Normalization
UTC: 20260426T190821Z

## What changed
- Migration: 20260424000001_10_11A5_deal_properties_schema_normalization.sql applied
- Altered public.deal_properties columns:
  - beds: integer -> text
  - baths: numeric -> text
  - sqft: integer -> text
- Existing values preserved via USING ...::text cast
- No new columns. No new tables. No RPCs added.
- garage_parking unchanged -- already text
- Supports shorthand display values: 3+1, 2+1, 2400/1200, 2/4
- get_acq_deal_v1 read path unaffected -- still returns beds, baths, sqft
- Tests: 10_11A5_deal_properties_schema_normalization.test.sql (12 tests, all pass)
- CONTRACTS.md updated -- deal_properties schema change documented
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
Pure schema normalization. No RPC changes. No data loss.
USING cast preserves existing integer/numeric values as text strings.
get_acq_deal_v1 reads these columns as text -- no read path changes needed.
No privilege changes. No new surfaces.

## Risk
Low. ALTER COLUMN with USING cast is safe for integer->text and numeric->text.
No existing callers write directly to these columns -- all writes go through RPCs.
No RPC changes in this item.

## Rollback
Revert PR. Re-run supabase db push to restore prior column types.
Note: rollback ALTER COLUMN text->integer would fail if any shorthand values exist.