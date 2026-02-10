# INCIDENTS

## 2026-01-31 — GitHub/pgTAP style incident
- Symptom: CI risk from pgTAP files using forbidden patterns (psql meta commands or DO blocks).
- Classification: repeatable test-style hazard (Bad plan class).
- Closure: automation guard added (lint:pgtap) wired into green gate + CI.

Date: 2026-01-31 (or today’s date you’re using)
Symptom: CI schema drift only in CI
Classification: determinism/tooling drift
Closure: pinned Supabase CLI in CI to 2.74.5 (guard)

## 2026-01-31 — Repo ruleset + CI deadlock incident

* Symptom: Merge blocked on a PR despite green-looking checks; ruleset showed **“Expected — waiting for status”** for required checks that were already successful.
* Classification: GitHub ruleset required-check reconciliation / naming deadlock (string-exact check names; integration vs GitHub Actions source).
* Closure: Required checks reconfigured to **GitHub Actions** source with exact names; deadlocked PR unblocked by temporary disable → merge → re-enable after fresh green runs on `main`.

## 2026-01-31 — pgTAP “Bad plan” incident

* Symptom: `supabase test db` failed with **Bad plan (planned N ran 0)** / **No plan found**, blocking CI.
* Classification: repeatable test-style hazard (pgTAP harness abort / non-TAP emission).
* Closure: pgTAP tests rewritten to **SQL-only** TAP statements (no `DO` blocks, no psql meta `\` lines), and SQL files normalized to **UTF-8 no BOM + LF**.

## 2026-01-31 — Tenancy helper missing / privilege allowlist drift

* Symptom: `list_deals_v1` crashed in CI/local due to missing `public.current_tenant_id()`; separate allowlist test failed because `authenticated` could EXECUTE it.
* Classification: migration contract gap + privilege firewall drift.
* Closure: forward migrations added to create `current_tenant_id()` and revoke EXECUTE from `authenticated`; schema drift resolved by regenerating and committing truth artifacts (`npm run handoff`).

**Incident Report**

**Date:** Feb 6–8, 2026

**Symptom:**
Repeated CI failures and local/CI mismatch during Week 2 work. Errors included schema drift, SQL parse failures, encoding/BOM corruption, PowerShell/Linux incompatibility, EXECUTE privilege leakage, and inconsistent “green” proofs.

**Classification:**
Systemic tooling + process gaps (not logic bugs). Root causes were missing guards (encoding, `$` quoting), OS-specific assumptions (PowerShell vs `pwsh`), missing lockfile for CI, undocumented deploy foot-guns, and detectors lagging enforcement.

**Closure:**
All failure classes were either prevented or explicitly accepted:

* Added SQL safety lint (no `$$`, no BOM/UTF-16) enforced locally, in green gate, and in CI.
* Normalized LF via `.gitattributes` and added CI guard to prevent drift.
* Added `package-lock.json`; CI now uses `npm ci`.
* Made `lint:sql` cross-platform (Windows + Linux CI).
* Hardened green gate to match CI.
* Implemented privilege firewall and EXECUTE allowlist with tests.
* Added remote deploy guard (`db:push` + `ALLOW_REMOTE=1`).
* Updated docs (GUARDRAILS, CONTRACTS, SOP, AUTOMATION) and regenerated handoff artifacts.
* CI green; `ship` clean.

**Status:** Closed.

**Date:** 2026-01-30

**Symptom:** Local proof gate intermittently failed with Docker errors (`failed to parse template: function "com" not defined`) and brittle cleanup behavior; `supabase db reset` usage caused instability on Windows; docs-only workflow failed due to Git warning handling.

**Classification:** Repeatable automation hazard (Bad plan class: unsafe Docker templating + forbidden reset path + noisy Git stderr).

**Closure:** Replaced Docker label templating with safe `{{.Labels}}` parsing; added project-scoped `docker:clean` preflight and enforced it in green gate; hard-blocked `supabase db reset`; fixed docs-only guard to use porcelain filtering; updated automation to use `docs:push` and preflight cleanup.

## Incident Report

**Date:** 2026-01-31

**Symptom:**
Local Supabase proof gate failed intermittently: `db reset` produced 502 errors on Windows; `supabase start` failed with container name conflicts (e.g., orphaned `supabase_vector_<project>`), leading to missing DB container logs and misleading migration errors (duplicate `schema_migrations` version).

**Classification:**
Environment / tooling failure — local stack instability on Windows caused by stale, project-scoped Docker containers and use of an unsupported proof path (`db reset`).

**Closure:**

* Removed orphaned project-scoped containers causing name conflicts.
* Switched to locked, Windows-safe proof gate: **stop → start (-x vector, --ignore-health-check) → status → lint:migrations → build → handoff**.
* Excluded vector from the gate; accepted restart noise.
* Confirmed migrations were not duplicating versions; error was environmental.
* Proof gate passed deterministically; artifacts generated successfully.

## 2026-01-31 — CI schema drift loop

* Symptom: GitHub Actions fails `ci_schema_drift.ps1` with `SCHEMA DRIFT: generated/schema.sql changed` even after local `handoff` passes; repeated “regen mismatch” cycles during `ship`.
* Classification: deterministic truth-artifact mismatch (Publisher/gate mismatch class) + workflow friction (Bad plan class).
* Closure: restore publisher discipline by using the correct lane: **docs-only commits separate**, **`handoff:commit` for truth-artifact updates**, **`ship` reserved for end-of-session**; enforce normalization by expanding `.gitattributes` to include `.gitattributes` itself and any allowlisted truth paths, and require `git add --renormalize` in the truth commit path.

## 2026-02-05 — CI schema drift + ship/publisher mismatch

* **Symptom:** GitHub Actions failed with `SCHEMA DRIFT: generated/schema.sql changed. Commit updated schema.sql` after “Update handoff snapshot”; local `handoff` regenerated `generated/schema.sql`/`generated/contracts.snapshot.json`, but they weren’t committed, so CI regenerated and detected mismatch.
* **Classification:** Repeatable automation/truth-artifact publishing failure (publisher allowlist incomplete; Win↔CI normalization gap).
* **Closure:** Updated `ship`/handoff workflow to treat truth artifacts as a single committed set (`docs/handoff_latest.txt`, `generated/schema.sql`, `generated/contracts.snapshot.json`), added LF normalization via `.gitattributes` + `git add --renormalize`, and documented “ship is publisher; robot-owned files never hand-edited.”

## 2026-01-29 — Handoff secrets + mojibake + dirty checkpoint incident

* Symptom: `docs/handoff_latest.txt` contained secret keys and inconsistent Supabase status output; docs showed mojibake (`â€”`, garbled quotes); handoff ended with a dirty working tree and untracked fixer scripts.
* Classification: repeatable process hazard (Bad plan class) + security leak risk (Critical hygiene).
* Closure: rewrote handoff to be deterministic + sanitized; aligned `AUTOMATION.md` to implemented vs planned gates; fixed doc encoding; enforced clean handoff checkpoints (`## main`); committed changes and removed temp scripts.

## 2026-02-01 — GitHub Required Checks Deadlock

* **Symptom:** PR showed “Expected — Waiting for status to be reported” for required checks, even though identical checks were green. Merge was blocked indefinitely.
* **Classification:** Tooling deadlock caused by stale/mismatched required check contexts (job/workflow renames + ruleset caching + event mismatch).
* **Root Cause:** Branch rules required multiple job-level contexts whose names/events no longer aligned cleanly with emitted checks. GitHub continued evaluating an older commit context.
* **Closure:** Introduced a single, stable required check (`required (pull_request)`), updated ruleset to require only that check, retriggered CI, updated PR branch from `main`, and merged with a merge commit.
* **Prevention:** Use one invariant “gate” check only; treat check names as contracts; avoid renames; if merge queue is enabled, ensure contexts exist for its event or disable it.

ID: 2026-02-01-ship-handoff-loop

Summary:
Ship pipeline violated PR-only main rule by auto-committing and regenerating nondeterministic handoff artifacts.

Impact:
Blocked releases; repeated manual recovery.

Root Causes:

Mixed publish/verify roles

Volatile handoff file

Hidden mutation path via green gate

Fix:
Separated handoff / publish / ship lanes.

Prevention:
Janitor-proof branching + no-write ship.

## 2026-02-02 — Schema Drift & Privilege Firewall Incident

- Symptom: CI failed schema drift checks due to privilege differences in `generated/schema.sql`.
- Root Cause:
  - Dynamic `DO/EXECUTE` migration caused non-deterministic privilege state.
  - `user_profiles` received unintended `GRANT ALL` to `anon/authenticated`.
- Classification: repeatable CI drift + privilege firewall violation.
- Closure:
  - Replaced dynamic migration with forward-only deterministic migrations.
  - Enforced `user_profiles` privileges explicitly.
  - Updated firewall detection to rely on absence of GRANTs.
  - Published corrected truth artifacts via dedicated artifacts PR.

## 2026-02-03 — Encoding guard caught BOM in new pgTAP test
- Symptom: New pgTAP test file failed encoding preflight with BOM (blocked commit).
- Classification: repeatable Windows/editor encoding hazard (Bad plan class).
- Closure: ran `npm run fix:encoding`, re-committed; policy remains “UTF-8 no BOM” and encoding preflight blocks merges.

## 2026-02-03 — pgTAP `is()` type mismatch caused “Bad plan” (0 tests executed)
- Symptom: `is(bigint, integer, ...) does not exist` → planned 1, ran 0, test file failed.
- Classification: deterministic test authoring error (Bad plan class).
- Closure: cast expected value to `0::bigint`; `npx supabase test db` passes thereafter.

CI delay likely external: GitHub Actions had a degraded-performance incident Feb 2–3, 2026.
The official status page shows an Incident with Actions that included “Actions is experiencing degraded performance” (Feb 2, 2026) and later “Actions is operating normally” (Feb 3, 2026).

## 2026-02-24 — Teleportation negative proof
- Symptom: Risk that forged tenant context (`app.tenant_id` or `user_profiles.current_tenant_id`) could read protected rows from a non-member tenant via SECURITY DEFINER read RPCs.
- Classification: privilege/tenant-context bypass risk (negative proof required).
- Closure: Added pgTAP `083_teleportation_negative_proof.sql` covering both vectors against `public.list_deals_v1`; CI-gated.

2026-02-25 — CI schema drift after artifacts update

Symptom: GitHub Actions ci_schema_drift.ps1 failed; CI-regenerated generated/schema.sql differed from the committed artifact, missing Feb 25 RLS changes (FORCE ROW LEVEL SECURITY / CREATE POLICY).

Classification: Publisher lane ordering error (truth artifacts generated against a different DB state than CI rebuild).

Root cause: Truth artifacts PR was created/merged out of sequence relative to the Feb 25 migration PR.

Closure: Merged Feb 25 migration first; on main reran npm run handoff → npm run handoff:commit; merged updated artifacts PR; CI green; npm run ship passed on main (HEAD b7b3214).

## 2026-03-07 — PostgREST schema cache stale (reload required)
Date: 2026-03-07
Symptom: WeWeb/PostgREST responses don’t reflect newly deployed migrations; functions/columns appear missing until a restart.
Classification: Reliability — PostgREST cache/reload
Closure: Deploy triggers `NOTIFY pgrst, 'reload schema'` via migration `20260307100000_102_postgrest_reload_notify.sql`. If already deployed and stale:
- Run: `NOTIFY pgrst, 'reload schema';`
- If still stale: restart PostgREST/Supabase services.
Prevention: Keep NOTIFY-on-deploy migration in place; do not rely on manual Studio reload.
Proof (repo): migration `supabase/migrations/20260307100000_102_postgrest_reload_notify.sql` contains `notify pgrst, 'reload schema';`.

## 2026-02-04
* merge-conflict markers existed on `main` (`docs/artifacts/SOP_WORKFLOW.md`)
* proof workflow initially targeted `logs/**` but `logs/**` is **blocked/ignored**
* BOM/CRLF issues triggered encoding gate
## 2026-02-04
Symptom: Merge-conflict markers appeared on `main` in `docs/artifacts/SOP_WORKFLOW.md`; proof attempt targeted `logs/**` which is blocked; encoding gate failures due to BOM/CRLF.
Classification: Process / Governance drift.
Closure: Resolved merge conflict; moved proof artifacts to `docs/proofs/`; ran `npm run fix:encoding`; enforced clean-tree + handoff discipline.
Prevention: Proofs only under `docs/proofs/`; run encoding preflight before committing any new proof; keep PR-only governance for doc changes.

## Incident: package.json BOM broke tooling (Husky init)

### Symptom
`npx husky init` failed with JSON.parse errors even though package.json looked valid.

### Root Cause
`package.json` contained a UTF-8 BOM (`EF BB BF`). Some tooling treated the BOM as an illegal character before `{`, causing parse failure.

### Fix
Rewrote `package.json` as UTF-8 without BOM (content unchanged). Tooling succeeded immediately afterward.

### Prevention
- Guardrail: `package.json` must be UTF-8 without BOM.
- Pre-commit gate added for SQL safety (Husky + lint-staged).
- Use encoding fix workflow when any file behaves “valid but won’t parse.”

## Incident: UTF-8 BOM in package.json broke tooling (Husky init)

### Symptom
`npx husky init` failed with a JSON.parse error even though `package.json` looked valid.

### Root Cause
`package.json` contained a UTF-8 BOM (`EF BB BF`). Some tooling treated the BOM as an illegal character before `{`, causing parse failure.

### Fix
Rewrote `package.json` as UTF-8 without BOM (content unchanged). Husky init succeeded immediately afterward.

### Prevention
- Guardrail added: repo text files must be UTF-8 without BOM.
- Commit-time BOM gate added (Husky + lint-staged): blocks BOM in staged `**/*.{json,md,yml,yaml,js,mjs,ts,tsx,sql,ps1}` by running `node scripts/lint_bom_gate.mjs`.
- Existing encoding repair: use `npm run fix:encoding` when file encoding/line endings cause inconsistent tool behavior.

### 2026-02-08 — Renormalize gate state drift + path mismatch (Windows)

Symptom: npm run renormalize:check failed with Missing script: "renormalize:check" and/or fatal: pathspec 'scripts/check_renormalize.mjs' did not match any files, blocking the renormalize-enforced gate.

Classification: determinism/state-drift incident (shell context drift + unpersisted wiring) + gate path mismatch.

Closure: Proved repo truth (ls scripts + git ls-files), created scripts/check_renormalize.mjs at the referenced path, added renormalize:check to package.json, committed, reran gate → RENORMALIZE_ENFORCED_OK.

Status: Closed. 


## 2026-02-09 — Proof manifest self-entry + Windows path normalization

* Symptom: 
pm run proof:manifest failed (missing entries / self-entry / hash mismatch) due to Windows path separators and manifest including itself.
* Classification: determinism / chain-of-custody drift (proof manifest non-canonicalization).
* Closure: enforce POSIX-style keys in manifest, hard-forbid self-entry, regenerate manifest after proof additions/merges; gate now hard-fails on violations.
* Status: Closed.

## 2026-02-09 — Gitleaks Action org license break
- Symptom: CI secrets-scan failed: gitleaks-action@v2 required org license key.
- Classification: external dependency / CI gate break.
- Closure: replaced action with Docker-based gitleaks in secrets-scan workflow; proof logs committed; required check context pinned.


## 2026-02-09 — Stop-the-line coupling introduced
- Policy change: certain CI failures now require explicit acknowledgment (INCIDENT or one-PR waiver).
- Enforced by merge-blocking gate: stop-the-line.


## 2026-02-10 — Prevented: Governance drift via docs-only PR
- Symptom: Governance-affecting change could be classified as docs-only.
- Risk: CI lane bypass / unreviewed governance drift.
- Fix: 2.15 governance-change-guard + docs-only override.
- Proof: docs/proofs/2.15_governance_change_20260210_001959Z.log
- PR: #25
- Status: Closed

## 2026-02-10 — 2.16.1 proof treadmill (HEAD semantics + Windows session/token drift)

Symptom
- Repeated QA FAIL for 2.16.1 due to `HEAD=` mismatch vs PR tip after committing proof.
- Intermittent empty/malformed proof logs during capture.
- Local runs alternated between success and `Missing GH_TOKEN/GITHUB_TOKEN` / `401 Bad credentials`.

Root Causes
- Proof contract ambiguity: `HEAD` interpreted as PR tip vs tested commit.
- Windows shell/session drift: token present in one shell/session but not another.
- Git Bash redirection instability in this environment (proof capture produced `stdout is not a tty` / non-zero exit in some runs).
- Superseded proof artifacts accumulated before final proof was committed.

Resolution
- Clarified proof contract (QA-approved): `HEAD` denotes the commit that was tested.
- QA acceptance: `HEAD` must be an ancestor of merge commit; diff after `HEAD` must be proof-only (`docs/proofs/**`).
- Generated final proof using PowerShell (UTF-8 no BOM), committed once, merged.

Prevention
- Operator rule (Windows): generate and write proof logs via PowerShell; verify token presence (LEN + SHA256_8) in the same session that runs the attestation.
- Always delete superseded proof logs before generating the final proof artifact.

Status
Closed.


### Post-Mortem — 2.16.1 Proof Treadmill (Expanded)

**What actually failed**
- The system did not fail governance checks.
- The failure mode was **proof binding semantics under Windows execution**, compounded by shell/session drift.

**Why it escaped initially**
- `HEAD` was underspecified (tested commit vs. proof container commit).
- Windows allowed tokens to exist in one shell but not another without obvious failure.
- Git Bash redirection intermittently corrupted or truncated proof logs.

**What fixed it**
- Contract clarified: `HEAD` = **tested commit**.
- QA acceptance tightened: ancestry + proof-only diff.
- Proof generation moved to PowerShell (UTF-8 no BOM).
- Superseded proof artifacts explicitly removed before final proof.

**Why this is now safe**
- Ancestry check prevents false binding.
- Proof-only diff constraint prevents silent semantic drift.
- Token presence verified via non-secret signals before execution.

**Residual risk**
- Windows shell/session inconsistency remains a human-ops risk.
- Mitigated by SOP, not automation.

**Classification**
- Tooling / process boundary failure (non-logic).

**Status**
- Closed. Prevented by SOP + clarified contract.


## 2026-02-10 — proof-commit-binding false-fail on no-proof PRs
Objective
- Prevent merge-blocking CI / proof-commit-binding from deadlocking PRs that do not touch docs/proofs/**
Changes
- Gate now exits 0 with PROOF_COMMIT_BINDING_SKIP when no proof files changed in the PR
Proof (filenames)
- N/A (behavior change; validated by CI green on docs-only PR)
PR/CI
- CI / proof-commit-binding no longer blocks docs-only PRs without proof deltas
DoD
- Docs-only PR merges without adding docs/proofs/** artifacts; gate reports SKIP and passes
Status
- CLOSED

