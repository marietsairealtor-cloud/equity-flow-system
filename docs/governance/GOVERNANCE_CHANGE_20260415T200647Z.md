# GOVERNANCE CHANGE — 10.8.11Q Storage API Version Alignment
UTC: 20260415T200647Z

## What changed
- docs/truth/toolchain.json: storage_api key added with known limitation note,
  cloud_version v1.48.20, local_version v1.48.28
- docs/artifacts/SOP_WORKFLOW.md: section 20 added documenting storage-api
  version drift, known limitation, and operator re-alignment instructions
- qa_scope_map.json, qa_claim.json, ci_robot_owned_guard.ps1 registered

## Why this item exists
supabase start warns when local Docker storage-api image differs from the
linked cloud project. Supabase CLI 2.90.0 does not support governed repo-based
image pinning for storage-api (image key rejected in config.toml).
Warning is cosmetic and non-blocking. This item documents the known limitation
and provides operator guidance for future re-alignment.

## Why safe
- No schema changes
- No migrations
- No RPC changes
- No bucket contract changes (CONTRACTS.md sections 30-31 unchanged)
- Documentation-only

## Risk
None. Documentation addition only.

## Future action
When Supabase CLI gains support for storage-api image pinning via config.toml
or another governed mechanism, implement the pin and remove the known limitation
note from toolchain.json and SOP_WORKFLOW.md section 20.