What changed
Implemented workspace switcher UI in WeWeb hamburger popup (10.8.11C).
Switch workspace expands inline showing workspace list from
list_user_tenants_v1. On selection calls set_current_tenant_v1,
updates gs_selectedTenantId, refetches get_user_entitlements_v1.
Also fixed onboarding Case A bug: set_current_tenant_v1 now called
after create_tenant_v1 before set_tenant_slug_v1.

Why safe
WeWeb UI only. All data via allowlisted RPCs. No direct table calls.
No business logic in frontend. Tenant switch enforced server-side.

Risk
Low. UI change only. RPC calls already proven in 10.8.11A and 10.8.11B.

Rollback
Revert WeWeb page changes via WeWeb version history.