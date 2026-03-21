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

## 5A) Entitlement RPC Contract (LOCKED)

### rpc.get_user_entitlements_v1

Returns the current user entitlement state for the active tenant context.
Entitlement is derived from tenant_memberships. Membership exists = entitled.

Parameters: none (reads from JWT context: tenant_id, user_id).

Security: SECURITY DEFINER, search_path = public.
GRANT EXECUTE to authenticated only. REVOKE from anon.
Source of truth per GUARDRAILS S17.

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
| create_deal_v1 | 6.6 | Create a new deal with calc_version and assumptions | SECURITY DEFINER, min role: member | current_tenant_id() — no tenant_id param |
| update_deal_v1 | 6.6 | Update existing deal with optimistic concurrency | SECURITY DEFINER, min role: member | current_tenant_id() — no tenant_id param |
| list_deals_v1 | 5A | List deals for current tenant with cursor pagination | SECURITY DEFINER | current_tenant_id() — no tenant_id param |
| get_user_entitlements_v1 | 5A | Return entitlement state for current user and tenant | SECURITY DEFINER | current_tenant_id() — no tenant_id param |
| foundation_log_activity_v1 | 6.10 | Append activity log entry for audit trail | SECURITY DEFINER | current_tenant_id() — no tenant_id param |
| lookup_share_token_v1 | 6.7/8.7/8.10 | Look up share token by token + deal_id scope; logs attempt (best-effort, hash-only). deal_id required (8.10). | SECURITY DEFINER | current_tenant_id() - no tenant_id param |
| revoke_share_token_v1 | 8.6 | Revoke a share token immediately (idempotent) | SECURITY DEFINER | current_tenant_id() — no tenant_id param |
| create_share_token_v1 | 8.8/8.9 | Generate cryptographically secure share token (shr_ prefix, 256-bit entropy, hash-at-rest); expires_at required (8.9) | SECURITY DEFINER | current_tenant_id() — no tenant_id param |
| resolve_form_slug_v1 | 10.8.1 | Resolve tenant slug + form type to tenant context for public intake forms | SECURITY DEFINER, anon-callable (§12 exception) | slug input only — no tenant_id param |
| submit_form_v1 | 10.8.1 | Submit public intake form; creates draft deal with MAO pre-fill for seller submissions | SECURITY DEFINER, anon-callable (§12 exception) | slug input only — no tenant_id param |
| list_reminders_v1 | 10.8.3 | List overdue and upcoming reminders for current tenant | SECURITY DEFINER | current_tenant_id() — no tenant_id param |
| create_reminder_v1 | 10.8.3 | Create a deal reminder for current tenant | SECURITY DEFINER, min role: member | current_tenant_id() — no tenant_id param |
| complete_reminder_v1 | 10.8.3 | Mark a reminder as completed (idempotent) | SECURITY DEFINER, min role: member | current_tenant_id() — no tenant_id param |
| accept_invite_v1 | 10.8.7B | Accept app invite token and create tenant membership | SECURITY DEFINER, authenticated only | token lookup — tenant_id derived from tenant_invites row |
| list_farm_areas_v1 | 10.8.6 | List all farm areas for current tenant | SECURITY DEFINER, min role: admin | current_tenant_id() — no tenant_id param |
| create_farm_area_v1 | 10.8.6 | Create a new farm area for current tenant | SECURITY DEFINER, min role: admin | current_tenant_id() — no tenant_id param |
| delete_farm_area_v1 | 10.8.6 | Delete a farm area for current tenant (SET NULL on deals) | SECURITY DEFINER, min role: admin | current_tenant_id() — no tenant_id param |

### Mapping Rules

- Any PR that adds or modifies a public RPC must update this table in the same PR.
- Internal helpers are excluded from this table but must be listed in docs/truth/definer_allowlist.json if SECURITY DEFINER.
- Gate: rpc-mapping-contract (merge-blocking, policy-coupling style).

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

## 24) Entitlement RPC Extension — Subscription Status (10.8.2)

`get_user_entitlements_v1` return shape extended (Build Route 10.8.2).

New fields in `data`:
- `subscription_status`: `active | expiring | expired | none` — computed server-side from `tenant_subscriptions`. `expiring` when active AND ≤5 days remain. `none` when no subscription record exists.
- `subscription_days_remaining`: integer, null when `subscription_status` is `none`. 0 or negative when expired.

Computation rules:
- Threshold (5 days) lives in RPC only. WeWeb performs zero date math (GUARDRAILS §5).
- `canceled` status or `current_period_end <= now()` → `expired`.
- No subscription record → `none`.

Gate logic derivable from single RPC call:
- No memberships → onboarding Step 1
- Membership + status `none` or `expired` → onboarding Step 3
- Membership + status `active` or `expiring` → hub

Additive change — existing callers unaffected. DROP + CREATE per CONTRACTS §2.

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
