# GOVERNANCE CHANGE -- 10.14B5 Acquisition Backend -- Signed APS Documents + Handoff Gate
UTC: 20260521T181917Z

## What changed
- Migration: 20260521000001_10_14B5_signed_aps_documents_handoff_gate.sql applied
- New table: public.deal_documents (tenant-scoped document metadata)
  - Columns: id, tenant_id, deal_id, document_type, storage_path, file_name, mime_type, file_size, uploaded_by, uploaded_at, created_at
  - RLS enabled
  - Direct table access revoked from PUBLIC, anon, authenticated
  - Indexes: tenant/deal, tenant/deal/document_type
- New RPC: attach_deal_document_v1(p_deal_id, p_document_type, p_storage_path, p_file_name, p_mime_type, p_file_size)
  - SECURITY DEFINER, authenticated only, min role: member
  - Tenant-scoped, workspace write-lock enforced
  - Allowed document type: signed_purchase_agreement
  - storage_path validated: must be {tenant_id}/{deal_id}/documents/{document_type}/{filename}
  - Rejects: path traversal, double slash, leading slash, empty filename segment, wrong tenant prefix
- New RPC: list_deal_documents_v1(p_deal_id)
  - SECURITY DEFINER, STABLE, authenticated only, min role: member
  - Returns metadata only -- no file contents
- handoff_to_dispo_v1: extended with signed APS gate
  - New handoff attempts blocked unless signed_purchase_agreement exists in deal_documents
  - Existing dispo deals grandfathered -- gate runs only at handoff time
  - Envelope-safe require_min_role_v1('member') guard added
- create_deal_document_upload_v1: explicitly out of scope -- client uploads directly to Supabase Storage
- 10_11A_acquisition_backend.test.sql updated: APS document seeded before handoff tests
- 10_11A10_activity_log_expansion.test.sql updated: APS document seeded before handoff test

## Storage model
Client uploads file to Supabase Storage directly.
attach_deal_document_v1 records governed metadata after upload.
No file content stored in DB. No base64.
Storage path convention: {tenant_id}/{deal_id}/documents/{document_type}/{filename}

## Why safe
Additive only. New table + two new RPCs + one extended RPC.
handoff_to_dispo_v1 signature unchanged.
Grandfathering ensures no existing dispo deals are affected.
All access via SECURITY DEFINER RPCs -- no direct table exposure.

## Risk
Medium. New table + handoff gate. Existing dispo deals unaffected.
WeWeb must call attach_deal_document_v1 before handoff_to_dispo_v1 for new deals.

## Rollback
Revert PR. Re-run supabase db push. Drop deal_documents table if needed.