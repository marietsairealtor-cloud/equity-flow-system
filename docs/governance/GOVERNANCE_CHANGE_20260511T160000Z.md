# GOVERNANCE CHANGE — Build Route 10.12C8 mark_submission_reviewed_v1 draft id

UTC: 20260511T160000Z

## What changed

- **`supabase/migrations/20260511000001_10_12C8_mark_submission_reviewed_draft_id.sql`** — **`DROP FUNCTION`** legacy **`(uuid, text)`**; canonical **`mark_submission_reviewed_v1(p_outcome text, p_submission_id uuid DEFAULT NULL, p_draft_id uuid DEFAULT NULL)`** (PL/pgSQL); **`LANGUAGE plpgsql`** legacy overload **`(p_submission_id uuid, p_outcome text)`** with **`PERFORM public.current_tenant_id()`** then delegate to canonical (**definer-safety-audit**); **`GRANT EXECUTE`** on both overloads to **`authenticated`**; tenant-scoped row fetch **`id AND tenant_id`**.
- **`supabase/migrations/20260512000001_10_12C8_legacy_wrapper_definer_audit.sql`** — idempotent **`CREATE OR REPLACE`** of the legacy overload for databases that applied an earlier revision of **`20260511000001`** using a SQL-only wrapper (no **`current_tenant_id()`** in **prosrc**).
- **`supabase/tests/10_12C8_mark_submission_reviewed_draft_id.test.sql`** — pgTAP: draft dismiss, legacy path, neither-id validation, cross-tenant draft, submission-wins, workspace lock, auth envelope, canonical **`EXECUTE`** posture.
- **`docs/artifacts/CONTRACTS.md`** — §17 **`mark_submission_reviewed_v1`** row; §64 authority chain + full **`mark_submission_reviewed_v1`** contract (canonical + legacy + **`p_draft_id`** rules); §Registry line **10.12C8**.
- **`docs/truth/rpc_contract_registry.json`** — **`mark_submission_reviewed_v1`** **`input_contract`** and **`notes`** for **10.12C8** overloads and resolution semantics.
- **`docs/truth/privilege_truth.json`** — **`routine_grants.authenticated`** **`mark_submission_reviewed_v1`** authority **10.12C4 + 10.12C8**.
- **`docs/truth/qa_claim.json`** — active item **`10.12C8`**.
- **`docs/truth/qa_scope_map.json`** — **`10.12C8`** title + proof pattern **`^docs/proofs/10\.12C8_mark_submission_reviewed_draft_id_`**.
- **`docs/truth/cloud_migration_parity.json`** — migration tip **`20260512000001`**; **`migration_count`** includes **10.12C8** chain.
- **`scripts/ci_robot_owned_guard.ps1`** — canonical proof log allowlist pattern for **10.12C8**.

## Alignment

- **Build Route `10.12C8`** (merge-blocking; prerequisite **`10.12C4`**). Proof path: **`docs/proofs/10.12C8_mark_submission_reviewed_draft_id_<UTC>.log`** (Phase 4 per **SOP_WORKFLOW.md**).
- **Phase 1** (SOP): migrations, tests, **CONTRACTS.md**, governance file, truth registries (**rpc_contract_registry**, **privilege_truth**, **qa_***, **cloud_migration_parity**, robot guard). **Phase 2+**: **`npm run handoff`**, **`handoff_latest.txt`**, **`generated/schema.sql`**, proof finalize (not in this change set unless run separately).

## Why safe

- Same SECURITY DEFINER + member + workspace gate + outcome allowlist as **10.12C4**; draft resolution is **tenant-bound**; cross-tenant and unknown draft return **`NOT_FOUND`**; legacy overload preserves positional **`(submission_id, outcome)`** callers.

## Risk

- Low. New optional identifier path only; breaking change avoided via forwarder overload.

## Rollback

- Revert migrations **20260512000001** and **20260511000001** and related test/truth/doc updates; restore prior **`mark_submission_reviewed_v1(uuid, text)`** from **20260507000001** if re-applying piecemeal.
