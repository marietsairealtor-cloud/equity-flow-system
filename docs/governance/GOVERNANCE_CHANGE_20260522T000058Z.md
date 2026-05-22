# GOVERNANCE CHANGE -- 10.14B5A Deal Documents Backend -- Generic Document Vault + Remove Path
UTC: 20260522T000058Z

## What changed
- Migration: 20260521000002_10_14B5A_generic_deal_documents_remove.sql applied
- deal_documents table extended:
  - deleted_at timestamptz NULL added
  - deleted_by uuid NULL added
- attach_deal_document_v1 extended:
  - document_type = 'general' now allowed in addition to 'signed_purchase_agreement'
  - Error message updated to reflect both allowed types
  - All other behavior, guard order, and path validation unchanged from 10.14B5
- list_deal_documents_v1 extended:
  - WHERE clause now excludes rows where deleted_at IS NOT NULL
  - All other behavior unchanged from 10.14B5
- New RPC: delete_deal_document_v1(p_document_id uuid)
  - SECURITY DEFINER, RETURNS json
  - REVOKE ALL from PUBLIC, anon; GRANT EXECUTE to authenticated only
  - Guard order: tenant/user context -> require_min_role_v1('member') -> check_workspace_write_allowed_v1() -> validation -> mutation
  - Soft-delete only: sets deleted_at = now(), deleted_by = auth.uid()
  - Cross-tenant document returns NOT_FOUND
  - Storage file deletion is out of scope
- handoff_to_dispo_v1 revised:
  - Signed APS hard gate removed (QA ruling 2026-05-21)
  - All other behavior preserved: guard order, stage check, assignee membership check, activity log, row_version increment, return shape
- 10_14B5_signed_aps_documents_handoff_gate.test.sql updated:
  - Test 11 updated to expect OK instead of CONFLICT (gate removed)

## Design decision
Documents are a shared deal document vault used by ACQ, Dispo, and TC.
No hard APS gate. Send to Dispo modal shows reminder copy only.
Operator does not choose document type in UI -- document_type = 'general' is the default.

## Why safe
Additive schema change only -- two nullable columns added to deal_documents.
attach_deal_document_v1 signature unchanged -- new type value added to allowlist only.
delete_deal_document_v1 is soft-delete only -- no data destroyed, no storage files removed.
list_deal_documents_v1 filter change is backward safe -- deleted rows were not queryable by UI before.
handoff_to_dispo_v1 gate removal is intentional per QA ruling 2026-05-21.
All RPCs remain SECURITY DEFINER, authenticated only, tenant-scoped, envelope-safe.

## Risk
Low. Additive schema change. Gate removal is by design.
No existing data affected. No existing RPC signatures changed.

## Rollback
Revert PR. deleted_at and deleted_by columns can remain (nullable, no impact).
handoff_to_dispo_v1 gate can be restored via new migration if needed.