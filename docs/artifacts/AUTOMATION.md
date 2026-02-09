# AUTOMATION — Robot Gates (v4)

## Purpose

Define **what automation may do and may not do**, mechanically.

This document is a **scripts contract**.
If a script violates this contract, the script is wrong — not the SOP, not the user.

---

## Core Principle (LOCKED)

**Proof ≠ Publish ≠ Release**

Automation responsibilities are permanently separated:

* **Generate truth** → `handoff`
* **Publish truth (PR lane)** → `handoff:commit`
* **Verify only** → `ship`
* **Gate checks** → `green:*`

Any script that mixes these roles is **invalid by definition**.

---

## Command Contract (Scripts Contract)

| Command          | May Write | May Commit | May Push    | Purpose        |
| ---------------- | --------- | ---------- | ----------- | -------------- |
| `handoff`        | Yes       | No         | No          | Generate truth |
| `handoff:commit` | Yes       | Yes        | Branch only | Publish        |
| `ship`           | No        | No         | No          | Verify         |
| `green:*`        | No        | No         | No          | Gates only     |

---

## Enforcement Notes (LOCKED)

### `handoff`

* May write **only** robot-owned truth artifacts:

  * `docs/handoff_latest.txt`
  * `generated/schema.sql`
  * `generated/contracts.snapshot.json`
* Must never:

  * commit
  * push
  * open PRs
  * wait for CI

---

### `handoff:commit`

* Is the **only publisher** of truth artifacts.
* Must be **janitor-proof**.

Required behavior:

* If current branch is `main`:

  * auto-create a PR branch
* Commit **only** truth artifacts
* Push **only** the PR branch
* Must never:

  * commit `main`
  * push `main`
  * bypass PR flow

---

### `ship`

* **Proof-only** command.
* main branch only.
* Requires clean working tree.

Must:

* Run verification gates only
* Exit `0` (pass) or `1` (fail)

Must never:

* run `handoff`
* generate artifacts
* commit
* push
* wait for CI
* trigger workflows

---

### `green:*`

* Gate-only commands (`green:once`, `green:twice`)
* Must never:

  * run `handoff`
  * write artifacts
  * commit
  * push

---

## Local Green Gate Loop (Implementation)

`green:*` runs deterministic proof passes of:

1. Hard reset local stack (Windows-safe):

   ```bash
   npx supabase stop --no-backup
   npx supabase start -x vector --ignore-health-check
   ```

2. Validate running state:

   ```bash
   npx supabase status
   ```

3. Lints and checks:

   ```bash
   npm run lint:migrations
   npm run lint:sql
   npm run lint:pgtap
   ```

4. Build (may be a no-op):

   ```bash
   npm run build
   ```

Rules:

* No generators allowed
* No commits allowed
* No pushes allowed
* Must be repeatable

Requirement:

* `green:twice` = two consecutive passes with **no edits between**

---

## End-of-Session Automation (AUTHORITATIVE)

End-of-session publishing is **explicitly not handled by `ship`**.

Correct flow:

```bash
npm run handoff
npm run handoff:commit
```

Everything else (PR open, CI wait, merge) is human + CI controlled.

---

## Release Verification Automation

Release verification is **manual + proof-only**.

```bash
git checkout main
git pull
git status
npm run ship
```

Rules:

* If working tree is dirty → STOP
* If `ship` fails → STOP
* `ship` does not publish

---

## Docs-Only Changes

If only documentation files changed:

* Do **not** run `ship`
* Use:

  ```bash
  npm run docs:push
  ```

---

## CI Behavior (Every Push / PR)

### Required workflows

* `.github/workflows/database-tests.yml` (pgTAP)
* `.github/workflows/ci.yml` (policy / guardrails)

### Required check naming (Rulesets)

* Must originate from **GitHub Actions**
* Must match check names **string-exactly**
* Must exist on `main` before being marked required

---

## Schema Drift Is Intentional

CI regenerates truth artifacts and fails if they differ from committed:

* `docs/handoff_latest.txt`
* `generated/schema.sql`
* `generated/contracts.snapshot.json`

Correct response to drift:

```bash
npm run handoff
npm run handoff:commit
```

Never “fix” drift manually.

---

## SQL Safety Lint (ENFORCED)

CI enforces:

* No `$$` dollar quoting
* UTF-8 **without BOM**
* No UTF-16
* pgTAP files must be SQL-only, deterministic, and complete

---

## Truth Files (Robot-Owned)

The following are **robot-owned** and must never be hand-edited:

* `docs/handoff_latest.txt`
* `generated/schema.sql`
* `generated/contracts.snapshot.json`
* `.gitattributes`

If they change, it must be via:

```bash
npm run handoff
npm run handoff:commit
```

---

## CI Schema Drift — Supabase CLI Version (ENFORCED)

If CI reports drift but local checks pass:

* Assume Supabase CLI version mismatch
* CI must pin CLI explicitly (e.g. `supabase/setup-cli@v1` with version)
* After pinning:

  ```bash
  npm run handoff
  npm run handoff:commit
  ```
Add/append under CI / required checks: “Definer safety audit” now runs in CI via scripts/ci_definer_safety_audit.ps1 (enumerates SECURITY DEFINER funcs; fails on missing search_path=pg_catalog, public or unqualified internal calls).

Note where it runs in workflow (.github/workflows/ci.yml after ci_boot.ps1).

## Pre-commit Safety Gate (SQL)

### What it does
A local Git pre-commit hook runs automatically on every `git commit`. It scans staged SQL migrations and blocks commits that violate SQL safety rules.

### Why it exists
This prevents merge-blocking CI failures by stopping unsafe SQL from being committed in the first place (e.g., `$$` dollar-quoting, UTF-16, and other banned patterns).

### How it works (automated)
- Tooling: Husky + lint-staged
- Trigger: `git commit` (automatic)
- Scope: staged files matching `supabase/**/*.sql`
- Command executed: `node scripts/run_lint_sql.mjs`
- Result:
  - PASS → commit continues
  - FAIL → commit is blocked with an error message

### Operator notes
- Humans/AIs do not need to manually run anything for this gate.
- Bypass is possible only with intentional override (e.g., `--no-verify`). Do not bypass except for emergency recovery with a written post-mortem.

### Quick manual check (optional)
- `npm run lint:sql`
- `npx lint-staged` (only checks staged files)

## Commit-time gates (automatic)

On `git commit`, Husky runs lint-staged automatically:

- SQL Safety Gate:
  - staged `supabase/**/*.sql`
  - runs `node scripts/run_lint_sql.mjs`
  - blocks unsafe SQL (ex: `$$`)

- BOM Gate:
  - staged `**/*.{json,md,yml,yaml,js,mjs,ts,tsx,sql,ps1}`
  - runs `node scripts/lint_bom_gate.mjs`
  - blocks UTF-8 BOM / UTF-16 BOM (prevents “looks-valid but tooling fails” issues)

Bypass (`--no-verify`) is prohibited except emergency recovery with written post-mortem.


## secrets-scan (merge-blocking)
- Implemented as GitHub Actions workflow .github/workflows/secrets-scan.yml running Docker gitleaks.
- No local npm script; local verification may use the same Docker commands as the workflow.


## stop-the-line (merge-blocking)
- Implemented by .github/workflows/stop-the-line.yml.
- Script: scripts/stop_the_line_gate.mjs.
- Required check context: stop-the-line / stop-the-line.

