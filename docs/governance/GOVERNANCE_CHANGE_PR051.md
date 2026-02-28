# Governance Change — PR051

## Build Route Item
6.8 Seat + role model (per-seat billing-ready)

## What changed
Added tenant_role enum with three values (owner, admin, member) to public schema. Expanded tenant_memberships stub table with tenant_id, user_id, role, and created_at columns. Added four RLS policies enforcing tenant isolation via current_tenant_id() on tenant_memberships. Applied REVOKE ALL on tenant_memberships from anon and authenticated per CONTRACTS.md section 12 privilege firewall.

## Why safe
No existing data in tenant_memberships (stub was id-only with zero rows). New columns and enum are additive. RLS policies follow the identical current_tenant_id() pattern already proven on deals table. REVOKE enforces the existing privilege firewall contract — no new access granted. No RPCs added or modified. No existing queries or application paths reference tenant_memberships columns.

## Risk
Low. Migration is forward-only and additive. If enum values need future expansion, tenant_role is additive-only per GUARDRAILS rule 10. No breaking changes to any existing RPC signature or return shape. No impact on existing RLS policies on other tables.

## Rollback
Drop RLS policies, drop added columns, drop enum type via reverse migration. No data loss since table was a stub with zero rows. No downstream dependencies exist on the new columns or enum.
