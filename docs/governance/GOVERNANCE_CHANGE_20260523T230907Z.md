# GOVERNANCE CHANGE -- 10.14B5B Deal Documents Storage Bucket + RLS Policies
UTC: 20260523T230907Z

## What changed
- Migration: 20260522000001_10_14B5B_deal_documents_storage_bucket.sql applied
- New Supabase Storage bucket: deal-documents
  - Private (public = false)
  - File size limit: 10 MB (10485760 bytes)
  - Allowed MIME types: application/pdf, application/msword, application/vnd.openxmlformats-officedocument.wordprocessingml.document, application/vnd.ms-excel, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, image/jpeg, image/jpg, image/png, image/webp
- New storage RLS policy: deal_documents_insert_authenticated
  - FOR INSERT TO authenticated
  - WITH CHECK: bucket_id = 'deal-documents' + full path convention enforced
  - Path convention: {tenant_id}/{deal_id}/documents/{document_type}/{filename}
  - Tenant prefix: foldername(name)[1] = current_tenant_id()
  - Segment [3] must equal 'documents'
  - Segment [4] must be IN ('general', 'signed_purchase_agreement')
  - Filename must be non-empty
- New storage RLS policy: deal_documents_select_authenticated
  - FOR SELECT TO authenticated
  - USING: same path convention as INSERT
- No anon access
- No public bucket access
- No storage deletion policy added (out of scope)
- attach_deal_document_v1 remains governed metadata record path
- list_deal_documents_v1 remains governed metadata list path

## Why safe
Additive only. New bucket + two storage RLS policies.
No existing tables, RPCs, or migrations modified.
Tenant isolation enforced at storage layer via current_tenant_id().
Path convention matches attach_deal_document_v1 validation exactly.

## Risk
Low. Additive only. No existing behavior changed.

## Rollback
Revert PR. Delete bucket from Supabase dashboard if needed.