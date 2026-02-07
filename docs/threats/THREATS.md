# THREATS — Major Risks (Week 5)

This document lists realistic threats to the WeWeb + Supabase (Option 2) system and the controls that mitigate them.
Scope: production-like threat model for RPC-only architecture.

---

## 1) API Keys / Secrets Exposure

### Threat
- `service_role` or other privileged keys are leaked (repo, logs, browser, WeWeb config, CI artifacts).
- Attacker bypasses RLS/privilege firewall using elevated key.

### Impact
- Full data exfiltration, cross-tenant reads/writes, destructive operations.

### Controls (Required)
- **No `service_role` key in WeWeb** (GUARDRAILS).
- Keep secrets out of repo; use provider secret storage.
- CI redaction discipline (never echo env vars).
- Rotate keys on any suspicion; treat as incident.

### Detection / Response
- Incident: “Key exposure” → immediate key rotation + audit + invalidate sessions.

---

## 2) RLS Bypass / Tenant Isolation Failure

### Threat
- Missing/incorrect RLS predicate allows cross-tenant reads/writes.
- “Teleportation” via user-controlled tenant context (e.g., profile field) grants access to non-member tenant.

### Impact
- Cross-tenant data leak or corruption.

### Controls (Required)
- RLS **ON** with default deny for tenant tables.
- Policies use **EXISTS tenant_memberships** directly (no single-variable trust).
- `current_tenant_id()` derived from verified membership (Week 4).
- Core tables unreadable/unwritable directly; all access via allowlisted RPCs.

### Detection / Response
- pgTAP invariants + CI gates catch regressions.
- Incident: revoke execute / disable read RPCs if needed; ship must fail closed.

---

## 3) SECURITY DEFINER RPC Abuse

### Threat
- SD function has unsafe `search_path`, unqualified internal calls, or exposes forbidden columns / `SELECT *`.
- SD function forgets membership enforcement.

### Impact
- Privilege escalation, data exposure.

### Controls (Required)
- Fixed `search_path` excluding user-writable schemas.
- Schema-qualified internal calls.
- CI definer safety audit gates.
- Membership gate and forbidden-column gates.

### Detection / Response
- CI hard blocks merge; emergency response is remove EXECUTE grants (forward-only migration).

---

## 4) Privilege Firewall Regression

### Threat
- Accidentally re-granting table SELECT/WRITE to `anon/authenticated`.
- EXECUTE allowlist expands unintentionally.

### Impact
- Direct table access from clients.

### Controls (Required)
- Explicit REVOKE on core tables.
- EXECUTE revoked by default; allowlist only.
- pgTAP proves firewall invariants.
- Forward-only migrations; no retro-editing old migrations.

---

## 5) Schema Drift / Truth Artifact Desync

### Threat
- `generated/schema.sql` differs between local and CI or isn’t committed after changes.
- Drift hides privilege / RLS changes or blocks releases.

### Impact
- Broken CI, unclear truth, inconsistent deployments.

### Controls (Required)
- CI schema drift gate.
- `handoff` generates truth; `handoff:commit` publishes truth (PR only).
- No hand-editing robot files.

---

## 6) Denial of Service / Resource Exhaustion

### Threat
- Large payloads or unbounded queries in RPCs.
- Abuse of endpoints causing PostgREST/DB saturation.

### Impact
- Outage, slow app, cascading failures.

### Controls (Required)
- Pagination everywhere; hard caps (`limit <= 100` etc).
- Keep RPCs index-friendly; no `SELECT *`.
- Future: rate limiting / budgets (Week 5+).

---

## 7) Dependency / Supply Chain Risk

### Threat
- Malicious or breaking dependency update (Node, Supabase CLI, Actions).

### Impact
- CI compromise, build breaks, unexpected behavior.

### Controls (Required)
- `npm ci` in CI; lockfile discipline.
- Minimal GitHub Actions permissions; pin actions major versions.
- Treat dependency bumps as scoped PRs with full green gates.

---

## 8) Rollback / Release Discipline Failure

### Threat
- No tagged releases; inability to rollback deterministically.
- Hotfixing production without passing gates.

### Impact
- Extended outage, unreproducible production state.

### Controls (Required)
- Annotated tags for releases.
- Fresh-env CI proof; `ship` gate-close discipline.
- Rollback by redeploying last known-good tag.

---
