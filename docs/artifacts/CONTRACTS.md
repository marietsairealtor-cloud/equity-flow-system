# CONTRACTS — Immutable Interfaces (v2)

This is an interface spec.
Do not assume an RPC exists because it is listed here; verify existence in `generated/schema.sql` or `docs/handoff_latest.txt`.


## 1) RPC Envelope (frozen)

All RPCs return exactly:

{
  "ok": true|false,
  "code": "OK" | "VALIDATION_ERROR" | "CONFLICT" | "NOT_AUTHORIZED" | "NOT_FOUND" | "INTERNAL",
  "data": object|null,
  "error": { "message": string, "fields": { [field]: string } } | null
}

Rules:
- `data` is ALWAYS an object. Lists go in `data.items`.
- `code` enum is additive only.

## RPC signature stability (ENFORCED)

- Any change to an RPC’s **parameters or return shape** must use:
  **DROP FUNCTION …; CREATE FUNCTION …**
- `CREATE OR REPLACE FUNCTION` is **forbidden** for signature or return changes.
- Internal logic may change without DROP only if the interface is identical.

Rationale: callers must never observe silent interface drift.


### Tenancy Resolution (LOCKED)

`current_tenant_id()` resolves tenant context in this order:
1) If `user_profiles.current_tenant_id` is non-NULL → return it.
2) Else if `current_setting('app.tenant_id', true)` is a valid UUID → return it (dev/test only).
3) Else if JWT tenant claim is enabled and valid UUID → return it.
4) Else return NULL (RLS denies by design).

Mismatch behavior:
- If both profile tenant and JWT tenant are non-NULL and differ:
  - `current_tenant_id()` returns the profile tenant.
  - `tenant_id_mismatch()` returns true.
  - No exceptions; no logging inside `current_tenant_id()`.



## 2) UI State Contract (minimal globals)

Allowed WeWeb globals:
- gs_selectedTenantId (UI routing cache only; never authorization)
- gs_selectedDealId (UI selection only)
- gs_maoDraft (local draft)
- gs_pendingIdempotencyKey (one per write)

Forbidden:
- new globals without editing this contract.


## 3) Pagination Contract (locked)

### Pagination: rpc.list_deals_v1

Signature: 
pc.list_deals_v1(limit, cursor)
ordering: created_at desc, id desc
limit: default 25, max 100
cursor: opaque string returned by server

Return:
- data: { items: [...], next_cursor: string|null }


`rpc.list_deals_v1(limit, cursor)`:
- ordering: created_at desc, id desc
- limit: default 25, max 100
- cursor: opaque string returned by server

Return:
- `data`: `{ items: [...], next_cursor: string|null }`


## 4) Idempotency Replay Semantics (locked)

For write RPCs:
- first call stores `result_json` and returns it
- replay returns the stored `result_json` verbatim


## 5) Golden Path (business alive)

1) Anonymous: `rpc.calculate_mao_v1` (pure; no writes)
2) Auth: signup/login
3) Upgrade & Save: `rpc.provision_tenant_and_seed_deal_v1` (atomic)
4) Deals list: `rpc.list_deals_v1`
5) Save/update: `rpc.upsert_deal_v1(expected_row_version, ...)`

## 3) Pagination Contract (locked)
Pagination: rpc.list_deals_v1 
rpc.list_deals_v1(limit, cursor) 
order: created_at desc, id desc 
returns: items, next_cursor

## 6) Privilege Contract (ENFORCED)

- Core tables must not be readable by anon or authenticated.
- All reads and writes must occur via allowlisted RPCs.
- Direct SELECT on tenant tables is forbidden.

- Helper functions are internal by default.
- Helpers must not be executable by authenticated.


## 7) SECURITY DEFINER Safety Rules (LOCKED)

All SECURITY DEFINER RPCs must:

- Set a fixed search_path or empty search_path.
- Schema-qualify all object references.
- Enforce tenant membership internally.
- Avoid dynamic SQL.
- Never rely on caller privileges.

Violation of any rule requires a new versioned RPC.


## 8) Helper Function Exposure (LOCKED)

- Internal helpers must not be directly executable by app roles.
- Helpers may be executed only by allowlisted SECURITY DEFINER RPCs.
- Granting EXECUTE to helpers requires contract update.


## 9) Output Restriction Rule

- SECURITY DEFINER read RPCs must return only required columns.
- SELECT * is forbidden.
- No internal identifiers may be exposed.


## 10) Contract Change Policy

- Any change to this file requires:
  - CI green
  - Contract lint passing
  - Version bump if public behavior changes

- Breaking changes require new RPC versions.
- Silent behavior changes are forbidden.

Artifact Contract
On clean main:
npm run ship
→ git status is empty

Publish Contract
No script may commit on main.

CI Contract
All merges require required (pull_request).

Recovery Contract
If main is ahead locally → reset, never push.

### Privilege Firewall Contract (Authoritative)

- Core tables (`tenants`, `tenant_memberships`, `tenant_invites`, `deals`, `documents`) **must not have any GRANTs** to `anon` or `authenticated`.
- Privilege truth is defined by the **absence of GRANTs**, not the presence of `REVOKE` lines.
- `user_profiles` is a controlled exception:
  - Allowed: `GRANT SELECT, UPDATE ON public.user_profiles TO authenticated`
  - Forbidden: any GRANT to `anon`, or `GRANT ALL` to any role.
- Privilege enforcement is evaluated on the **final database state** after all migrations.

## 3.4 — Default privileges lockdown
- Change: Default privileges set to private-by-default for new objects in schema `public`.
- Impact: No RPC/interface/response-shape changes; snapshot drift is expected from privilege metadata only.

- Feb 7, 2026: contracts snapshot regenerated (CI policy sync).
