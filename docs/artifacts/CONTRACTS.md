# CONTRACTS — Immutable Interfaces (v2)

This is an interface spec.
Do not assume an RPC exists because it is listed here; verify existence in `generated/schema.sql` or `docs/handoff_latest.txt`.

---

## 1) RPC Envelope (frozen)

All RPCs return exactly:

```json
{
  "ok": true|false,
  "code": "OK" | "VALIDATION_ERROR" | "CONFLICT" | "NOT_AUTHORIZED" | "NOT_FOUND" | "INTERNAL",
  "data": object|null,
  "error": { "message": string, "fields": { [field]: string } } | null
}
```

Rules:
- `data` is ALWAYS an object. Lists go in `data.items`.
- `code` enum is additive only.

---

## 2) RPC Signature Stability (ENFORCED)

- Any change to an RPC's **parameters or return shape** must use:
  **DROP FUNCTION …; CREATE FUNCTION …**
- `CREATE OR REPLACE FUNCTION` is **forbidden** for signature or return changes.
- Internal logic may change without DROP only if the interface is identical.

Rationale: callers must never observe silent interface drift.

---

## 3) Tenancy Resolution (LOCKED)

`current_tenant_id()` resolves tenant context in this order:
1. If `user_profiles.current_tenant_id` is non-NULL → return it.
2. Else if `current_setting('app.tenant_id', true)` is a valid UUID → return it (dev/test only).
3. Else if JWT tenant claim is enabled and valid UUID → return it.
4. Else return NULL (RLS denies by design).

Mismatch behavior:
- If both profile tenant and JWT tenant are non-NULL and differ:
  - `current_tenant_id()` returns the profile tenant.
  - `tenant_id_mismatch()` returns true.
  - No exceptions; no logging inside `current_tenant_id()`.

---

## 4) UI State Contract (minimal globals)

Allowed WeWeb globals:
- `gs_selectedTenantId` (UI routing cache only; never authorization)
- `gs_selectedDealId` (UI selection only)
- `gs_maoDraft` (local draft)
- `gs_pendingIdempotencyKey` (one per write)
- `gs_slugCheckResult` (onboarding slug check result cache; never authorization)

Forbidden:
- New globals without editing this contract.

---

## 5) Pagination Contract (LOCKED)

### rpc.list_deals_v1

Signature:
```
rpc.list_deals_v1(limit, cursor)
```

Parameters:
- `limit`: default 25, max 100
- `cursor`: opaque string returned by server

Ordering:
- `created_at DESC, id DESC`

Return:
```json
{
  "data": {
    "items": [...],
    "next_cursor": string|null
  }
}
```
---
## 5A) Entitlement RPC Contract (LOCKED, extended 10.8.11M; corrective 10.8.11O2)

### rpc.get_user_entitlements_v1

Returns the current user entitlement state, access mode, and retention state
for the active tenant context. Entitlement is derived from tenant_memberships.
Membership exists = entitled.

Parameters: none (reads from JWT context: tenant_id, user_id).

Security: SECURITY DEFINER, search_path = public.
GRANT EXECUTE to authenticated only. REVOKE from anon.
Source of truth per GUARDRAILS S17.

**10.8.11O2 (corrective extension, no new RPC, no new columns):** After membership is confirmed for the current tenant, the implementation reads `public.tenants.archived_at` for that tenant. When `archived_at IS NOT NULL`, `app_mode` must be `archived_unreachable` and must override subscription-derived `app_mode` until archive state is cleared (e.g. by `restore_workspace_v1`). This aligns RPC output with archived workspace truth already stored on `tenants`.

Returns (in addition to existing fields):
- `app_mode`: `normal` | `read_only_expired` | `archived_unreachable`
- `can_manage_billing`: boolean — true for owner only
- `renew_route`: `billing` | `none` — semantic enum, not a URL
- `retention_deadline`: timestamptz | null — end of 60-day grace window, derived from current_period_end
- `days_until_deletion`: integer | null — countdown after archive begins

Derivation rules:
- if `public.tenants.archived_at IS NOT NULL` for the current tenant → `app_mode = archived_unreachable` (takes priority over subscription-derived rules below; Build Route 10.8.11O2)
- active / expiring → `app_mode = normal`
- expired within 60 days of current_period_end → `app_mode = read_only_expired`
- expired beyond 60 days of current_period_end → `app_mode = archived_unreachable`
- membership + no subscription → `app_mode = read_only_expired`
- no membership → early return, `is_member = false`, `app_mode = normal`
- owner → `can_manage_billing = true`, `renew_route = billing` (when valid)
- admin/member/archived → `can_manage_billing = false`, `renew_route = none`
---

## 6) Idempotency Replay Semantics (LOCKED)

For write RPCs:
- First call stores `result_json` and returns it.
- Replay returns the stored `result_json` verbatim.

---

## 7) Privilege Contract (ENFORCED)

- Core tables must not be readable by `anon` or `authenticated`.
- All reads and writes must occur via allowlisted RPCs.
- Direct SELECT on tenant tables is forbidden.
- Helper functions are internal by default.
- Helpers must not be executable by `authenticated`.

---

## 8) SECURITY DEFINER Safety Rules (LOCKED)

All SECURITY DEFINER RPCs must:

- Set a fixed `search_path` or empty `search_path`.
- Schema-qualify all object references.
- Enforce tenant membership internally.
- Avoid dynamic SQL.
- Never rely on caller privileges.

Violation of any rule requires a new versioned RPC.

---

## 9) Helper Function Exposure (LOCKED)

- Internal helpers must not be directly executable by app roles.
- public.require_min_role_v1(p_min tenant_role) is the authoritative DB-layer role enforcement helper. Enum ordering: owner(0) < admin(1) < member(2). Authorization fails when v_role > p_min (caller is less privileged). Any privileged RPC must call this as its first executable statement (Build Route 7.8).
- No RPC may accept tenant_id as caller input. Tenant ID must be derived strictly from JWT via current_tenant_id(). RPCs that previously accepted p_tenant_id (foundation_log_activity_v1, lookup_share_token_v1) have had that parameter removed (Build Route 7.9).
- Share tokens support explicit revocation via revoke_share_token_v1(text). Revocation is idempotent. Revoked tokens return NOT_FOUND — identical response shape to nonexistent tokens (no existence leak). Revocation overrides expiration: a token with future expires_at is still refused if revoked_at IS NOT NULL (Build Route 8.6). Tenant ID must be derived strictly from JWT via current_tenant_id(). RPCs that previously accepted p_tenant_id (foundation_log_activity_v1, lookup_share_token_v1) have had that parameter removed (Build Route 7.9). Lookup attempts are logged to the activity log via foundation_log_activity_v1 (best-effort, hash-only, never raw token). Failure categories: not_found, revoked, expired (Build Route 8.7). Lookup attempts are logged to the activity log via foundation_log_activity_v1 (best-effort, hash-only, never raw token). Failure categories: not_found, revoked, expired (Build Route 8.7).
- Helpers may be executed only by allowlisted SECURITY DEFINER RPCs.
- Granting EXECUTE to helpers requires contract update.

---

## 10) Output Restriction Rule

- SECURITY DEFINER read RPCs must return only required columns.
- `SELECT *` is forbidden.
- No internal identifiers may be exposed.

---

## 11) Contract Change Policy

Any change to this file requires:
- CI green
- Contract lint passing
- Version bump if public behavior changes

Breaking changes require new RPC versions.
Silent behavior changes are forbidden.
Snapshot changes require accompanying CONTRACTS.md changes in the same PR (enforced by CI gate: policy-coupling).

---

## 12) Privilege Firewall Contract (Authoritative)

Note (9.1): EXECUTE on all business RPCs (create_deal_v1, update_deal_v1, list_deals_v1, get_user_entitlements_v1) revoked from PUBLIC/anon. These RPCs require authenticated context only. Only current_tenant_id() remains anon-accessible via PostgREST surface (utility function, reads JWT claims only).

- Core tables (`tenants`, `tenant_memberships`, `tenant_invites`, `deals`, `documents`, `tenant_subscriptions`, `deal_reminders`) **must not have any GRANTs**
- Privilege truth is defined by the **absence of GRANTs**, not the presence of `REVOKE` lines.
- `user_profiles` is a controlled exception:
  - Allowed: `GRANT SELECT, UPDATE ON public.user_profiles TO authenticated`
  - Forbidden: any GRANT to `anon`, or `GRANT ALL` to any role.
- Privilege enforcement is evaluated on the **final database state** after all migrations.

Documented exception (10.8.1): `resolve_form_slug_v1` and `submit_form_v1` EXECUTE granted to `anon` — per Build Route 10.8.1. Rationale: public intake form URLs require slug resolution and submission without authentication. Both RPCs are SECURITY DEFINER with fixed search_path. No tenant_id param. No internal identifiers exposed. Spam token required on submissions.

---

## 13) Default Privileges Lockdown

- Default privileges set to private-by-default for new objects in schema `public`.
- Impact: No RPC/interface/response-shape changes; snapshot drift is expected from privilege metadata only.
- Feb 7, 2026: contracts snapshot regenerated (CI policy sync).

---

## 14) Artifact Contracts

### Ship Contract
On clean main:
```
npm run ship
→ git status is empty
```

### Publish Contract
No script may commit on main.

### CI Contract
All merges require `required` job (pull_request).

### Recovery Contract
If main is ahead locally → reset, never push.

---

## 15) PROOF_SCRIPTS_HASH Authority

**Authority Source:** `docs/artifacts/AUTOMATION.md`

### Contract Guarantees

1. Script list declared exactly once.
2. Order is authoritative.
3. Encoding explicitly UTF-8 (no BOM).
4. In-memory newline normalization before hashing.
5. Deterministic framing.
6. SHA-256 lowercase hex output.

### Validator Obligations

Validator must:
- Parse authority section markers exactly.
- Extract script list deterministically.
- Reject missing header or end marker.
- Reject empty script list.
- Reject hash mismatch.
- Reject post-proof non-proof changes.

No inference.
No globbing.
No silent fallback.

---

## 16) Repo Layer Boundary — No Cross-Write

- Product layer (`products/**`) MUST NOT modify Foundation (`supabase/foundation/**`).
- Foundation changes ONLY via approved upgrade protocol (governance PR with proof).

---

## 17) Public RPC ↔ Build Route Mapping (ENFORCED)

Every public/app-callable RPC must be registered below with all five required fields.
Gate fails if any public RPC in the schema is missing from this table or lacks any field.
Internal helpers (e.g. require_min_role_v1, current_tenant_id) are excluded.

### Registered RPCs

| RPC name | Build Route item | Purpose | Security class | Tenancy rule |
|---|---|---|---|---|
| create_deal_v1 | 6.6, 10.9 | Create deal; server-computed MAO from assumptions inputs (10.9); stores assumptions snapshot | SECURITY DEFINER, min role: member | current_tenant_id() — no tenant_id param |
| update_deal_v1 | 6.6 | Update existing deal with optimistic concurrency | SECURITY DEFINER, min role: member | current_tenant_id() — no tenant_id param |
| list_deals_v1 | 5A | List deals for current tenant with cursor pagination | SECURITY DEFINER | current_tenant_id() — no tenant_id param |
| get_acq_kpis_v1 | 10.11A, KPI date range 10.11A4 | Acquisition KPIs (contracts signed, lead-to-contract %, avg assignment fee) for current tenant; optional `p_date_from` / `p_date_to` filter by deal `created_at` (both NULL = all time); invalid range → `VALIDATION_ERROR`; avg fee from latest `deal_inputs` per deal | SECURITY DEFINER, min role: member | current_tenant_id() — optional `p_date_from`, `p_date_to` timestamptz |
| get_acq_deal_v1 | 10.11A, read-path corrections 10.11A3 | Single deal detail for Acquisition (deal + deal_properties + latest pricing snapshot including mao and multiplier; top-level last_contacted_at from latest call_log or null) | SECURITY DEFINER, min role: member | current_tenant_id() — p_deal_id only |
| list_acq_deals_v1 | 10.11A | Filtered Acquisition deal list (excludes dispo/tc/closed/dead; follow_ups via deal_reminders) | SECURITY DEFINER, min role: member | current_tenant_id() — p_filter + optional p_farm_area_id |
| update_seller_info_v1 | 10.11A | Partial update of seller + next-action fields on deals | SECURITY DEFINER, min role: member | current_tenant_id() — p_deal_id only |
| update_property_info_v1 | 10.11A | Upsert deal_properties row for a deal (partial field merge) | SECURITY DEFINER, min role: member | current_tenant_id() — p_deal_id only |
| advance_deal_stage_v1 | 10.11A; activity log 10.11A10 | Validated stage transitions (start_analysis / send_offer / mark_contract_signed); writes `stage_change` to `deal_activity_log` (§62) | SECURITY DEFINER, min role: member | non-NULL `current_tenant_id()` and `auth.uid()` — p_deal_id + p_action |
| mark_deal_dead_v1 | 10.11A | Mark deal dead with required reason | SECURITY DEFINER, min role: member | current_tenant_id() — p_deal_id + p_dead_reason |
| handoff_to_dispo_v1 | 10.11A; activity log 10.11A10 | under_contract → dispo; sets assignee_user_id; writes `handoff` to `deal_activity_log` (§62) | SECURITY DEFINER, min role: member | non-NULL `current_tenant_id()` and `auth.uid()` — p_deal_id + p_assignee_user_id |
| handoff_to_tc_v1 | 10.11A | dispo → tc; sets assignee_user_id | SECURITY DEFINER, min role: member | current_tenant_id() — p_deal_id + p_assignee_user_id |
| return_to_acq_v1 | 10.11A | dispo → under_contract (undo dispo) | SECURITY DEFINER, min role: member | current_tenant_id() — p_deal_id only |
| return_to_dispo_v1 | 10.11A | tc → dispo (undo tc) | SECURITY DEFINER, min role: member | current_tenant_id() — p_deal_id only |
| list_deal_media_v1 | 10.11A | List registered deal photo metadata for a deal | SECURITY DEFINER, min role: member | current_tenant_id() — p_deal_id only |
| register_deal_media_v1 | 10.11A | Register storage_path after client upload to deal-photos bucket | SECURITY DEFINER, min role: member | current_tenant_id() — p_deal_id + p_storage_path + p_sort_order |
| delete_deal_media_v1 | 10.11A | Delete deal_media row; returns storage_path for Edge cleanup | SECURITY DEFINER, min role: member | current_tenant_id() — p_media_id only |
| create_deal_note_v1 | 10.11A1 | Append user note or call log on `deal_notes` for a deal | SECURITY DEFINER, min role: member | current_tenant_id() — p_deal_id + p_note_type + p_content |
| list_deal_notes_v1 | 10.11A1 | List notes/call logs for a deal (newest first) | SECURITY DEFINER, STABLE, min role: member | current_tenant_id() — p_deal_id only |
| list_deal_activity_v1 | 10.11A1 | List `deal_activity_log` rows for a deal (newest first) | SECURITY DEFINER, STABLE, min role: member | current_tenant_id() — p_deal_id only |
| update_deal_seller_v1 | 10.11A2 | Jsonb field patch for seller columns on `deals` (§57) | SECURITY DEFINER, authenticated only, min role: member | current_tenant_id() — p_deal_id + p_fields jsonb |
| update_deal_property_v1 | 10.11A2 | Jsonb field patch for address and next-action fields (§57) | SECURITY DEFINER, authenticated only, min role: member | current_tenant_id() — p_deal_id + p_fields jsonb |
| update_deal_properties_v1 | 10.11A8 (corrective to 10.11A6) | Jsonb field patch for `deal_properties` only (§58); does not touch `deal_inputs` or assumptions; repair_estimate owned by `update_deal_pricing_v1` / deal_inputs (§58, §60) | SECURITY DEFINER, authenticated only, min role: member | current_tenant_id() — p_deal_id + p_fields jsonb |
| update_deal_pricing_v1 | 10.11A9 (corrective to 10.11A7) | Append-only pricing snapshot: editable assumptions + server-derived `mao` (§59, §61); updates `deals.assumptions_snapshot_id` | SECURITY DEFINER, authenticated only, min role: member | current_tenant_id() — p_deal_id + p_fields jsonb |
| get_user_entitlements_v1 | 5A | Return entitlement state for current user and tenant | SECURITY DEFINER | current_tenant_id() — no tenant_id param |
| foundation_log_activity_v1 | 6.10 | Append activity log entry for audit trail | SECURITY DEFINER | current_tenant_id() — no tenant_id param |
| lookup_share_token_v1 | 6.7/8.7/8.10 | Look up share token by token + deal_id scope; logs attempt (best-effort, hash-only). deal_id required (8.10). | SECURITY DEFINER | current_tenant_id() - no tenant_id param |
| revoke_share_token_v1 | 8.6 | Revoke a share token immediately (idempotent) | SECURITY DEFINER | current_tenant_id() — no tenant_id param |
| create_share_token_v1 | 8.8/8.9 | Generate cryptographically secure share token (shr_ prefix, 256-bit entropy, hash-at-rest); expires_at required (8.9) | SECURITY DEFINER | current_tenant_id() — no tenant_id param |
| resolve_form_slug_v1 | 10.8.1 | Resolve tenant slug + form type to tenant context for public intake forms | SECURITY DEFINER, anon-callable (§12 exception) | slug input only — no tenant_id param |
| submit_form_v1 | 10.8.1 | Submit public intake form; creates draft deal with MAO pre-fill for seller submissions | SECURITY DEFINER, anon-callable (§12 exception) | slug input only — no tenant_id param |
| list_reminders_v1 | 10.8.3 | List overdue and upcoming reminders for current tenant | SECURITY DEFINER | current_tenant_id() — no tenant_id param |
| create_reminder_v1 | 10.8.3 | Create a deal reminder for current tenant | SECURITY DEFINER, min role: member | current_tenant_id() — no tenant_id param |
| complete_reminder_v1 | 10.8.3; activity log 10.11A10 | Mark reminder completed (idempotent); first completion writes `reminder_completed` to `deal_activity_log`; repeat completion ok=true silent no-op (§62) | SECURITY DEFINER, min role: member | non-NULL `current_tenant_id()` and `auth.uid()` — no tenant_id param |
| accept_invite_v1 | 10.8.7B | Accept app invite token and create tenant membership | SECURITY DEFINER, authenticated only | token lookup — tenant_id derived from tenant_invites row |
| list_farm_areas_v1 | 10.8.6 | List all farm areas for current tenant | SECURITY DEFINER, min role: admin | current_tenant_id() — no tenant_id param |
| create_farm_area_v1 | 10.8.6 | Create a new farm area for current tenant | SECURITY DEFINER, min role: admin | current_tenant_id() — no tenant_id param |
| delete_farm_area_v1 | 10.8.6 | Delete a farm area for current tenant (SET NULL on deals) | SECURITY DEFINER, min role: admin | current_tenant_id() — no tenant_id param |
| accept_pending_invites_v1 | 10.8.7E | Resolve pending invites for authenticated user by exact email match after auth; auto-accept valid invites oldest-first | SECURITY DEFINER, authenticated only | authenticated email derived via auth.uid() -> auth.users.email; no caller email or tenant_id param |
| create_tenant_v1 | 10.8.8A | Create a new workspace and owner membership for the authenticated user; requires p_idempotency_key replay protection | SECURITY DEFINER, authenticated only | tenant created server-side; no caller tenant_id param; idempotency key required; atomic replay via unique constraint |
| set_tenant_slug_v1 | 10.8.8B | Set or update workspace slug for current tenant; enforces one slug per tenant via UNIQUE(tenant_id) + upsert | SECURITY DEFINER, authenticated only, min role owner/admin | current_tenant_id() — no tenant_id param; slug validated server-side; CONFLICT on duplicate slug |
| upsert_subscription_v1 | 10.8.8C | Upsert tenant subscription state from Stripe webhook; service_role only | SECURITY DEFINER, service_role only | tenant_id supplied by Edge Function from verified Stripe metadata; not app-user callable |
| check_slug_access_v1 | 10.8.8D | Check if workspace slug is taken and whether current user is owner/admin of that slug's tenant | SECURITY DEFINER, authenticated only | no caller tenant_id; tenant_id returned only when caller is owner/admin of that slug |
| list_user_tenants_v1 | 10.8.11A, corrected 10.8.11I8 | Return all tenants the current user belongs to, with workspace_name, slug, role, and is_current flag | SECURITY DEFINER, authenticated only | current_tenant_id() — no tenant_id param |
| set_current_tenant_v1 | 10.8.11B | Update current workspace for authenticated user | SECURITY DEFINER, authenticated only | p_tenant_id validated against caller membership — no user_id param |
| get_profile_settings_v1 | 10.8.11D | Return current authenticated user's profile data (user_id, email, display_name) | SECURITY DEFINER, authenticated only | auth.uid() only — no caller user_id or tenant_id param |
| get_workspace_settings_v1 | 10.8.11E | Return current workspace settings (slug, role, tenant_id) for authenticated user | SECURITY DEFINER, authenticated only | current_tenant_id() — no caller tenant_id param |
| update_workspace_settings_v1 | 10.8.11F | Update workspace name, slug, country, currency, measurement_unit for current tenant | SECURITY DEFINER, authenticated only, min role: admin | current_tenant_id() — no caller tenant_id param; slug conflict returns CONFLICT without tenant leak |
| list_workspace_members_v1 | 10.8.11G | List all members of current workspace with email, display_name, and role | SECURITY DEFINER, authenticated only, min role: member | current_tenant_id() — no caller tenant_id param |
| invite_workspace_member_v1 | 10.8.11G | Invite a new member to current workspace by email; rejects duplicates and existing members | SECURITY DEFINER, authenticated only, min role: admin | current_tenant_id() — no caller tenant_id param |
| update_member_role_v1 | 10.8.11G | Update role of existing workspace member | SECURITY DEFINER, authenticated only, min role: admin | current_tenant_id() — no caller tenant_id param |
| remove_member_v1 | 10.8.11G | Remove a member from current workspace | SECURITY DEFINER, authenticated only, min role: admin | current_tenant_id() — no caller tenant_id param |
| list_farm_areas_v1 | 10.8.11H | List all farm areas for current tenant; corrected from admin to member role enforcement | SECURITY DEFINER, authenticated only, min role: member | current_tenant_id() — no caller tenant_id param |
| create_farm_area_v1 | 10.8.11H | Create a new farm area for current tenant; enforces uniqueness | SECURITY DEFINER, authenticated only, min role: admin | current_tenant_id() — no caller tenant_id param |
| delete_farm_area_v1 | 10.8.11H | Delete a farm area for current tenant; cross-tenant protected | SECURITY DEFINER, authenticated only, min role: admin | current_tenant_id() — no caller tenant_id param |
| list_pending_invites_v1 | 10.8.11I3 | List pending (unaccepted, unexpired) invites for current workspace | SECURITY DEFINER, authenticated only, min role: admin | current_tenant_id() — no caller tenant_id param |
| rescind_invite_v1 | 10.8.11I3 | Cancel a pending invite by invite_id; deletes row; cross-tenant protected | SECURITY DEFINER, authenticated only, min role: admin | current_tenant_id() — no caller tenant_id param |
| list_archived_workspaces_v1 | 10.8.11O3 | List archived workspaces owned by caller; includes restore_token and subscription snapshot | SECURITY DEFINER, authenticated only | auth.uid() + owner membership — not JWT current-tenant scoped |
| restore_workspace_v1 | 10.8.11O3 | Restore an archived workspace by p_restore_token; clears archived_at, subscription_lapsed_at, restore_token; owner-only, requires active subscription | SECURITY DEFINER, authenticated only, owner-only (explicit membership check, not require_min_role_v1) | p_restore_token resolves tenant internally — no caller tenant_id param |
| claim_trial_v1 | 10.8.12 | Atomically reserve one-time 30-day free trial for current authenticated user; returns trial_eligible and trial_period_days | SECURITY DEFINER, authenticated only | auth.uid() only — no caller tenant_id param; tenant context exempt |
| update_display_name_v1 | 10.8.11J | Update display name for current authenticated user; blank returns VALIDATION_ERROR | SECURITY DEFINER, authenticated only | auth.uid() only — no caller user_id or tenant_id param |

### Mapping Rules

- Any PR that adds or modifies a public RPC must update this table in the same PR.
- Internal helpers are excluded from this table but must be listed in docs/truth/definer_allowlist.json if SECURITY DEFINER.
- Gate: rpc-mapping-contract (merge-blocking, policy-coupling style).
- Any workspace-write RPC must call `check_workspace_write_allowed_v1()` near the top. Approved exceptions: billing/renewal path, `update_display_name_v1`. Gate: 10.8.11N1 (merge-blocking).

## 17A) Expired Workspace Write Lock (10.8.11N)

All workspace-write RPCs are server-enforced read-only when the workspace subscription is expired, canceled, or has no subscription record.

### Internal helper

`check_workspace_write_allowed_v1()` — SECURITY DEFINER, internal only, REVOKE ALL FROM PUBLIC.
Returns `true` when write is allowed, `false` otherwise.
Checks: tenant context exists, caller is a member, subscription exists, subscription is active or expiring.

### Locked RPCs (retrofitted 10.8.11N)

- `create_deal_v1`
- `update_deal_v1`
- `create_farm_area_v1`
- `delete_farm_area_v1`
- `create_reminder_v1`
- `complete_reminder_v1`
- `create_share_token_v1`
- `update_workspace_settings_v1`
- `update_member_role_v1`
- `remove_member_v1`
- `invite_workspace_member_v1`
- `advance_deal_stage_v1`
- `mark_deal_dead_v1`
- `handoff_to_dispo_v1`
- `handoff_to_tc_v1`
- `return_to_acq_v1`
- `return_to_dispo_v1`
- `update_seller_info_v1`
- `update_property_info_v1`
- `update_deal_seller_v1`
- `update_deal_property_v1`
- `update_deal_properties_v1`
- `update_deal_pricing_v1`
- `register_deal_media_v1`
- `delete_deal_media_v1`
- `create_deal_note_v1`

### Inline subscription check (slug-based resolution)

- `submit_form_v1` — blocked when workspace expired (inline check, no membership context)
- `lookup_share_token_v1` — blocked when workspace expired (inline check, no membership context)

### Approved exceptions (not locked)

- `update_display_name_v1` — profile settings, always allowed
- Billing/renewal path — always allowed

### Universal error message

`This workspace is read-only. Renew your subscription to continue.`

### 10.8.11N1 Coverage Gate (merge-blocking)

`scripts/ci_write_lock_coverage.ps1` — merge-blocking CI gate added in 10.8.11N1.

Verifies at every PR that:
- All helper-required write RPCs call `check_workspace_write_allowed_v1()`
- Inline-check RPCs (`submit_form_v1`, `lookup_share_token_v1`) contain a subscription check

Gate fails clearly with offending RPC names if any in-scope RPC is missing enforcement.
Registered in `ci.yml` under `required.needs` as `write-lock-coverage`.

---

## 18) Share Token Hash-at-Rest (8.4)

- `public.share_tokens` no longer stores raw token text. Column `token` replaced by `token_hash` (bytea, SHA-256 via pgcrypto).
- `public.lookup_share_token_v1` hashes input token before comparison. No signature change.
- `public.share_token_packet` view no longer exposes raw token.
- Unique index `share_tokens_token_hash_unique` replaces `share_tokens_tenant_token_unique`.

## 19) Reload Mechanism Contract (9.3)

Canonical PostgREST schema cache reload path: `docker kill -s SIGUSR1 <postgrest_container>`.
SIGUSR1 is the only approved reload mechanism. Container restart is not a substitute.

Rules:
- Reload is deploy-lane only. Local harnesses do not send reload signals.
- Local harnesses (pgTAP, ci_surface_truth, ci_surface_invariants) run against
  DB or PostgREST without issuing reload. They do not claim reload occurred.
- Cloud/deploy harness must include reload evidence in proof logs after migration apply.
- test_postgrest_isolation.mjs SIGUSR1 usage is grandfathered (pre-9.3 test setup).
  New harnesses must not add reload calls outside deploy lane.
- Release lane: ci_surface_invariants.mjs must pass after reload to confirm
  PostgREST surface matches expected_surface.json.

  
## 20) Token Format Validation Contract (9.4)

`lookup_share_token_v1` enforces token format validation before hashing (Build Route 9.4).

Validation rules (all checked before `extensions.digest()` is called):
- Token must begin with prefix `shr_`
- Token body after prefix must be exactly 64 lowercase hex characters `[0-9a-f]`
- Total token length must be >= 68 characters

Tokens failing any rule return `NOT_FOUND` immediately — identical response shape to nonexistent tokens. No format information is leaked to callers. Logging is best-effort (failure category: `format_invalid`). Signature unchanged: `lookup_share_token_v1(p_token text, p_deal_id uuid)`.

## 21) Token Cardinality Guard Contract (9.5)

`create_share_token_v1` enforces a maximum of 50 active tokens per resource (Build Route 9.5).

Active token definition: `revoked_at IS NULL AND expires_at > now()`.
Revoked and expired tokens do not count toward the limit.
Creation returns `CONFLICT` when active count >= 50.
Signature unchanged: `create_share_token_v1(p_deal_id uuid, p_expires_at timestamptz)`.

## 22) PostgREST Data Surface Truth Contract (9.6)

CI verifies that actual PostgREST data exposure matches `expected_surface.json` (Build Route 9.6).

Enforced fields: `schemas_exposed`, `tables_exposed`, `views_exposed`.
Roles checked: `anon`, `authenticated`.
Scope: `public` schema only. Supabase internal schemas excluded.
Privilege drift causing new table or view exposure fails the `data-surface:truth` CI gate.

Documented exception: `public.user_profiles` SELECT granted to `authenticated` only — per CONTRACTS S12 privilege firewall. No other core tables may appear in `tables_exposed`.

## 23) Share Token Maximum Lifetime Invariant (9.7)

`create_share_token_v1` enforces a maximum token lifetime of 90 days (Build Route 9.7).

Rules (checked in order after existing expires_at validations):
- `expires_at > now()` — token must be in the future (enforced since 8.9)
- `expires_at <= now() + interval '90 days'` — token cannot exceed 90-day lifetime

Violations return `VALIDATION_ERROR` with field-level error:
- `error.fields.expires_at = 'Maximum token lifetime is 90 days'`

Signature unchanged: `create_share_token_v1(p_deal_id uuid, p_expires_at timestamptz)`.

## 24) Entitlement RPC Extension — Subscription Status (10.8.2, corrected 10.8.11K, 10.8.12)

`get_user_entitlements_v1` return shape extended (Build Route 10.8.2).
Status mapping corrected and extended (Build Route 10.8.11K).
`trialing` as a first-class stored and derived status (Build Route 10.8.12).

New fields in `data`:
- `subscription_status`: `active | expiring | expired | trialing | none` — computed server-side from `tenant_subscriptions`. `expiring` when active AND ≤5 days remain OR raw status is `past_due`. `trialing` when raw status is `trialing` (Build Route 10.8.12). `none` when no subscription record exists.
- `subscription_days_remaining`: integer. Returned for `expiring` and `trialing` (days until `current_period_end`). `null` for `active`, `expired`, and `none`.

Raw storage vs derived return:
- `tenant_subscriptions.status` is webhook-written raw Stripe status only. Valid stored values include `trialing` (Build Route 10.8.12); see `upsert_subscription_v1` allowed status list.
- `get_user_entitlements_v1` returns derived banner/routing status, not raw status (except `trialing`, which is passed through as `subscription_status` when the stored row is `trialing`).

Stripe status mapping (raw → derived):
- `trialing` → `trialing` (normal hub routing; `subscription_days_remaining` set from period end)
- `past_due` → `expiring`
- `unpaid` / `incomplete_expired` → `expired`
- `canceled` → `expired`
- `active` / `expiring` + >5 days remain → `active`
- `active` / `expiring` + ≤5 days remain → `expiring`
- no subscription record → `none`

Computation rules:
- Threshold (5 days) lives in RPC only. WeWeb performs zero date math (GUARDRAILS §5).
- `canceled` status or `current_period_end <= now()` → `expired`.
- No subscription record → `none`.

Gate logic derivable from single RPC call:
- No memberships → onboarding Step 1
- Membership + status `none` or `expired` → onboarding Step 3
- Membership + status `active`, `expiring`, or `trialing` → hub

## 25) Privilege Firewall Closure — Historical RPC Gaps (10.8.3B)

Forward migration `20260318000003_10_8_3B_revoke_from_public.sql` closes two historical
privilege gaps identified in the 10.8.3A audit:

- `public.current_tenant_id()` — `REVOKE EXECUTE FROM PUBLIC` applied. Function was
  callable by PUBLIC since its original migration. Now restricted to SECURITY DEFINER
  RPC call chains only, consistent with GUARDRAILS §18.

- `public.foundation_log_activity_v1(text, jsonb, uuid)` — `REVOKE EXECUTE FROM PUBLIC`
  applied. Same historical gap, same remediation.

All other business RPCs had PUBLIC revoked via migration `20260310000004_9_1_revoke_anon_rpc_execute.sql`.
These two were not covered by that migration and are now closed.

## 26) tenant_subscriptions Optimistic Concurrency (10.8.3B)

Forward migration `20260318000004_10_8_3B_tenant_subscriptions_row_version.sql` adds
`row_version bigint NOT NULL DEFAULT 1` to `public.tenant_subscriptions`.

`tenant_subscriptions` is a mutable core record — status and current_period_end are
updated by billing events. GUARDRAILS §8 requires `row_version` on mutable core records.
This was identified as finding B9-F04 in the 10.8.3A audit and is now remediated.
## 27) Deal Health Computation — list_deals_v1 Extended (10.8.4)
Forward migration `20260319000001_10_8_4_deal_health.sql` adds three columns to
`public.deals`: `stage TEXT NOT NULL DEFAULT 'New'` (with CHECK constraint enforcing
authoritative stages per WEWEB_ARCHITECTURE §3), `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`,
and `deleted_at TIMESTAMPTZ`. These are the first functional columns on `public.deals`
beyond the baseline schema.

Adds internal helper `public.get_deal_health_color(stage, updated_at)` — SECURITY DEFINER,
REVOKE from PUBLIC/anon/authenticated. Callable only from allowlisted SECURITY DEFINER RPCs.

`public.list_deals_v1` is replaced via DROP + CREATE (return shape change per CONTRACTS §2).
New signature: `list_deals_v1(p_limit integer, p_cursor text)`. Now returns `stage` and
`health_color` (green/yellow/red) per `docs/truth/deal_health_thresholds.json`.
Tenancy via `public.current_tenant_id()`. Existing callers must handle new fields.

## 28) current_tenant_id() Privilege Exception (10.8.5 RLS Fix)
Item 10.8.3B applied REVOKE EXECUTE FROM PUBLIC to public.current_tenant_id().
This was overly broad -- it broke RLS policy evaluation for tenant-scoped tables
where the policy body calls current_tenant_id() and the query runs as uthenticated.

QA ruling 2026-03-19: GRANT EXECUTE ON FUNCTION public.current_tenant_id() TO authenticated
is authorized and required. This is a narrow restoration (authenticated only, not PUBLIC).
current_tenant_id() is uthenticated-executable specifically to support RLS evaluation.
It remains non-executable by non and PUBLIC.
Migration: 20260319000005_10_8_5_rls_privilege_fix.sql


## 29) Farm Areas Table + Deals FK (10.8.6)
Forward migration 20260319000007 adds public.tenant_farm_areas table (id, tenant_id,
row_version, area_name, created_at). UNIQUE(tenant_id, area_name). RLS ON. REVOKE ALL
from anon and authenticated. Three SECURITY DEFINER RPCs: list_farm_areas_v1,
create_farm_area_v1, delete_farm_area_v1 - all role-gated to admin+ via require_min_role_v1.
Adds deals.farm_area_id UUID FK (ON DELETE SET NULL) to public.deals. Nullable.
Deals tagging to farm areas is soft - deleting a farm area nulls the reference on deals.


## 30) TC Contract Storage Bucket (10.8.7)
Forward migration 20260319000008 creates Supabase Storage bucket tc-contracts.
Configuration: public=false, file_size_limit=10MB, allowed_mime_types=PDF only.
Storage RLS policies enforce exact path contract: {tenant_id}/{deal_id}/contract.pdf
(3 segments, segment[1]=tenant_id via current_tenant_id(), segment[3]=contract.pdf).
No anon access. Authenticated tenant-member access only via Storage client.
No RPC wrapper - access via Supabase Storage client with RLS enforcement.


## 31) Deal Photos Storage Bucket (10.8.7A)
Forward migration 20260320000001 creates Supabase Storage bucket deal-photos.
Configuration: public=false, file_size_limit=10MB, allowed_mime_types=JPEG and PNG only.
Path contract: {tenant_id}/{deal_id}/{photo_id}.jpg|.png (3 segments, segment[1]=tenant_id).
Storage RLS policies enforce segment count=3 and segment[1]=current_tenant_id().
No anon access. Multiple photos per deal supported. No transformations (V1 boundary).
No RPC wrapper - access via Supabase Storage client with RLS enforcement.


## 32) Tenant Invites + Accept Invite RPC (10.8.7B)
Forward migration 20260321000001 creates public.tenant_invites table (id, tenant_id,
invited_email, role, token, invited_by, accepted_at, expires_at, created_at, row_version).
RPC-only access surface: REVOKE ALL from anon and authenticated. No RLS policies.
Token unique constraint. invited_by FK references auth.users(id).
RPC accept_invite_v1(p_token text): SECURITY DEFINER, requires authenticated context.
Validates token existence and expiry. Idempotent via accepted_at marker.
Creates/upserts tenant_memberships row deriving tenant_id and role from invite row.
Returns standard envelope. Prerequisite for 10.8.8 invite acceptance flow.

## 33) Tenant Context Parity Fix (10.8.7C)

Forward migration `20260323T203400Z_10_8_7C_tenant_context_parity.sql` closes parity gap
between CONTRACTS §3 tenancy resolution order and actual database state.

Changes:
- `public.user_profiles.current_tenant_id UUID NULL` added with FK to `public.tenants(id) ON DELETE SET NULL`.
- `public.current_tenant_id()` corrected via DROP + CREATE to resolve in §3 order:
  (1) user_profiles.current_tenant_id, (2) app.tenant_id, (3) JWT tenant claim, (4) NULL.
- RLS policy `user_profiles_select_self` added to `public.user_profiles` (FOR SELECT TO authenticated USING id = auth.uid()).
  This is the minimum policy required for tenant resolution under RLS.
  Controlled exception per CONTRACTS §12 — authenticated self-read only.

No RPC signature changes. No new public RPCs. No changes to auth.users.


## 34) Accept Invite Tenant Context Sync (10.8.7D)
Forward migration 20260324000001 modifies accept_invite_v1 to set user_profiles.current_tenant_id
after successful invite acceptance. No schema changes. Behavioral parity fix only.
After membership creation, upserts user_profiles.current_tenant_id = tenant_id from invite row.
Idempotent. Ensures get_user_entitlements_v1 succeeds immediately after invite acceptance.
Required to complete tenancy contract established in 10.8.7C.


## 35) Pending Invite Resolution RPC (10.8.7E)

Forward migration `20260324000003_10_8_7E_accept_pending_invites.sql` adds
`public.accept_pending_invites_v1()` as the primary post-auth invite-resolution RPC.

Behavior:
- SECURITY DEFINER
- Requires authenticated context
- Accepts no frontend parameters
- Reads authenticated user email from `auth.users.email` via `auth.uid()`
- Does NOT read email from `public.user_profiles`
- Does NOT accept email as caller input
- Resolves pending invites by exact email match only against `public.tenant_invites.invited_email`

Valid pending invite filter:
- `accepted_at IS NULL`
- `expires_at > now()`
- any revoked / cancelled flag, if present, must indicate active invite only

Processing rules:
- Process valid pending invites oldest-first (`created_at ASC`)
- Auto-accept all valid pending invites for the authenticated email
- Create missing `tenant_memberships` rows using tenant_id and role from invite row
- If membership already exists, treat invite as already satisfied
- Duplicate/race conflicts are treated as already satisfied, not hard failure
- Mark accepted/satisfied invites with `accepted_at`
- Partial acceptance is allowed
- Failures are silent to the caller at invite-row level; the RPC should still return `OK` if at least the overall call completed safely

Tenant selection rules:
- If `public.user_profiles.current_tenant_id` already exists, do NOT switch it
- If `current_tenant_id` is NULL, set it to the oldest successfully accepted invite tenant

Return contract:
- Standard RPC envelope
- `data.accepted_count` = number of invites satisfied by this call
- `data.accepted_tenant_ids` = tenant IDs limited only to tenants where membership was created in this call or already existed and the invite was satisfied in this call
- `data.default_tenant_id` = tenant selected as current tenant in this call, or existing current tenant if unchanged, or NULL if none

Relationship to `accept_invite_v1(p_token text)`:
- `accept_invite_v1` remains valid and is NOT removed
- `accept_pending_invites_v1()` becomes the primary `/post-auth` invite-resolution path
- Token-based invite acceptance remains available as legacy/fallback capability

## 36) Create Workspace RPC Contract (10.8.8A)

Forward migration `20260326000001_10_8_8A_create_tenant.sql` adds
`public.create_tenant_v1(p_idempotency_key text)` as the workspace-creation RPC.

Behavior:
- SECURITY DEFINER
- Requires authenticated context
- Accepts no frontend tenant_id parameter
- Accepts one caller-supplied idempotency key (`p_idempotency_key text`)
- Same key → returns stored result verbatim (replay)
- Different key → may create a new workspace
- Creates one `public.tenants` row per unique idempotency key
- Creates one owner `public.tenant_memberships` row for `auth.uid()`
- If `public.user_profiles.current_tenant_id` is NULL, sets it to the new tenant
- If `current_tenant_id` already exists, does NOT overwrite it
- Standard RPC envelope; `data` is always an object, never null

Constraints:
- No caller-supplied tenant_id
- No direct table calls from WeWeb
- Tenant ownership derives from authenticated user only
- Idempotency claim is atomic via unique constraint + INSERT ON CONFLICT
- Replay is envelope-identical to the original call

Relationship to onboarding:
- This RPC is the Step 1 backend for `/onboarding`
- Joining an existing workspace is NOT part of onboarding; existing workspaces are joined by email invite and resolved in `/post-auth`

## 37) Set Workspace Slug RPC Contract (10.8.8B)

Forward migration `20260327000004_10_8_8B_set_tenant_slug.sql` adds
`public.set_tenant_slug_v1(p_slug text)` as the workspace-slug RPC.
Also adds `UNIQUE (tenant_id)` constraint to `public.tenant_slugs` enforcing one slug per tenant at schema level.

Behavior:
- SECURITY DEFINER
- Requires authenticated context
- Accepts no frontend tenant_id parameter
- Sets or updates slug for the current tenant context
- Slug must be lowercase and URL-safe
- Slug uniqueness enforced (UNIQUE on slug column, existing constraint) and tested(in Build Route item 10.8.11E1)
- One slug per tenant enforced (UNIQUE on tenant_id column, added in this migration)
- Upsert: INSERT ... ON CONFLICT (tenant_id) DO UPDATE
- Standard RPC envelope; data always an object, never null

Authorization:
- Caller must be authorized workspace role (owner/admin per implementation contract)
- Tenant context derives from current tenant resolution rules; no caller-supplied tenant_id allowed

Constraints:
- No direct table calls from WeWeb
- Slug must be validated server-side
- Slug collisions must return contract-valid error envelope

## 38) Upsert Subscription RPC Contract (10.8.8C, corrected 10.8.12)

Forward migration `20260329000001_10_8_8C_upsert_subscription.sql` adds
`public.upsert_subscription_v1(p_tenant_id uuid, p_stripe_subscription_id text, p_status text, p_current_period_end timestamptz)` as the billing write RPC.
Build Route 10.8.12 extends allowed `p_status` values and the `tenant_subscriptions.status` check constraint to include **`trialing`** (Stripe free-trial subscriptions written by the webhook).

Behavior:
- SECURITY DEFINER
- Callable by service_role only -- not authenticated, not anon
- Accepts tenant_id as parameter (server-side integration path, not app-user path)
- Validates `p_status` against allowed values: `active`, `expiring`, `expired`, `canceled`, **`trialing`**
- Persisted `tenant_subscriptions.status` may therefore store **`trialing`** as a first-class billing state (alongside the other allowed values)
- Upserts public.tenant_subscriptions on conflict (tenant_id)
- Standard RPC envelope; data always an object, never null

Constraints:
- No direct table calls from Edge Function
- tenant_id must reference existing tenant (FK enforced)
- Called exclusively by stripe-webhook Edge Function
- Not callable from WeWeb

## 39) Slug Ownership Check RPC Contract (10.8.8D)

Forward migration adds `public.check_slug_access_v1(p_slug text)`.

Behavior:
- SECURITY DEFINER
- Requires authenticated context
- Accepts p_slug text only — no caller-supplied tenant_id
- Validates slug format server-side
- Returns slug_taken, is_owner_or_admin, and tenant_id (only when caller is owner/admin)
- No tenant_id leak when caller is not owner/admin

Return contract:
- data.slug_taken: boolean
- data.is_owner_or_admin: boolean
- data.tenant_id: uuid or null

## 40) Profile Settings RPC Contract (10.8.11D, extended 10.8.12A)

`public.get_profile_settings_v1()` returns the current authenticated user's profile data.

Behavior:
- SECURITY DEFINER
- Requires authenticated context
- No caller-supplied user_id
- Derives user from auth.uid() only
- Returns user_id, email, display_name (sourced from public.user_profiles.display_name)
- **10.8.12A:** returns `has_used_trial` (boolean, sourced from `public.user_profiles.has_used_trial`) for trial-eligibility UI; additive field only, same RPC signature
- Returns NOT_AUTHORIZED when auth.uid() is null
- data is always an object, never null

Constraints:
- No direct table calls from WeWeb
- No cross-user data leakage
- anon cannot execute

## 41) Workspace Settings Read RPC Contract (10.8.11E, corrected 10.8.11I2)

`public.get_workspace_settings_v1()` returns current workspace settings for the authenticated user.

Behavior:
- SECURITY DEFINER
- Requires authenticated context
- No caller-supplied tenant_id
- Derives tenant from current_tenant_id() only
- Returns tenant_id, workspace_name, slug, role, country, currency, measurement_unit
- workspace_name sourced from public.tenants.name
- country sourced from public.tenants.country
- currency sourced from public.tenants.currency
- measurement_unit sourced from public.tenants.measurement_unit
- Returns NOT_AUTHORIZED when current_tenant_id() is null
- Returns NOT_AUTHORIZED when caller is not a member of the current tenant
- data is always an object, never null

Constraints:
- No direct table calls from WeWeb
- No cross-tenant data leakage
- anon cannot execute


## 42) Workspace Settings General RPCs Contract (10.8.11F)

`public.update_workspace_settings_v1(p_workspace_name, p_slug, p_country, p_currency, p_measurement_unit)` updates workspace settings for the current tenant.

Behavior:
- SECURITY DEFINER
- Requires authenticated context
- No caller-supplied tenant_id
- Derives tenant from current_tenant_id() only
- require_min_role_v1('admin') is first executable statement
- Supports partial updates via DEFAULT NULL parameters
- Blank string values rejected with VALIDATION_ERROR
- Slug enforces lowercase URL-safe format (3-50 chars)
- Slug conflict returns CONFLICT without leaking tenant_id
- Returns updated workspace state in data object
- data is always an object, never null

Constraints:
- No direct table calls from WeWeb
- No cross-tenant updates possible
- anon cannot execute
- member role cannot execute

## 43) Workspace Members RPCs Contract (10.8.11G)

`public.list_workspace_members_v1()` returns all members of the current workspace.
`public.invite_workspace_member_v1(p_email, p_role)` creates an invite for current workspace.
`public.update_member_role_v1(p_user_id, p_role)` updates role of existing member.
`public.remove_member_v1(p_user_id)` removes a member from current workspace.

Behavior (all four):
- SECURITY DEFINER, search_path = public
- Requires authenticated context
- No caller-supplied tenant_id
- Derives workspace from current_tenant_id() only

Role enforcement:
- list_workspace_members_v1: require_min_role_v1('member')
- invite, update, remove: require_min_role_v1('admin')

invite_workspace_member_v1 constraints:
- Rejects blank email with VALIDATION_ERROR
- Rejects null role with VALIDATION_ERROR
- Rejects existing member with CONFLICT
- Rejects duplicate pending invite with CONFLICT
- Token generated via gen_random_uuid()
- Invite expires in 7 days

update_member_role_v1 constraints:
- Rejects null user_id or role with VALIDATION_ERROR
- Returns NOT_FOUND if member not in current tenant

remove_member_v1 constraints:
- Rejects null user_id with VALIDATION_ERROR
- Returns NOT_FOUND if member not in current tenant

Schema changes:
- public.user_profiles.display_name text column added

data is always an object, never null.
anon cannot execute any of these RPCs.

## 44) Workspace Farm Areas RPCs Contract (10.8.11H)

`public.list_farm_areas_v1()` lists all farm areas for the current tenant.
`public.create_farm_area_v1(p_area_name text)` creates a new farm area.
`public.delete_farm_area_v1(p_farm_area_id uuid)` deletes a farm area.

Behavior (all three):
- SECURITY DEFINER, search_path = public
- Requires authenticated context
- No caller-supplied tenant_id
- Derives workspace from current_tenant_id() only

Role enforcement:
- list_farm_areas_v1: require_min_role_v1('member') — corrected from admin (10.8.6)
- create, delete: require_min_role_v1('admin')

Corrective note:
- list_farm_areas_v1 was originally authored in 10.8.6 with admin role enforcement
- 10.8.11H corrects this to member per system read/write pattern
- Response shape also corrected: id → farm_area_id, internal fields removed

list_farm_areas_v1 returns:
- data.items[].farm_area_id
- data.items[].area_name
- data.items[].created_at

create_farm_area_v1 constraints:
- Blank name returns VALIDATION_ERROR
- Duplicate name returns CONFLICT via unique_violation

delete_farm_area_v1 constraints:
- Null farm_area_id returns VALIDATION_ERROR
- Non-existent or cross-tenant returns NOT_FOUND

data is always an object, never null.
anon cannot execute any of these RPCs.

## 45) Invite Email Delivery Contract (10.8.11I1)

`public.trigger_invite_email()` is a SECURITY DEFINER trigger function that fires
on INSERT to `public.tenant_invites`.

Behavior:
- Fires AFTER INSERT on public.tenant_invites FOR EACH ROW
- Reads service_role_key from vault.decrypted_secrets
- Calls send-invite-email Edge Function via net.http_post
- Edge Function calls supabase.auth.admin.inviteUserByEmail
- Email failure does not block invite creation (EXCEPTION path returns NEW)
- No caller-supplied parameters
- No tenant context required — fires as infrastructure trigger

Dependencies:
- pg_net extension enabled in extensions schema
- vault secret: service_role_key must exist
- Edge Function: send-invite-email must be deployed
- Supabase Auth invite template configured

Constraints:
- Not callable from WeWeb
- Not callable by authenticated or anon roles
- Trigger only — no direct execution path

## 46) Pending Invites RPC Contract (10.8.11I3)

`public.list_pending_invites_v1()` returns pending invites for the current workspace.
`public.rescind_invite_v1(p_invite_id uuid)` cancels a pending invite.

Behavior (both):
- SECURITY DEFINER, search_path = public
- Requires authenticated context
- No caller-supplied tenant_id
- Derives workspace from current_tenant_id() only
- require_min_role_v1('admin') is first executable statement

list_pending_invites_v1:
- Returns data.items array (empty array when no pending invites, never null)
- Only returns invites where accepted_at IS NULL AND expires_at > now()
- invited_by returns inviter email from auth.users

rescind_invite_v1:
- Deletes invite row from public.tenant_invites
- Only rescinds pending invites (accepted_at IS NULL AND expires_at > now())
- Returns NOT_FOUND for accepted, expired, or cross-tenant invites
- Returns NOT_FOUND for cross-tenant invite attempts
- Returns VALIDATION_ERROR if p_invite_id is null

Constraints:
- No direct table calls from WeWeb
- No cross-tenant access
- anon cannot execute either RPC

## 47) Seat Billing Sync Contract (10.8.11I5)

`public.trigger_seat_sync()` is a SECURITY DEFINER trigger function that fires
on INSERT and DELETE on `public.tenant_memberships`.

Behavior:
- Fires AFTER INSERT and AFTER DELETE on public.tenant_memberships FOR EACH ROW
- Reads service_role_key from vault.decrypted_secrets
- Calls sync-seat-count Edge Function via net.http_post
- Edge Function counts all active tenant_memberships for the tenant
- Edge Function updates Stripe subscription quantity via STRIPE_PRICE_ID match
- Seat count = all members including owner (absolute recomputation, idempotent)
- Sync failure does not block membership changes (EXCEPTION path returns NEW/OLD)

Dependencies:
- pg_net extension enabled in extensions schema
- vault secret: service_role_key must exist
- Edge Function: sync-seat-count must be deployed
- Supabase Edge Function secret: STRIPE_PRICE_ID must match exact Stripe price ID
- Supabase Edge Function secret: STRIPE_SECRET_KEY must be valid

Constraints:
- Not callable from WeWeb
- Not callable by authenticated or anon roles
- Trigger only — no direct execution path
- No subscription for tenant → no-op (deliberate)
- No matching seat price item → no-op (deliberate)

## 48) Re-Invite Email Delivery Contract (10.8.11I7)

`public.auth_user_exists_v1(p_email text)` is a SECURITY DEFINER helper function
used by the send-invite-email Edge Function to determine invite email path.

Behavior:
- SECURITY DEFINER, search_path = public
- Reads from auth.users only
- Returns boolean — true if email exists, false if not
- Case-insensitive match via lower()
- No data leakage — boolean only

Access:
- EXECUTE granted to service_role only
- Not callable by authenticated or anon
- Not callable from WeWeb

send-invite-email Edge Function revised behavior:
- New user (not in auth.users): calls supabase.auth.admin.inviteUserByEmail()
- Existing user (in auth.users): calls supabase.auth.signInWithOtp() with shouldCreateUser: false
- Both paths redirect to APP_URL/auth
- After login: /post-auth calls accept_pending_invites_v1() — invite resolved
- Email failure does not block invite creation
- invite row remains in tenant_invites on email failure

Dependencies:
- Supabase Magic Link email template repurposed for existing-user re-invite emails
- APP_URL Edge Function secret must be configured
- Magic Link template dependency is project-level — any future passwordless login
  flow will share this template

Constraints:
- No frontend email logic
- No direct table access from UI
- Existing invite acceptance flow unchanged

## 49) Update Display Name RPC Contract (10.8.11J)

`public.update_display_name_v1(p_display_name text)` updates the display name
for the current authenticated user.

Behavior:
- SECURITY DEFINER, search_path = public
- Requires authenticated context
- No caller-supplied user_id
- Derives user from auth.uid() only
- Updates public.user_profiles.display_name
- Blank or null input returns VALIDATION_ERROR
- Returns NOT_FOUND if no user_profiles row exists for user
- Returns updated display_name in data envelope

Constraints:
- No direct table calls from WeWeb
- No cross-user updates possible
- anon cannot execute

## 50) Retention Lifecycle Automation Contract (10.8.11O)

`public.process_workspace_retention_v1()` is an internal SECURITY DEFINER function
called daily by the `retention-lifecycle` Edge Function (service_role only).

Behavior:
- SECURITY DEFINER, search_path = public
- Not callable from WeWeb
- Not callable by authenticated or anon roles
- Service_role only

Lifecycle steps executed in order:
1. Recovery: clears `tenants.subscription_lapsed_at` for workspaces that are
   not yet archived and have a valid active subscription again
2. Lapse detection: sets `tenants.subscription_lapsed_at = now()` on first
   detection for workspaces with members but no subscription row
3. Archive (subscription path): archives workspaces where
   `tenant_subscriptions.current_period_end <= now() - 60 days`
4. Archive (no-subscription path): archives workspaces where
   `tenants.subscription_lapsed_at <= now() - 60 days` and no subscription exists
5. Hard delete: explicit ordered delete for workspaces where
   `tenants.archived_at <= now() - 6 months`

Hard delete order:
- DELETE FROM public.activity_log WHERE tenant_id = ...
- DELETE FROM public.tenant_memberships WHERE tenant_id = ...
- DELETE FROM public.tenants WHERE tenant_id = ...
- CASCADE handles: deal_reminders, deal_tc, deal_tc_checklist, draft_deals,
  tenant_farm_areas, tenant_invites, tenant_slugs, tenant_subscriptions
- user_profiles.current_tenant_id SET NULL (proven FK rule)

Schema additions (public.tenants):
- subscription_lapsed_at timestamptz DEFAULT NULL
- archived_at timestamptz DEFAULT NULL

Renewal behavior:
- Renew within 60-day read-only window: subscription_lapsed_at cleared
  automatically on next processor run, archive does not occur
- Renew after archive: does not auto-restore, explicit restore required (10.8.11O1)
- Renew after hard delete: no recovery

Returns:
- data.recovery_count: integer
- data.lapsed_count: integer
- data.archived_count: integer
- data.deleted_count: integer
- data.run_at: timestamptz

Edge Function:
- Name: retention-lifecycle
- Schedule: 02:00 UTC daily
- Uses SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY

## 51) Archived Workspace Restore RPC Contract (10.8.11O1) — superseded

**Superseded by §52 (10.8.11O3).** The O1 zero-parameter `restore_workspace_v1()` form is removed; runtime contract is token-targeted restore plus list RPC below.

Historical (O1): `public.restore_workspace_v1()` restored an archived workspace using JWT current-tenant context only.

---

## 52) Archived Workspace Restore Targeting (10.8.11O3)

**10.8.11P (UI wiring, no new RPCs):** `list_archived_workspaces_v1` and `restore_workspace_v1(p_restore_token uuid)` are wired in WeWeb. The onboarding **Archived workspaces** section loads the list via `list_archived_workspaces_v1`. When billing is active again, **Restore workspace** calls `restore_workspace_v1` with the row’s `restore_token`. When billing is inactive, **Subscribe to restore workspace** uses the Supabase Edge Function `create-restore-checkout-session` (not the new-workspace `create-checkout-session` flow): the function accepts `restore_token`, validates it server-side against the same list RPC, creates a Stripe Checkout session, and returns the customer to `/onboarding?restore_checkout=success` on success.

### `public.list_archived_workspaces_v1()`

Returns archived workspaces where the authenticated caller is **owner** (not JWT-scoped to a single current tenant).

Behavior:
- SECURITY DEFINER, STABLE, search_path = public
- Requires authenticated context (`auth.uid()`)
- Each row includes: workspace_name, slug, archived_at, **restore_token**, role, subscription_status, current_period_end
- Empty list is OK when caller has no archived owned workspaces

Failure envelopes:
- NOT_AUTHORIZED: unauthenticated

Constraints:
- anon cannot execute
- Does not call `check_workspace_write_allowed_v1()` (read-only aggregate)

### `public.restore_workspace_v1(p_restore_token uuid)`

Restores an archived workspace to normal reachable state by resolving `public.tenants.restore_token` internally.

Behavior:
- SECURITY DEFINER, search_path = public
- Requires authenticated context
- **No caller-supplied tenant_id** — tenant is resolved from `restore_token` where `archived_at IS NOT NULL`
- Owner-only on the resolved tenant: NOT_AUTHORIZED otherwise
- `p_restore_token` NULL → VALIDATION_ERROR

Restore is allowed only when all are true:
- token matches a row with `archived_at IS NOT NULL` (otherwise NOT_FOUND)
- caller is workspace owner for that tenant
- subscription is active again (status IN ('active','expiring') AND current_period_end > now())

Restore behavior:
- clears `tenants.archived_at`, `tenants.subscription_lapsed_at`, and `tenants.restore_token`
- workspace becomes reachable again; post-auth routing and write access follow existing entitlement + write-lock logic

Failure envelopes:
- NOT_AUTHORIZED: unauthenticated or not owner
- VALIDATION_ERROR: `p_restore_token` is NULL
- NOT_FOUND: token unknown or workspace not archived / not eligible
- CONFLICT: subscription not active
- INTERNAL: server error

Renewal behavior (unchanged in intent from §50 / §51):
- renew within 60-day read-only window: auto recovery of lapse state without archive
- renew after archive: explicit `restore_workspace_v1(uuid)` required (after `restore_token` is present from archive)
- renew after hard delete: no recovery

Constraints:
- No direct table calls from WeWeb
- Approved write-lock exemption: does not call `check_workspace_write_allowed_v1()`
- anon cannot execute

---

## 53) Free Trial Reservation and Confirmation (10.8.12)

One-time, user-scoped free trial (30 days) with a two-phase RPC model: `claim_trial_v1()` reserves trial state before Stripe Checkout; `confirm_trial_v1(uuid, uuid)` finalizes usage after the webhook persists a `trialing` subscription. User profile columns: `has_used_trial`, `trial_claimed_at` (2-hour reservation window), `trial_started_at` (set on confirmation).

Edge Functions: `create-checkout-session` calls `claim_trial_v1` before creating a Checkout session; `stripe-webhook` calls `upsert_subscription_v1` then `confirm_trial_v1` when `customer.subscription.created` resolves to `trialing` and metadata includes `user_id` and `tenant_id`.

### `public.claim_trial_v1()`

Atomically reserves a trial when the caller has not used a trial and has no active reservation (`trial_claimed_at` null or older than 2 hours).

Behavior:
- SECURITY DEFINER, search_path = public
- Requires authenticated context (`auth.uid()`)
- No parameters — no caller-supplied `tenant_id`
- On success with reservation: `data.trial_eligible = true`, `data.trial_period_days = 30`
- On success without reservation (already used or active hold): `data.trial_eligible = false`, `data.trial_period_days = null`
- Does not use `current_tenant_id()` — listed in `tenant_context_exempt` (definer_allowlist)

Failure envelopes:
- NOT_AUTHORIZED: unauthenticated
- NOT_FOUND: no `user_profiles` row for `auth.uid()`
- INTERNAL: unexpected error

Constraints:
- `GRANT EXECUTE` to `authenticated` only (REVOKE PUBLIC)
- anon cannot execute

### `public.confirm_trial_v1(p_user_id uuid, p_tenant_id uuid)`

Finalizes trial usage after Stripe has created a subscription in `trialing` state. Verifies `p_user_id` is owner of `p_tenant_id`, profile exists, optional idempotent return if `has_used_trial` already true, and that a valid reservation exists (`trial_claimed_at` within the last 2 hours).

Behavior:
- SECURITY DEFINER, search_path = public
- **Not app-user callable** — `REVOKE` from `authenticated`; invoked with **service_role** from `stripe-webhook` only
- Sets `has_used_trial = true`, `trial_started_at = now()` on success
- Idempotent: already confirmed returns `already_confirmed: true`

Failure envelopes:
- VALIDATION_ERROR: `p_user_id` or `p_tenant_id` null
- NOT_FOUND: user profile missing
- NOT_AUTHORIZED: user is not owner of the tenant
- CONFLICT: no valid reservation (missing or expired `trial_claimed_at`)
- INTERNAL: unexpected error

Constraints:
- Listed in `tenant_context_exempt` (definer_allowlist) — no JWT current-tenant requirement
- Not in `execute_allowlist.json`

---

## 54) MAO Calculator — create_deal_v1 assumptions + server MAO (10.9)

**§RPC `create_deal_v1`** — authoritative narrative for MAO persistence (Build Route 10.9). This section narrows assumptions validation and MAO semantics on top of the core deals write path introduced in Build Route 6.6.

Forward migration `20260418000001_10_9_mao_calculator.sql` replaces `create_deal_v1` via DROP + CREATE with **identical signature**: `create_deal_v1(p_id uuid, p_calc_version int default 1, p_assumptions jsonb default '{}')`.

### Assumptions shape (required keys for MAO path)

`p_assumptions` is a JSON object. For successful deal creation the implementation requires these **string** fields (trimmed), each matching `^\d+(\.\d+)?$` before cast:

| Key | Role |
|-----|------|
| `arv` | After-repair value |
| `repair_estimate` | Repair budget |
| `desired_profit` | Target profit / assignment fee |
| `multiplier` | MAO multiplier strictly between 0 and 1 (e.g. 0.70, 0.75, 0.80) |

Optional keys may be present; they are merged into the stored snapshot. The key `mao` may be sent by the client but is **ignored for persistence**: the server sets `mao` to the computed value.

### Server-computed MAO

`mao := ROUND(arv::numeric * multiplier::numeric - repair_estimate::numeric - desired_profit::numeric)` (implementation uses numeric `ROUND` without second argument — integer dollars).

Stored snapshot: `p_assumptions || jsonb_build_object('mao', <computed>)` so `deal_inputs.assumptions` always carries backend-authoritative `mao`.

### Validation and errors

- `p_id` null → `VALIDATION_ERROR` (`p_id` required).
- Missing/blank/non-matching string for `arv`, `repair_estimate`, `desired_profit`, or `multiplier` → `VALIDATION_ERROR` with field hints.
- Negative `arv`, `repair_estimate`, or `desired_profit` after parse → `VALIDATION_ERROR`.
- `multiplier` ≤ 0 or > 1 → `VALIDATION_ERROR`.
- Workspace not writable (`check_workspace_write_allowed_v1`) → `NOT_AUTHORIZED` (read-only/expired messaging per §17A).
- Duplicate `p_id` for tenant → `CONFLICT`.
- Unexpected SQL → `INTERNAL`.

### Success payload

Standard envelope with `data` including at least: `id`, `tenant_id`, `assumptions_snapshot_id`, `mao` (matches stored snapshot).

---

## 55) Acquisition backend — deals schema, stages, and RPCs (10.11A)

**Authority:** migrations `20260419000001`–`20260419000005` (extend `public.deals`, `deal_properties`, `deal_media`, stage normalization, SECURITY DEFINER RPCs). Deal notes and activity log tables/RPCs: **10.11A1** — migration `20260420000001_10_11A1_deal_notes_activity_log.sql` (see §56). **`get_acq_deal_v1` read-path corrections (10.11A3):** migration `20260423000001_10_11A3_acq_deal_detail_read_corrections.sql` — no new RPC, no schema changes (function body only). Response `data.pricing` includes `mao` and `multiplier`; `data.last_contacted_at` is the timestamp of the most recent `call_log` row in `deal_notes`, or `null` when none exist. **`get_acq_kpis_v1` KPI date range (10.11A4):** migration `20260423000002_10_11A4_acq_kpi_date_range.sql` — replaces zero-arg function with optional `p_date_from` / `p_date_to`; see RPC table below.

### Canonical deal stages

`public.deals.stage` is constrained to lowercase snake_case values only:

`new`, `analyzing`, `offer_sent`, `under_contract`, `dispo`, `tc`, `closed`, `dead`.

Migration `20260419000004` aligns `get_deal_health_color` and `update_deal_v1` with these values; terminal immutability for `update_deal_v1` remains `closed` and `dead`.

### Deals table extensions (10.11A)

In addition to existing columns, Acquisition uses: `created_at`, `address`, `assignee_user_id` (FK `auth.users`), seller contact and notes fields (`seller_*`), `next_action` / `next_action_due`, `dead_reason`, and continued use of `farm_area_id`, `row_version`, `deleted_at`, etc., as defined in migration `20260419000001`.

### Tenant-scoped companion tables

- **`public.deal_properties`** — one row per deal (`UNIQUE(deal_id)`), property-condition fields (beds, baths, deficiency tags, repair_estimate on the property record, etc.). RLS: `tenant_id = current_tenant_id()`. No direct table grants; reads/writes go through RPCs.
  - **10.11A5:** `deal_properties.beds`, `baths`, and `sqft` are `text` (previously integer/numeric). Supports shorthand display values such as `3+1`, `2+1`, and `2400/1200`. Existing values were preserved via cast in migration. **`get_acq_deal_v1`** read path is unaffected (still returns `properties.beds`, `properties.baths`, `properties.sqft` as text-compatible JSON values).
- **`public.deal_media`** — photo metadata (`storage_path`, `sort_order`, `uploaded_by`, …) keyed to `deal_id`. RLS: `tenant_id = current_tenant_id()`. Storage objects live in the existing deal-photos bucket per §31 path contract; `register_deal_media_v1` / `delete_deal_media_v1` govern metadata.
- **`public.deal_notes`** — user-authored notes and call logs per deal (`note_type` ∈ `note`, `call_log`). RLS: `tenant_id = current_tenant_id()`. Append-only write path via `create_deal_note_v1`; no edit/delete RPC. See §56.
- **`public.deal_activity_log`** — system and workflow activity rows for a deal (timeline). RLS: `tenant_id = current_tenant_id()`. Inserts are server-side from DEFINER RPCs (e.g. stage changes); clients read via `list_deal_activity_v1`. See §56.

### RPC surface (narrative)

All listed functions use the standard JSON envelope (`ok`, `code`, `data`, `error`), resolve tenant via `current_tenant_id()`, enforce workspace write lock via `check_workspace_write_allowed_v1()` on mutating paths, and use `require_min_role_v1` at **member** unless otherwise noted.

| RPC | Role |
|-----|------|
| `get_acq_kpis_v1(p_date_from timestamptz DEFAULT NULL, p_date_to timestamptz DEFAULT NULL)` | Read KPI aggregates for the Acquisition dashboard. **Replaces** the old zero-arg surface. Both parameters NULL = all-time; otherwise counts and averages include only deals whose `created_at` falls within the range (inclusive when each bound is set). If both bounds are set and `p_date_to` is before `p_date_from`, returns `VALIDATION_ERROR`. **`avg_assignment_fee`** uses the **latest** `deal_inputs` row per qualifying deal (by `created_at`), then averages `assignment_fee` from those snapshots over terminal-stage deals in range. |
| `list_acq_deals_v1(p_filter text, p_farm_area_id uuid)` | List active Acquisition pipeline deals; `p_filter` ∈ `all`, `new`, `analyzing`, `offer_sent`, `under_contract`, `follow_ups` (reminder-driven). |
| `get_acq_deal_v1(p_deal_id uuid)` | Full detail for one deal including embedded `properties` and latest `pricing` from `deal_inputs` (`pricing` includes `mao` and `multiplier` — 10.11A3). Top-level `last_contacted_at` from the most recent `call_log` on `deal_notes`, or `null` if there is no call log. No new RPC; no schema changes. |
| `update_seller_info_v1(...)` | Partial updates to seller and next-action columns on `deals`. |
| `update_property_info_v1(...)` | Upsert `deal_properties` with partial merge. |
| `update_deal_properties_v1(p_deal_id uuid, p_fields jsonb)` | Jsonb patch on existing `deal_properties` row only (10.11A6 — §58; **`repair_estimate` removed §60 / 10.11A8**); does not upsert or touch `deal_inputs` / assumptions — use `update_deal_pricing_v1` for repair estimate. |
| `update_deal_pricing_v1(p_deal_id uuid, p_fields jsonb)` | Append-only merge into `deal_inputs` assumptions; **`mao` derived server-side** (10.11A9 — §59, §61); new row + `deals.assumptions_snapshot_id` update. |
| `advance_deal_stage_v1(p_deal_id uuid, p_action text)` | Allowed forward transitions only; invalid transitions → `CONFLICT`. **10.11A10:** successful transition appends **`stage_change`** to **`deal_activity_log`**; requires tenant + user JWT context (**§62**). |
| `mark_deal_dead_v1(p_deal_id uuid, p_dead_reason text)` | Sets stage `dead`; empty reason → `VALIDATION_ERROR`. |
| `handoff_to_dispo_v1` / `handoff_to_tc_v1` | Stage handoffs with assignee; wrong stage → `CONFLICT`. **`handoff_to_dispo_v1` (10.11A10):** successful path appends **`handoff`** to **`deal_activity_log`**; requires tenant + user JWT context (**§62**). |
| `return_to_acq_v1` / `return_to_dispo_v1` | Reverse handoffs (`dispo`→`under_contract`, `tc`→`dispo`). |
| `list_deal_media_v1` / `register_deal_media_v1` / `delete_deal_media_v1` | Deal photo metadata lifecycle. |
| `create_deal_note_v1` / `list_deal_notes_v1` / `list_deal_activity_v1` | User notes/call logs and read-only deal activity timeline (10.11A1 — §56). |

**§RPC reference:** Detailed error codes and behaviors for registry/CI are summarized in `docs/truth/rpc_contract_registry.json` under `build_route_owner` **10.11A** (and **10.11A1** for notes/activity — §56; **10.11A4** for `get_acq_kpis_v1` date-range signature; **10.11A8** for `update_deal_properties_v1` — §58, §60; **10.11A9** for `update_deal_pricing_v1` — §59, §61; **10.11A10** for `advance_deal_stage_v1`, `handoff_to_dispo_v1`, and **`complete_reminder_v1`** `deal_activity_log` writes — §62).

---

## 56) Acquisition deal notes and activity log (10.11A1)

**Authority:** migration `20260420000001_10_11A1_deal_notes_activity_log.sql`.

**Stream separation:** User-visible notes and call logs are stored only in **`deal_notes`**. Automated/system events (for example stage transitions logged by other RPCs) are stored only in **`deal_activity_log`**. Both tables use standard tenant RLS; `anon`/`authenticated` have no direct table privileges — use the RPCs below.

### Tables (summary)

| Table | Role |
|-----|------|
| `deal_notes` | `note_type` check: `note` \| `call_log`; `content` text; `created_by` required; `updated_at` maintained. Append-only from the product surface (no row edit RPC). |
| `deal_activity_log` | `activity_type`, `content`, optional `created_by`; append-only audit stream per deal. |

### RPCs

**§RPC `create_deal_note_v1(p_deal_id uuid, p_note_type text, p_content text)`** — SECURITY DEFINER. Inserts one row into `deal_notes` for the deal resolved in the current tenant. Calls `check_workspace_write_allowed_v1()` before write (§17A). Missing tenant/user JWT context → `NOT_AUTHORIZED`. Workspace not writable → `WORKSPACE_NOT_WRITABLE`. Null `p_deal_id`, invalid `p_note_type`, or blank `p_content` → `VALIDATION_ERROR`. Deal missing or not in tenant → `NOT_FOUND`. Success envelope: `data.note_id`.

**§RPC `list_deal_notes_v1(p_deal_id uuid)`** — SECURITY DEFINER, **STABLE**. Returns `data.notes` (JSON array, newest first) with note fields and `created_by_name` (from `user_profiles.display_name`, empty string if absent). Deal guards match `create_deal_note_v1` (`NOT_AUTHORIZED`, `VALIDATION_ERROR`, `NOT_FOUND`).

**§RPC `list_deal_activity_v1(p_deal_id uuid)`** — SECURITY DEFINER, **STABLE**. Returns `data.activity` (JSON array, newest first) from `deal_activity_log` with activity fields and `created_by_name`. Same deal validation and error set as `list_deal_notes_v1`.

**§Registry:** `docs/truth/rpc_contract_registry.json` — `build_route_owner` **10.11A1**.

---

## 57) Deal edit write paths — jsonb field patches (10.11A2)

**Authority:** migration `20260422000001_10_11A2_deal_edit_write_paths.sql`.

### Shared rules (both RPCs)

- **SECURITY DEFINER**, **GRANT EXECUTE** to **`authenticated` only** (no `anon`). Standard JSON RPC envelope.
- **Tenant** from `current_tenant_id()`. **Workspace write lock:** `check_workspace_write_allowed_v1()` before any write (§17A). Failure → `NOT_AUTHORIZED` (read-only workspace messaging) or `WORKSPACE_NOT_WRITABLE` where the implementation distinguishes locked workspace from other auth failures; align with `create_deal_note_v1` (§56).
- **`p_fields`:** must be a **JSON object** with **only** the allowed keys for that RPC. **Omitted key** → no change to that column. **Explicit JSON `null`** for a present key → clear nullable column. **Value equals current DB value** for a column being written → **`VALIDATION_ERROR`** (no-op updates rejected). **Empty object `{}`**, **non-object** `p_fields`, or **any unknown key** → **`VALIDATION_ERROR`**. **`next_action_due`**, where applicable, must parse as **timestamptz**; invalid values → **`VALIDATION_ERROR`**.
- **Deal must exist** in the current tenant; otherwise → **`NOT_FOUND`**.

### §RPC `update_deal_seller_v1(p_deal_id uuid, p_fields jsonb)`

Writes seller-related columns on **`public.deals`**. Allowed keys: **`seller_name`**, **`seller_phone`**, **`seller_email`**, **`seller_pain`**, **`seller_timeline`**, **`seller_notes`** (all optional; omit-unchanged / null-clear / same-value error per shared rules).

### §RPC `update_deal_property_v1(p_deal_id uuid, p_fields jsonb)`

Writes **`address`**, **`next_action`**, and **`next_action_due`** on **`public.deals`**. Validate **`next_action_due`** as **timestamptz** when the key is present. Same field contract as `update_deal_seller_v1` for merge semantics and validation.

**§Registry:** `docs/truth/rpc_contract_registry.json` — `build_route_owner` **10.11A2**.

---

## 58) Deal properties write path — jsonb patch on `deal_properties` (10.11A6)

**Authority:** migration `20260426000001_10_11A6_deal_properties_write_path.sql`. **`repair_estimate` key contract corrected in 10.11A8** — migration `20260428000002_10_11A8_repair_estimate_cleanup.sql` (see §60).

### §RPC `update_deal_properties_v1(p_deal_id uuid, p_fields jsonb)`

- **SECURITY DEFINER**; **GRANT EXECUTE** to **`authenticated` only** (no `anon`). Standard JSON RPC envelope. **Tenant** from `current_tenant_id()` and **`auth.uid()`**; missing context → **`NOT_AUTHORIZED`** (aligned with §57 jsonb patch RPCs).
- **Workspace write lock:** `check_workspace_write_allowed_v1()` before any write (§17A); failure → `WORKSPACE_NOT_WRITABLE` or `NOT_AUTHORIZED` per implementation alignment with other Acquisition mutators.
- **Scope:** writes **`public.deal_properties` only**. Does **not** read or write **`deal_inputs`**, assumptions, or pricing snapshots.
- **Row existence:** the deal must exist in the current tenant **and** a **`deal_properties`** row must already exist for that `deal_id`; otherwise → **`NOT_FOUND`** (no auto-create in this RPC).
- **Allowed keys in `p_fields`:** `property_type`, `beds`, `baths`, `sqft`, `lot_size`, `year_built`, `occupancy`, `deficiency_tags`, `condition_notes`, `garage_parking`, `basement_type`, `foundation_type`, `roof_age`, `furnace_age`, `ac_age`, `heating_type`, `cooling_type`.
- **`repair_estimate`:** removed from allowed keys in **10.11A8** — repair estimate is owned exclusively by **`update_deal_pricing_v1`** via **`deal_inputs.assumptions`** (§59). The **`deal_properties.repair_estimate`** column may still exist for reads/back-compat; the Acquisition write flow no longer patches it through this RPC.
- **`beds`, `baths`, `sqft`, `garage_parking`:** stored as **text** (10.11A5); v1 allows shorthand display/input values such as **`3+1`**, **`2+1`**, **`2400/1200`**.
- **`deficiency_tags`:** **explicit JSON `null`** → clear; **JSON array of strings** → valid; **any other JSON shape** → **`VALIDATION_ERROR`**.
- **Typed fields** **`year_built`**, **`roof_age`**, **`furnace_age`**, **`ac_age`:** validated to safe scalar types; bad values → **`VALIDATION_ERROR`** (no raw database errors surfaced).
- **Patch semantics** (same contract as **`update_deal_seller_v1`**, §57): **`p_fields`** must be a **non-empty JSON object**. **Omitted key** → no change. **Explicit `null`** on a present key → clear where the column is nullable. **Value equals current** (for columns being updated) → **`VALIDATION_ERROR`**. **Empty object**, **non-object** `p_fields`, or **unknown key** → **`VALIDATION_ERROR`**.

**§Registry:** `docs/truth/rpc_contract_registry.json` — `build_route_owner` **10.11A8** (corrective to **10.11A6**).

---

## 59) Deal pricing write path — append-only `deal_inputs` (10.11A7, corrective 10.11A9)

**Authority:** migration `20260427000001_10_11A7_deal_pricing_write_path.sql`; pricing contract correction `20260428000003_10_11A9_pricing_contract_correction.sql` (§61).

### §RPC `update_deal_pricing_v1(p_deal_id uuid, p_fields jsonb)`

- **SECURITY DEFINER**; **GRANT EXECUTE** to **`authenticated` only** (no `anon`). Standard JSON RPC envelope. **Tenant** from `current_tenant_id()` and **`auth.uid()`**; missing context → **`NOT_AUTHORIZED`**.
- **Workspace write lock:** `check_workspace_write_allowed_v1()` before any write (§17A); failure → **`WORKSPACE_NOT_WRITABLE`** (or aligned `NOT_AUTHORIZED` where the implementation matches other Acquisition mutators).
- **Write scope:** **`public.deal_inputs` only**, and only by **inserting a new row** — never updates an existing `deal_inputs` row in place. Also updates **`deals.assumptions_snapshot_id`** to the new row and increments **`deals.row_version`** on success.
- **Base snapshot:** Uses the **latest** `deal_inputs` row for the deal in the current tenant (`ORDER BY created_at DESC, id DESC`). **No row** → **`NOT_FOUND`** (no auto-create). Deal missing or wrong tenant → **`NOT_FOUND`**.
- **Editable keys in `p_fields`:** **`arv`**, **`ask_price`**, **`repair_estimate`**, **`assignment_fee`**, **`multiplier`** — **numeric** when a non-null value is supplied; invalid numbers → **`VALIDATION_ERROR`**. **`mao`** is **not** an input key — it is **derived server-side** after merge. Caller-supplied **`mao`** in **`p_fields`** → **`VALIDATION_ERROR`**.
- **Derived `mao`:** After patch merge onto the base snapshot, **`mao`** is computed and stored as **`(arv * multiplier) - repair_estimate - assignment_fee`** ( **`assignment_fee`** treated as **0** when absent after merge). If **`arv`**, **`repair_estimate`**, or **`multiplier`** is missing after merge (e.g. cleared with explicit JSON **`null`**), **`mao`** is **omitted** from the new assumptions snapshot (stale **`mao`** is not carried forward in that case).
- **Merge semantics:** **`p_fields`** must be a **non-empty JSON object**. **Omitted key** → value **carried forward** from the base snapshot’s `assumptions`. **Explicit JSON `null`** for a present key → **remove that key** from the merged assumptions (key absent in stored JSON — not stored as JSON null). **Unknown key**, **empty `{}`**, or **non-object** `p_fields` → **`VALIDATION_ERROR`**.
- **No-op:** If the merged snapshot (including derived **`mao`**) is **identical** to the base snapshot → **`VALIDATION_ERROR`** (same-value submission rejected).

**§Registry:** `docs/truth/rpc_contract_registry.json` — `build_route_owner` **10.11A9** (corrective to **10.11A7**).

---

## 60) Repair estimate source-of-truth cleanup (10.11A8)

**Authority:** migration `20260428000002_10_11A8_repair_estimate_cleanup.sql`.

**Purpose:** Establish a single write path for repair-estimate values used in Acquisition pricing: **`deal_inputs.assumptions`** via **`update_deal_pricing_v1`** (§59). **`update_deal_properties_v1`** (§58) no longer accepts **`repair_estimate`** in **`p_fields`**; callers must use **`update_deal_pricing_v1`** for repair estimate updates.

**Schema note:** **`public.deal_properties.repair_estimate`** may remain as a column for legacy reads or non-ACQ flows; **Acquisition** product writes no longer persist repair estimate through **`update_deal_properties_v1`**.

**Relationship:** Corrective to **10.11A6** (`deal_properties` jsonb patch RPC); aligns contract with **`update_deal_pricing_v1`** (**10.11A7**) as the owner of **`repair_estimate`** in **`deal_inputs`**.

**§Registry:** `docs/truth/rpc_contract_registry.json` — `update_deal_properties_v1` **`build_route_owner`** **10.11A8**.

---

## 61) Pricing contract correction — assignment fee editable, MAO derived (10.11A9)

**Authority:** migration `20260428000003_10_11A9_pricing_contract_correction.sql`.

**Purpose:** Correct the Acquisition **`update_deal_pricing_v1`** contract introduced in **10.11A7**: **`assignment_fee`** is an editable assumption; **`mao`** is **not** client-writable and is **recomputed** on each append-only snapshot using **`mao = (arv * multiplier) - repair_estimate - assignment_fee`** (with **`assignment_fee`** as **0** when not present after merge). If any of **`arv`**, **`repair_estimate`**, or **`multiplier`** is missing after merge, **`mao`** is **cleared** from the stored assumptions on the new row.

**Relationship:** Corrective to **10.11A7**; **`build_route_owner`** for **`update_deal_pricing_v1`** is **10.11A9** in `docs/truth/rpc_contract_registry.json`. **`repair_estimate`** ownership via **`update_deal_pricing_v1`** (§60) is unchanged.

**§Registry:** `docs/truth/rpc_contract_registry.json` — **`update_deal_pricing_v1`** **10.11A9**.

---

## 62) Acquisition backend — activity log expansion (10.11A10)

**Authority:** migration `20260430000001_10_11A10_activity_log_expansion.sql`.

**Purpose:** Extend **system-events-only** **`deal_activity_log`** coverage so selected workflow RPCs persist auditable timeline rows while preserving stream separation from user-authored **`deal_notes`** (§56).

### `advance_deal_stage_v1`

- After a successful valid stage transition, the implementation writes one **`deal_activity_log`** row with **`activity_type`** **`stage_change`** (details in migration / implementation).
- **Tenant + user context:** **`current_tenant_id()`** and **`auth.uid()`** must both be non-NULL; otherwise **`NOT_AUTHORIZED`**. Existing transition validation, workspace write lock, and error codes (**`VALIDATION_ERROR`**, **`CONFLICT`**, **`NOT_FOUND`**) are unchanged aside from context checks.

### `handoff_to_dispo_v1`

- After a successful **`under_contract` → `dispo`** handoff (including assignee update), writes one **`deal_activity_log`** row with **`activity_type`** **`handoff`**.
- Same **tenant + user context** requirement as **`advance_deal_stage_v1`**; missing context → **`NOT_AUTHORIZED`**.

### `complete_reminder_v1`

- On **first** completion (`completed_at` transition from unset to set): writes one **`deal_activity_log`** row on the linked deal with **`activity_type`** **`reminder_completed`**.
- **Repeat completion** (already completed reminder): returns **`ok: true`** with no state change — **silent no-op**, **no** additional **`deal_activity_log`** row (idempotent).
- **Tenant + user context:** **`current_tenant_id()`** and **`auth.uid()`** must both be non-NULL; otherwise **`NOT_AUTHORIZED`**.

### Stream separation unchanged

- **`create_deal_note_v1`** continues to append **only** to **`deal_notes`**. It does **not** write to **`deal_activity_log`** — user notes vs system activity streams remain separated (§56).
- **`deal_activity_log`** remains **system-events only** — no user-note duplication through this RPC set.

**§Registry:** `docs/truth/rpc_contract_registry.json` — **`advance_deal_stage_v1`**, **`handoff_to_dispo_v1`**, **`complete_reminder_v1`** **`build_route_owner`** **10.11A10**.

---

## 63) Acquisition Wiring — UI / WeWeb (10.11B)

**Purpose:** Freeze the **Acquisition** page product contract: live WeWeb wiring against **allowlisted RPCs only** — no mocks, no direct tenant tables from the canvas, **no privileged storage path construction**. UI workflow naming and triggers are enumerated in **`docs/ui-workflows/WORKFLOWS.md`**.

**Behavior (product surface):**

- All **Acquisition** workflows are wired to the **governed backend only** (RPC / Supabase-invoked RPC patterns per §17); no supplemental mock datasets for ACQ KPI, list, detail, notes, reminders, activity, or media.
- No **mock KPI**, **mock deal list**, or **mock deal detail** data remains on the Acquisition page; **KPI strip**, **deal list**, and **deal detail** are **live reads** from the governed endpoints.
- All **writes** on the Acquisition surface use **governed RPCs only** (stage, seller/property edits, reminders, notes, media registration, handoff, dead, pricing/properties paths as routed in the UI registry).
- **Quick contact actions:** Call, Email (**Text deferred from v1**); wired with native **`tel:`** / **`mailto:`** links per **`docs/ui-workflows/WORKFLOWS.md`**.

**Deal photos / media:**

- Upload is implemented in **WeWeb** using the **storage upload API** followed by **`register_deal_media_v1`** (`p_deal_id`, `p_storage_path`, `p_sort_order`) — **not** via a bespoke Edge upload handoff unless the Build Route explicitly supersedes this item.
- **Multi-file uploads** use the **indexed while-loop pattern** documented in **`docs/ui-workflows/WORKFLOWS.md`** (counter + file array length) so batches work **without embedding raw JavaScript** in the workflow graph.

**Activity log timeline:**

- **Activity log requires 10.11A10 (merged):** The Acquisition activity panel reads **`deal_activity_log`** via **`list_deal_activity_v1`** (wired in **`docs/ui-workflows/WORKFLOWS.md`**); meaningful system-backed rows assume **§62** (**10.11A10** activity log expansion) merged first.

**§Registry:** UI truth — **`docs/ui-workflows/WORKFLOWS.md`**; RPC truth — **`docs/truth/rpc_contract_registry.json`** (Build Route backend owners unchanged by this subsection).

---

## 64) Intake Backend — Submission Persistence (10.12A)

**Authority:** migration **`20260503000001_10_12A_intake_submission_persistence.sql`**.

**Purpose:** Authoritative persistence for public intake submissions under tenant context, governed list surfaces for Lead Intake / buyer ops, and **no direct `anon` / `authenticated` access** to the new product tables (EXECUTE on `SECURITY DEFINER` RPCs only).

### Tables (schema `public`)

#### `intake_submissions`

| Column | Type | Notes |
|--------|------|--------|
| `id` | uuid | PK, default `gen_random_uuid()` |
| `tenant_id` | uuid | NOT NULL, FK → `tenants(id)` |
| `form_type` | text | NOT NULL, CHECK ∈ `seller`, `buyer`, `birddog` |
| `payload` | jsonb | NOT NULL, default `{}` |
| `source` | text | NOT NULL, default `web` |
| `submitted_at` | timestamptz | NOT NULL, default `now()` |
| `reviewed_at` | timestamptz | nullable |
| `created_at` | timestamptz | NOT NULL, default `now()` |

- **RLS:** enabled. Policy **tenant isolation** using `current_tenant_id()` (no elevated bypass for app roles).
- **Grants:** `REVOKE ALL` from `anon`, `authenticated`.

#### `intake_buyers`

| Column | Type | Notes |
|--------|------|--------|
| `id` | uuid | PK, default `gen_random_uuid()` |
| `tenant_id` | uuid | NOT NULL, FK → `tenants(id)` |
| `name` | text | nullable |
| `email` | text | nullable |
| `phone` | text | nullable |
| `areas_of_interest` | text | nullable |
| `budget_range` | text | nullable |
| `deal_type_tags` | text[] | nullable |
| `price_range_notes` | text | nullable |
| `notes` | text | nullable |
| `is_active` | boolean | NOT NULL, default `true` |
| `created_at` | timestamptz | NOT NULL, default `now()` |
| `updated_at` | timestamptz | NOT NULL, default `now()` |

- **RLS / grants:** same posture as `intake_submissions`.

### `submit_form_v1(p_slug text, p_form_type text, p_payload jsonb)` → `jsonb`

- **Implementation:** **DROP + CREATE** in 10.12A (same public signature). **`SECURITY DEFINER`**, **`REVOKE ALL`** from `PUBLIC`; **`GRANT EXECUTE`** to **`anon`** and **`authenticated`** (unchanged surface; see also §17).
- **Writes:** On every successful submission:
  1. Existing behavior preserved: insert into **`draft_deals`** (including seller `asking_price` / `repair_estimate` pre-fill where applicable).
  2. **New:** insert into **`intake_submissions`** (`tenant_id`, `form_type`, `payload`, `source` = `web`).
- **Response (OK):** Includes `data.draft_id` and `data.intake_id`.
- **Errors:** `NOT_FOUND` (slug / validation shape per prior contract), `VALIDATION_ERROR` (form type, payload, spam token, etc.), **`NOT_AUTHORIZED`** when the workspace is not accepting submissions (latest `tenant_subscriptions` row missing, **`canceled`**, or **`current_period_end <= now()`**).

### `list_intake_submissions_v1(p_limit int DEFAULT 25)` → `jsonb`

- **Callable by:** **`authenticated` only** (`REVOKE` from `anon`, `PUBLIC`).
- **Tenant:** `current_tenant_id()`; **`NULL` → `NOT_AUTHORIZED`**.
- **Limits:** `COALESCE(p_limit, 25)`; must satisfy **1 ≤ p_limit ≤ 100** or **`VALIDATION_ERROR`**.
- **OK payload:** `data.items` — JSON array of objects `{ id, form_type, payload, source, submitted_at, reviewed_at }` for the caller tenant, ordered newest first.

### `list_buyers_v1(p_limit int DEFAULT 25)` → `jsonb`

- **Callable by:** **`authenticated` only** — same grant and limit rules as **`list_intake_submissions_v1`**.
- **OK payload:** `data.items` from **`intake_buyers`** (`id`, `name`, `email`, `phone`, `areas_of_interest`, `budget_range`, `deal_type_tags`, `price_range_notes`, `notes`, `is_active`, `created_at`, `updated_at`).

### Direct access invariant

Authenticated clients **must not** read or write **`intake_submissions`** / **`intake_buyers`** via PostgREST table routes; **`42501`** (privilege) is the expected failure mode for direct SQL/table access outside **`SECURITY DEFINER`** RPCs.

**§Registry:** **`docs/truth/rpc_contract_registry.json`** — **`submit_form_v1`**, **`list_intake_submissions_v1`**, **`list_buyers_v1`** `build_route_owner` **10.12A**. **`docs/truth/execute_allowlist.json`**, **`docs/truth/privilege_truth.json`**.
