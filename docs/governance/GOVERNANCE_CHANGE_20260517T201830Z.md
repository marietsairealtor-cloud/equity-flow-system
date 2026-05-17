# GOVERNANCE CHANGE -- 10.14B3 Property Field Expansion -- Electrical + Plumbing Backend
UTC: 20260517T201830Z

## What changed
- Migration: 20260517000003_10_14B3_property_electrical_plumbing.sql applied
- Altered public.deal_properties: added electrical text NULL, plumbing text NULL
- update_deal_properties_v1 extended: electrical and plumbing added to allowed keys
- update_deal_properties_v1: envelope-safe require_min_role_v1('member') guard added
- get_acq_deal_v1 extended: properties.electrical and properties.plumbing added to output
- get_acq_deal_v1: envelope-safe require_min_role_v1('member') guard added
- No new RPCs. No new tables. No signature changes.
- Tests: 10_14B3_property_electrical_plumbing.test.sql (12 tests, all pass)
- CONTRACTS.md updated
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why safe
Additive schema change only. ADD COLUMN IF NOT EXISTS is safe.
Both RPCs use CREATE OR REPLACE -- signature unchanged, internal logic only.
No existing callers broken. No data migration needed.
Member guard is envelope-safe -- returns NOT_AUTHORIZED JSON on failure.
Fields are operator-only -- public seller form is not changed.

## Risk
Low. Two new nullable text columns. Two RPC extensions with no signature change.

## Rollback
Revert PR. Columns remain but are unused. No data loss.