# WAIVER_PR417

QA: NOT AN INCIDENT

## Scope
This waiver covers 8 historical M4 (retro-edit) violations identified during the 10.8.3A audit across the following migration files:
- `20260219000003_baseline_deals.sql`
- `20260219000007_tenant_rls_policies.sql`
- `20260219000011_deals_rpc_grants.sql`
- `20260219000012_product_core_tables.sql`
- `20260302000000_6_11_role_guard_helper.sql`
- `20260310000002_8_9_fix_comment_encoding.sql`
- `20260317000001_10_8_1_slug_system.sql`
- `20260318000001_10_8_3_reminder_engine.sql`

## Justification
These edits occurred before the strict migration-first authoring discipline was mechanically enforced.
* **Comment-only edits:** Four files had non-functional comment modifications after original merge.
* **Structural/Lint splits:** Two files were structural splits to pass linting with no privilege end-state change.
* **Pre-production QA mandates:** Two files had functional fixes applied before the migrations reached production.
  - `6_11_role_guard_helper.sql`: Added `REVOKE EXECUTE FROM PUBLIC` on `require_min_role_v1`. Migration was pre-production at time of edit. Privilege end-state is now correct.
  - `10_8_3_reminder_engine.sql`: Added `row_version bigint NOT NULL DEFAULT 1` to `deal_reminders`. Pre-production functional fix mandated by QA per GUARDRAILS S8. Migration had not been applied to production when the edit was made.

None of these edits altered a live production schema out-of-band. The privilege end-state for all files is confirmed correct.

## Expiry Date
2026-04-18 (30 Days)

## QA Sign-Off
Status: APPROVED