# BUDGETS — Resource Limits (Week 5)

Budgets exist to prevent runaway cost, latency, and instability. Defaults are conservative.

---

## API / RPC Budgets

- Max page size: **100**
- Default page size: **25**
- Max response payload (jsonb): **256 KB** target (keep envelopes small)
- Target P95 RPC latency (local/CI): **< 300ms** for list endpoints on seed-sized data
- No `SELECT *` in SECURITY DEFINER RPCs (CI-gated)

---

## Database Budgets

- Tenant tables require `tenant_id NOT NULL` and indexed access patterns.
- Queries must be index-friendly (filter by `tenant_id`, order by indexed columns).
- No dynamic SQL in migrations.
- SECURITY DEFINER functions must have fixed `search_path` and schema-qualified calls (CI-gated).

---

## CI / Workflow Budgets

- A new developer should be able to run `npm run ship` on a clean checkout in **< 30 minutes** on a normal laptop.
- If `ship` exceeds 30 minutes, treat as Reliability regression; fix by:
  - reducing unnecessary steps
  - caching dependencies
  - removing redundant work
  - splitting heavyweight checks into separate workflows (without weakening required checks)

---

## Local Development Budgets

- `green:twice` loop should complete in **< 15 minutes** after warm caches.
- If Supabase start becomes unreliable, use stop/start (not reset) and file an incident.

---
