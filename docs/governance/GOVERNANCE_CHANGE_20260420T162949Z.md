# GOVERNANCE CHANGE — 10.11A1 Acquisition Backend — Notes/Log Write Path and Activity Log Read Path

UTC: 20260420T162949Z

PR HEAD SHA (workspace): 0cff2cce228d5afe23216c7b836818dea9562f36

## What changed

- **Migration:** `supabase/migrations/20260420000001_10_11A1_deal_notes_activity_log.sql`
  - **`public.deal_notes`** — tenant-scoped notes and call logs (`note_type` ∈ `note`, `call_log`); RLS; no direct grants to `anon`/`authenticated`.
  - **`public.deal_activity_log`** — tenant-scoped per-deal activity stream; RLS; same grant posture.
  - **`create_deal_note_v1(uuid, text, text)`** — SECURITY DEFINER; workspace write lock; standard JSON envelope.
  - **`list_deal_notes_v1(uuid)`** — STABLE SECURITY DEFINER; returns `data.notes`.
  - **`list_deal_activity_v1(uuid)`** — STABLE SECURITY DEFINER; returns `data.activity`.
  - **Retrofit:** `mark_deal_dead_v1` extended to append a **`deal_activity_log`** row when a deal is marked dead (existing callers unchanged at the signature level).
- **Tests:** `supabase/tests/10_11A1_deal_notes_activity_log.test.sql`
- **`docs/artifacts/CONTRACTS.md`** — §17 registered RPC table; §17A write-lock list (`create_deal_note_v1`); §55 companion tables + RPC narrative; **§56** authoritative RPC narrative for 10.11A1.
- **`docs/truth/rpc_contract_registry.json`** — entries for the three new RPCs (`build_route_owner` **10.11A1**).
- **`docs/truth/execute_allowlist.json`** — `create_deal_note_v1`, `list_deal_notes_v1`, `list_deal_activity_v1`.
- **`docs/truth/definer_allowlist.json`** — `public.*` allow rows for the three functions; per-RPC `anon_callable: false` metadata entries.
- **`docs/truth/qa_scope_map.json`** — `10.11A1` proof pattern `^docs/proofs/10\.11A1_deal_notes_activity_log_`.
- **`docs/truth/qa_claim.json`** — claimed item `10.11A1`.
- **`scripts/ci_robot_owned_guard.ps1`** — `ExceptionMatch` allow rule for timestamped `10.11A1_deal_notes_activity_log_*.log` proofs.

## Rationale

User-authored notes/call logs and a read path for per-deal activity were missing from the Acquisition backend. `foundation_log_activity_v1` remains a separate foundation write helper; this item adds product-scoped **`deal_notes`** / **`deal_activity_log`** and RPCs aligned with §55–§56.

## Why safe

- Additive schema (new tables) plus new RPCs; one controlled retrofit on **`mark_deal_dead_v1`** to log activity consistently.
- Same tenancy pattern as other Acquisition RPCs: **`current_tenant_id()`**, deal existence checks, **`REVOKE` from `PUBLIC`**, **`GRANT EXECUTE` to `authenticated`** only on the new surface.
- Notes write path participates in expired-workspace write lock (§17A) like other mutating Acquisition RPCs.

## Risk

Low–medium. **`mark_deal_dead_v1`** behavior gains an extra side effect (activity row). Mitigated by transactional function body and pgTAP coverage.

## Rollback

Revert the migration and dependent truth/docs commits. Re-apply prior **`mark_deal_dead_v1`** definition if rolling back only the retrofit is required.
