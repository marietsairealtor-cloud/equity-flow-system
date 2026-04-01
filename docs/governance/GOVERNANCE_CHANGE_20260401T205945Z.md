## What changed
Updated docs/truth/definer_allowlist.json to add tenant_context_exempt key alongside existing anon_callable key. The ci_definer_safety_audit.ps1 script was updated to read tenant_context_exempt instead of anon_callable for the tenant context exemption list. New SECURITY DEFINER functions that legitimately do not require current_tenant_id() in their body are now registered under tenant_context_exempt. Existing anon_callable entries retained for backward compatibility.

## Why safe
The tenant_context_exempt list is an audit exemption only -- it does not grant any privileges or bypass any security controls. Functions on this list are still required to be on the allow list, have fixed search_path, and contain no dynamic SQL. The exemption only skips the current_tenant_id() body check for functions that are intentionally tenant-agnostic by design.

## Risk
Low. Additive change only. No existing function behavior changed. No privilege changes. The definer safety audit still enforces all other checks on exempt functions. Misuse would require adding a function to the exemption list without justification -- which requires a governance PR to change definer_allowlist.json.

## Rollback
Remove tenant_context_exempt key from definer_allowlist.json and revert ci_definer_safety_audit.ps1 to read anon_callable. No DB changes required.