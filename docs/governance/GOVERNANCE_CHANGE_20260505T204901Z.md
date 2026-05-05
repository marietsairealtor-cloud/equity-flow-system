# GOVERNANCE CHANGE — 10.12C2 Intake Backend — Lead Intake KPI Read Path
UTC: 20260505T204901Z

## What changed
- Migration: 20260505000002_10_12C2_lead_intake_kpis.sql applied
- New RPC: get_lead_intake_kpis_v1(p_date_from timestamptz, p_date_to timestamptz)
  - STABLE SECURITY DEFINER, authenticated only, REVOKE ALL from anon
  - Tenant from current_tenant_id() — NOT_AUTHORIZED if NULL
  - Default window: last 30 days when both params NULL
  - Custom window supported via date params
  - VALIDATION_ERROR when p_date_to < p_date_from (after COALESCE)
  - Returns: new_leads, submission_to_deal_pct, avg_review_time_hours, unreviewed_count, date_from, date_to
  - submission_to_deal_pct excludes buyer submissions from denominator
  - unreviewed_count is current-state, not date-windowed
  - Zero denominator returns 0 (not null/error)
  - No reviewed rows returns 0 avg (not null/error)
- Tests: 10_12C2_lead_intake_kpis.test.sql (12 tests, all pass)
- CONTRACTS.md §68 added (note: verify section number matches actual file)
- qa_scope_map.json, privilege_truth.json, execute_allowlist.json, definer_allowlist.json, rpc_contract_registry.json updated

## Why safe
- Read-only RPC (STABLE). No writes. No write-lock check needed.
- No schema changes. No new tables.
- Tenant isolation enforced via current_tenant_id()

## Risk
Low. Read-only. No existing callers. Additive only.

## Rollback
Revert PR. Function dropped on rollback.