<<<<<<< HEAD
GOVERNANCE_CHANGE_PR124.md
=======
10.8.11 gov devlog · MDCopyGOVERNANCE_CHANGE_PR124.md
>>>>>>> 53527f0544c43a68e5ed2ab629370843f2af664a
What changed

docs/artifacts/BUILD_ROUTE_V2_4.md item 10.8 — Switch workspace DoD revised. Live tenant list + selection wiring deferred to 10.8.11. Shell (dropdown popup + gs_selectedTenantId variable) ships in 10.8.
docs/artifacts/BUILD_ROUTE_V2_4.md item 10.8.11 — New item added. list_user_tenants_v1 RPC + WeWeb workspace switcher wiring end-to-end.

Why safe

Gap identified during 10.8 implementation: no RPC exists to list user tenants. get_user_entitlements_v1 returns current tenant only.
10.8 shell can merge without the RPC. Switcher is non-functional but present.
10.8.11 completes the wiring in a single follow-up PR. No half-wired state persists on main beyond one PR cycle.
New RPC follows existing patterns: SECURITY DEFINER, no tenant_id param, authenticated only.

Risk
None. Specification addition. No implementation in this PR.
Rollback
Revert PR. 10.8 reverts to original DoD (implied live wiring). 10.8.11 removed.