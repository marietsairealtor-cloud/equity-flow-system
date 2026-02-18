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

---

## 12) Privilege Firewall Contract (Authoritative)

- Core tables (`tenants`, `tenant_memberships`, `tenant_invites`, `deals`, `documents`) **must not have any GRANTs** to `anon` or `authenticated`.
- Privilege truth is defined by the **absence of GRANTs**, not the presence of `REVOKE` lines.
- `user_profiles` is a controlled exception:
  - Allowed: `GRANT SELECT, UPDATE ON public.user_profiles TO authenticated`
  - Forbidden: any GRANT to `anon`, or `GRANT ALL` to any role.
- Privilege enforcement is evaluated on the **final database state** after all migrations.

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
