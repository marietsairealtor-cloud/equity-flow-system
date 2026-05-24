# GOVERNANCE CHANGE -- 10.14B6 ACQ UI -- Deal Documents Upload + Send to Dispo Reminder
UTC: 20260524T014919Z

## What changed
- ACQ deal detail page: Documents section added
- Documents section supports: upload, list, remove, and open/download via signed URL
- WeWeb uploads files directly to Supabase Storage (deal-documents bucket)
- After successful Storage upload, UI calls attach_deal_document_v1 (document_type = general)
- UI lists documents via list_deal_documents_v1 (dealDocuments variable)
- UI removes documents via delete_deal_document_v1 (soft delete)
- UI generates signed URL via Supabase Storage client action for file access (no new RPC)
- Send to Dispo modal updated: reminder copy added -- no hard APS gate
- Error handling: error_message variable + fixed toast element added to ACQ page
- No document type selector exposed to operator
- No create_deal_document_upload_v1 usage
- No direct table access in UI
- WORKFLOWS.md updated: upload-deal-documents, fetch-deal-documents, delete-deal-document, open-deal-document workflows + error handling convention added
- Gate: lane-only

## Why safe
UI-only item. No migrations. No new RPCs.
All backend RPCs (attach_deal_document_v1, list_deal_documents_v1, delete_deal_document_v1) already governed by 10.14B5/10.14B5A.
Storage bucket and RLS policies already governed by 10.14B5B.
Signed URL generation is client-side Supabase Storage action -- no new backend surface.

## Risk
Low. UI-only. All backend surfaces already merged and governed.

## Rollback
Revert WeWeb page changes. No migration rollback needed.