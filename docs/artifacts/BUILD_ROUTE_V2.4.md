# **Build Route v2.4 — Clean Baseline, Proof-First**

(Restart Fresh • Rebuild Mode)  
Authoritative • Merge-blocking governance • Clean-room replay • Surface truth • E2E release safety  
Version: v2.4  
Status: LOCKED (changes only via PR \+ proof)  
Scope: Supabase \+ WeWeb build, hardening, proofs, release, and operational discipline.  
Solo-team bias: Prefer cheap, mechanical checks over enterprise ceremony.

## **Preamble — System Laws (LOCKED, not part of the route numbering)**

### **REBUILD MODE declaration (MANDATORY, early)**

Intent: governance/tooling/docs/scripts are ported; Supabase database \+ schema are rebuilt greenfield.  
Declaration (authoritative):  
No legacy migrations/history will be imported or replayed.  
Schema will be authored new (clean baseline).  
All prior acceptance language about migration-import, monotonic timestamp porting, or legacy replay is INVALID.  
DoD:  
docs/proofs/0.0\_rebuild\_mode\_.md exists and explicitly states "no legacy migration import."  
docs/threats/INCIDENTS.md includes a REBUILD MODE switch entry with commit/PR reference.  
Proof: docs/proofs/0.0\_rebuild\_mode\_.md  
Gate: rebuild-mode-declared (merge-blocking)

### **Publisher Law (LOCKED)**

Law: handoff:commit is the only publisher. ship is verify-only.

### **Truth Hierarchy (Conflict Resolver)**

If conflicts exist, resolve in this order:  
docs/handoff\_latest.txt (handoff pointer \+ current state)  
generated/schema.sql (schema truth)  
generated/contracts.snapshot.json (contracts truth)  
Specific truth files (explicit):  
docs/truth/required\_checks.json (merge-blocking checks only)  
docs/truth/lane\_checks.json (lane-only checks only)  
docs/truth/toolchain.json  
docs/truth/qa\_requirements.json  
docs/truth/expected\_surface.json  
docs/truth/execute\_allowlist.json  
docs/truth/definer\_allowlist.json  
docs/truth/tenant\_table\_selector.json  
docs/truth/blocked\_identifiers.json  
docs/truth/rpc\_budget.json  
docs/truth/pr\_scope\_rules.json  
docs/truth/robot\_owned\_paths.json  
docs/truth/privilege\_truth.json  
Proof integrity layer:  
docs/proofs/manifest.json (hashes \+ chain-of-custody)  
Policy docs:  
docs/artifacts/*, docs/ops/*, docs/threats/\*, DEVLOG

### **Prime Directive**

Nothing is "done" unless all are true:  
DoD exists  
Proof exists in docs/proofs/  
Gate exists that fails on regression (local and/or CI)  
QA returns STATUS: PASS based on artifacts

### **One Objective \= One PR**

One objective → one branch → one PR → one merge.

### **Mandatory Means Merge-blocking**

If marked mandatory, it maps to a merge-blocking check unless explicitly marked lane-only or one-time (with mechanism below).

### **Proof Locality**

Proofs must be generated from the PR branch/commit they claim to verify.

### **Clean Tree Invariant**

No handoff/release actions unless git status is clean.

---

## **1 — Port Manifest (Governance Port Only, P0/P1/P2/P3)**

Umbrella Gate Rule: Steps 1.1–1.4 are collectively enforced by a single merge-blocking gate named port-manifest.  
The gate must prove each subcondition in its proof log.

### **1.1 P0 — Port 100% (mandatory, governance/tooling/docs/scripts only) (DONE FEB 7\)**

Deliverable: All governance \+ enforcement assets exist in v2 (REBUILD MODE: database/schema are NOT ported).  
DoD:  
All required assets exist exactly as specified in Checklist 1.1.  
No database/schema artifacts are ported as "truth" (per Checklist 1.4/regen policy).  
Checklist 1.1 (non-DoD):  
Repo enforcement  
.gitattributes  
.editorconfig  
lockfile (package-lock.json or equivalent)  
CODEOWNERS  
.github/workflows/\*\* Docs (policy)  
docs/artifacts/AUTOMATION.md  
docs/artifacts/CONTRACTS.md  
docs/artifacts/GUARDRAILS.md  
docs/artifacts/RELEASES.md  
docs/artifacts/SOP\_WORKFLOW.md  
Ops  
docs/ops/BUDGETS.md  
docs/ops/ONBOARDING.md  
docs/ops/PRIORITIES.md  
Threat model \+ incidents  
docs/threats/THREATS.md  
docs/threats/INCIDENTS.md  
Handoff pointer  
docs/handoff\_latest.txt  
Scripts (port all)  
your existing scripts list plus:  
scripts/build.mjs  
scripts/ci\_boot.ps1  
scripts/ci\_definer\_safety\_audit.ps1  
scripts/ci\_guard\_gitattributes.ps1  
scripts/ci\_policy.ps1  
scripts/ci\_schema\_drift.ps1  
scripts/contracts\_lint.ps1  
scripts/db\_push\_guard.ps1  
scripts/docker\_cleanup\_project.ps1  
scripts/docs\_push.ps1  
scripts/fix\_encoding.ps1  
scripts/gen\_contracts\_snapshot.ps1  
scripts/gen\_schema.ps1  
scripts/green\_gate.mjs  
scripts/handoff.ps1  
scripts/handoff\_commit.ps1  
scripts/lint\_bom\_gate.mjs  
scripts/lint\_migrations.mjs  
scripts/lint\_pgtap.mjs  
scripts/lint\_sql\_safety.ps1  
scripts/must\_contain.ps1  
scripts/patch\_green\_gate.mjs  
scripts/preflight\_encoding.ps1  
scripts/prepare\_ci\_safe.mjs  
scripts/run\_lint\_sql.mjs  
scripts/ship.mjs  
scripts/ship\_guard.ps1  
Note: Truth files \+ schemas are created and validated later in the Truth Bootstrap step (not required to exist at port time).  
Proof: docs/proofs/1.1\_port\_manifest\_.log  
Gate: port-manifest (merge-blocking)

### **1.2 P1 — Governance port is runnable (mandatory)(DONE FEB7)**

Deliverable: Ported governance/tooling is runnable and not "dead on arrival".  
DoD:  
All required repo scripts/targets run successfully locally (per Checklist 1.2).  
Workflows parse (YAML valid) and referenced scripts exist on disk.  
Checklist 1.2 (non-DoD):  
npm ci succeeds  
npm run lint:migrations succeeds (runner exists; OK if "no migrations")  
npm run lint:sql succeeds  
npm run lint:pgtap succeeds (runner exists; OK if "no tests" is permitted PASS)  
npm run build succeeds (or governance-only build target exists and passes)  
All scripts referenced by npm scripts exist on disk  
Proof: docs/proofs/1.2\_port\_governance\_runnable\_.log  
Gate: port-governance-runnable (merge-blocking)

### **1.3 P2 — Denylist (never port) (DONE FEB 7\)**

Deliverable: No ghost carriers.  
DoD:  
Denylisted paths are absent (per Checklist 1.3).  
Proof log includes the exact commands used to verify absence.  
Checklist 1.3 (non-DoD):  
supabase/.branches/  
supabase/.temp/  
any local supabase state  
docker volumes  
secret-bearing logs  
Proof: docs/proofs/1.3\_denylist\_.log  
Gate: port-manifest (merge-blocking)

### **1.4 P3 — Regenerate only (DONE FEB 7\)**

Deliverable: Generated outputs are regenerated in v2.  
DoD:  
No generated outputs are ported (per Checklist 1.4).  
Repo contains policy that generated outputs are produced only via generators.  
Checklist 1.4 (non-DoD):  
Do not port:  
generated/schema.sql  
generated/contracts.snapshot.json  
any derived outputs  
Proof: docs/proofs/1.4\_regen\_policy\_.log  
Gate: port-manifest (merge-blocking)

### **1.5 Document Corrections (mandatory in porting) (DONE FEB 7\)**

Deliverable: Ported docs reflect the true command contract.  
DoD:  
All "ship publishes" statements are removed/replaced with "handoff:commit publishes; ship verifies."  
Proof contains diff excerpts demonstrating the corrections.  
Checklist 1.5 (non-DoD):  
Update docs/ops/PRIORITIES.md publish semantics  
Correct historical note(s) in docs/threats/INCIDENTS.md  
Proof: docs/proofs/1.5\_doc\_corrections\_.md  
Gate: policy-coupling (merge-blocking)

---

## **2 — Repo Baseline \+ Governance (Day-0)**

### **2.1 Repo bootstrap (DONE FEB 7\)**

Deliverable: Repo boots with toolchain pinned and precommit functional.  
DoD:  
Local \+ CI npm ci succeeds with no husky CI failure.  
Proof includes CI run link and tool versions printed.  
Proof: docs/proofs/2.1\_repo\_bootstrap\_.log  
Gate: ci-boot (merge-blocking)

### **2.2 Toolchain truth \+ pinning (DONE FEB 8\)**

Deliverable: Core tool versions are pinned and verified.  
DoD:  
docs/truth/toolchain.json exists and is validated by CI output comparison.  
CI hard-fails on any toolchain mismatch (Node / runner OS).  
Proof: docs/proofs/2.2\_toolchain\_versions\_.log  
Gate: toolchain-contract-core (merge-blocking)  
(Supabase CLI / psql removed; handled later.)

### **2.3 Normalize enforcement (DONE FEB 8\)**

Deliverable: .gitattributes is actually enforced (Windows↔CI drift prevented).

DoD: CI hard-fails if git add \--renormalize would change any allowlisted docs/truth/robot paths.

Proof: docs/proofs/2.2a\_renormalize\_enforced\_\<UTC\>.log

Gate: renormalize-enforced (merge-blocking)

### **2.4 Branch Protection \+ Ruleset Enforced (One-Time, Stable Prerequisite)(DONE FEB 8\)**

**Deliverable**:  
GitHub ruleset enforces required checks \+ no admin bypass.

**DoD**:

1. **GitHub Branch Protection Rules**:  
   * **No direct pushes to `main`** are allowed.  
   * **No admin bypass** for merging.  
   * Verified in GitHub Settings (with export/screenshots or links for re-verification).  
2. **GitHub Settings Link**:  
   * Ensure the **GitHub branch protection settings** are configured correctly for `main`.  
   * Proof includes a link to the settings page for review.  
3. **CI Verification**:  
   * CI must show the correct application of these protection rules by passing the required checks as specified in `docs/proofs/2.3_repo_rules_enforced_20260208_163125.md`.  
4. **PR for 2.3**:  
   * A **GitHub PR** must be created to explicitly enforce these rules in the repository.  
   * The PR should include:  
     * **Setup of GitHub branch protection rules**.  
     * **Link to the proof file and settings**.  
     * **Validation of proof via CI run**.

**Proof**:

* Proof Log: [docs/proofs/2.3\_repo\_rules\_enforced\_20260208\_163125.md](https://github.com/marietsairealtor-cloud/equity-flow-system/blob/main/docs/proofs/2.3_repo_rules_enforced_20260208_163125.md)  
* **GitHub Settings Link**: [GitHub Branch Protection Settings](https://github.com/marietsairealtor-cloud/equity-flow-system/settings/branches/main)  
* **GitHub CI Run**: [CI Run Link](https://github.com/marietsairealtor-cloud/equity-flow-system/actions/runs/21800144370)

**Gate**: lane-only repo-ruleset-contract (merge-blocking)

### **2.5 Truth Bootstrap (mandatory)(DONE FEB 8\)**

Deliverable: Truth files \+ schemas required for gates exist and are validated.  
DoD:  
All truth inputs \+ schemas exist (per Checklist 2.5) and validate.  
Proof shows validation command outputs (schema validation \+ any harness validations).  
Checklist 2.5 (non-DoD):  
Truth inputs:  
docs/truth/required\_checks.json (merge-blocking only)  
docs/truth/lane\_checks.json (lane-only only)  
docs/truth/toolchain.json  
docs/truth/qa\_requirements.json  
docs/truth/expected\_surface.json  
docs/truth/execute\_allowlist.json  
docs/truth/definer\_allowlist.json  
docs/truth/pr\_scope\_rules.json  
docs/truth/robot\_owned\_paths.json  
docs/truth/rpc\_budget.json  
docs/truth/blocked\_identifiers.json  
docs/truth/tenant\_table\_selector.json  
docs/truth/privilege\_truth.json  
Schemas:  
docs/truth/qa\_requirements.schema.json  
docs/truth/surface\_truth.schema.json  
docs/truth/cloud\_inventory.schema.json  
docs/truth/privilege\_truth.schema.json  
Proof: docs/proofs/2.5\_truth\_bootstrap\_.log  
Gate: truth-bootstrap (merge-blocking)

### **2.6 Required checks contract (merge-blocking)(FEB 8\)**

Deliverable: required\_checks.json is real and enforceable.  
DoD:  
Contract script verifies required\_checks.json matches workflow job names string-exact (no phantoms).  
Contract script verifies lane-only gates are excluded from required\_checks.json.  
Proof: docs/proofs/2.6\_required\_checks\_contract\_.log  
Gate: required-checks-contract (merge-blocking)

### **2.7 Docs-only CI skip contract (NEW, mandatory)(DONE FEB 8\)**

Deliverable: Docs-only PRs do not run DB-heavy workflows.  
DoD:  
If PR diff touches only `docs/**`, DB-heavy jobs are skipped mechanically.  
Docs-only PR still runs required governance gates (as defined in required\_checks.json).  
Proof: docs/proofs/2.7\_docs\_only\_ci\_skip\_.log  
Gate: docs-only-ci-skip (merge-blocking)

### **2.8 Command Smoke (Gov-only) (mandatory)(DONE FEB 9\)**

Deliverable: Governance commands still run without Supabase.

DoD: These scripts exist (per `npm run`) and each returns PASS on main without DB:

`preflight:encoding`, `renormalize:check`, `toolchain:contract`, `truth-bootstrap`, `required-checks-contract`, `docs-only-ci-skip`.

Proof: `docs/proofs/2.8_command_smoke_gov_<UTC>.log`

Gate: `command-smoke-gov` (merge-blocking)

### **2.9 Main moved guard.(DONE FEB 9\)**

DoD

* CI fails on PR if HEAD is not up-to-date with origin/main.  
* Output prints:  
  behind/ahead counts  
  the exact required fix: git fetch origin && git rebase origin/main  
* Exemption allowed only for lane-only workflows (if you want), otherwise always enforced.

Gate name

main-moved-guard (merge-blocking)

Proof

docs/proofs/2.9\_main\_moved\_guard\_\<UTC\>.log

### **2.10 Proof chain-of-custody \+ manifest(DONE FEB 9\)**

Deliverable: Proofs are hash-tracked and append-only.  
DoD:  
docs/proofs/manifest.json exists and contains SHA256 for all proofs in-scope.  
Append-only rules are enforced mechanically (modify/delete forbidden without redaction protocol).  
Proof: docs/proofs/2.10\_proof\_manifest\_.log  
Gate: proof-manifest \+ proofs-append-only (merge-blocking)

### **2.11 Proof redaction escape hatch (only for secrets / corruption)(DONE FEB 9\)**

Deliverable: Fix accidental secret capture without breaking the system.  
DoD:  
Any proof edit/delete is paired with PROOF\_REDACTION\_\_.md explaining replacement and why.  
If secret-related, INCIDENTS entry exists and secrets scan passes.  
Proof: redaction md \+ updated manifest  
Gate: enforced by proofs-append-only (merge-blocking)

### **2.12 Secrets discipline gate(DONE FEB 9\)**

Deliverable: No secrets in repo, including proofs.  
DoD:  
Precommit \+ CI secrets scan passes for repo and docs/proofs/\*\*.  
Proof shows scanner output \+ version.  
Proof: docs/proofs/2.12\_secrets\_scan\_.log  
Gate: secrets-scan (merge-blocking)

### **2.13 Environment sanity gate (DONE FEB 9\)**

Deliverable: Clean-room replay can't run on contaminated docker context.  
DoD:  
env\_sanity passes and fails on contamination conditions (defined in script).  
Proof shows env\_sanity output run immediately before clean-room replay.  
Proof: docs/proofs/2.13\_env\_sanity\_.log  
Gate: env-sanity (merge-blocking)

### **2.14 Stop-the-line incident coupling (solo-friendly)(DONE FEB 9\)**

Deliverable: Incident-class patterns can't be silently ignored.  
DoD:  
CI stop-the-line conditions require INCIDENTS entry OR a one-PR waiver file.  
Waiver validity is mechanically enforceable (PRNUM+commit+"QA: NOT AN INCIDENT").  
Proof: docs/proofs/2.14\_stop\_the\_line\_.log  
Gate: stop-the-line (merge-blocking)

### **2.15 Governance-change guard(DONE FEB 9\)**

Deliverable: Changes to core docs/truth/policy require explicit justification.  
DoD:  
Any PR touching core truth requires a GOVERNANCE\_CHANGE\_*.md.* *Guard prevents "docs-only" classification on such PRs.* *Proof: docs/proofs/2.15\_governance\_change*.log  
Gate: governance-change-guard (merge-blocking)

---

## **Section 2.16 — Additive Governance Hardening (Post-Close)**

*(Section 2 remains closed; all items are additive only)*

---

### **2.16.1 — GitHub Policy Drift Attestation (Scheduled)(DONE FEB 10\)**

**Deliverable** Scheduled CI workflow that detects GitHub governance drift outside repo control.

**DoD**

* Workflow runs on schedule (and manual trigger).  
* Fetches via GitHub API:  
  * branch protection / rulesets  
  * required checks  
  * admin bypass flags  
* Diffs against committed snapshot `docs/truth/github_policy_snapshot.json`.  
* Any mismatch produces a loud signal (CI fail or issue).

**Proof** `docs/proofs/2.16.1_policy_drift_attestation_<UTC>.log`

**Gate** `policy-drift-attestation` (scheduled, non-merge-blocking)

---

### **2.16.2 — Proof Commit-Binding (Validity Enforcement, Minimal)(DONE FEB 10\)**

**Deliverable** Proof header contract \+ validator binding proofs to reality.

**DoD** **All must be true:**

1. **Build Route updated** * **`PROOF_HEAD` defined as tested SHA at runtime** * **Valid if `PROOF_HEAD` is an ancestor of PR\_HEAD** * **`git diff --name-only PROOF_HEAD..PR_HEAD` contains only:** * **`docs/proofs/**`** * **optionally `docs/DEVLOG.md`** * **SKIP rule documented: if no `docs/proofs/**` touched, gate exits `0` with `PROOF_COMMIT_BINDING_SKIP`** 2. **Validator implemented** * **Gate `proof-commit-binding` enforces the above rules** * **Fails on:** * **non-ancestor `PROOF_HEAD`** * **non-proof tail changes** * **missing/mismatched `PROOF_SCRIPTS_HASH`** * **Uses deterministic, normalized script-hash algorithm per AUTOMATION** 3. **Proof artifact committed** * **`docs/proofs/2.16.2_proof_commit_binding_<UTC>.log`** * **Contains:** * **`PROOF_HEAD`** * **`PROOF_SCRIPTS_HASH`** * **`RESULT=PASS`** 4. **Manifest updated** * **`docs/proofs/manifest.json` includes the new proof log with correct sha256** 5. **CI wired \+ merge-blocking** * **Job `proof-commit-binding` exists in `.github/workflows/ci.yml`** * **Registered as required check** * **CI is green**

**Proof** `docs/proofs/2.16.2_proof_commit_binding_<UTC>.log`

**Gate** `proof-commit-binding` (merge-blocking)

---

### **2.16.2A Hash Authority Contract (NEW, mandatory)(DONE FEB 11\)**

**Deliverable:** `PROOF_SCRIPTS_HASH` authority is declared once and cannot drift.

**DoD:**

* `docs/artifacts/AUTOMATION.md` contains a subsection **"proof-commit-binding — scripts hash authority"** that defines, **string-exact**:  
  * the **script file list** included in `PROOF_SCRIPTS_HASH`  
  * the **ordering rule** (explicit order or path-sorted)  
  * the **normalization rule** (**CRLF→LF** before hashing)  
* `scripts/ci_proof_commit_binding.ps1` computes `PROOF_SCRIPTS_HASH` **exactly per `docs/artifacts/AUTOMATION.md`** (no inference, no globbing).  
* The 2.16.2 proof log shows **matching** `PROOF_SCRIPTS_HASH` between proof header and validator output.

**Proof:** `docs/proofs/2.16.2A_hash_authority_contract_<UTC>.log`

**Gate:** `proof-commit-binding` (merge-blocking)

---

### **2.16.3 — CI Semantic Contract (Targeted Anti–No-Op)(DONE FEB 11\)**

**Deliverable** Semantic validation that required CI jobs actually execute gates.

**DoD**

* If `.github/workflows/**` **changes** in PR:  
  * semantic contract is **merge-blocking** * Otherwise:  
  * runs **alert-only** (PR \+ scheduled)  
* Validator asserts required jobs:  
  * invoke allowlisted gate scripts  
  * are not noop / echo-only exits

**Proof** `docs/proofs/2.16.3_ci_semantic_contract_<UTC>.log`

**Gate** `ci-semantic-contract`  
(merge-blocking **only** on workflow changes)

---

### **2.16.4 — Waiver Debt Enforcement (Low-Ceiling Hard Fail)(DONE FEB 11\)**

**Deliverable** Mechanical limit preventing waiver normalization.

**DoD**

* CI computes waiver usage from `docs/waivers/` \+ repo history.  
* Threshold rules:  
  * **\>1 waiver in last 14 days → hard FAIL** * Below threshold:  
  * WARN \+ signal only  
* Forces cleanup: convert to INCIDENT or remove waiver.

**Proof** `docs/proofs/2.16.4_waiver_debt_enforcement_<UTC>.log`

**Gate** `waiver-debt-enforcement` (merge-blocking at low ceiling)

---

### **2.16.4A — CI Gate Wiring Closure (Authoritative)(DONE FEB 12\)**

**Objective:** Close known governance gate wiring gaps by ensuring all merge-blocking governance gates **required up to this section** are present in CI as **string-exact job IDs** and are structurally merge-blocking via the repo's aggregate `required` job. Structural enforcement only.

**Authoritative Source:** `docs/truth/required_checks.json`

**Deliverable:** `.github/workflows/**` contains jobs with **string-exact job IDs** for every required check in `docs/truth/required_checks.json`, and `.github/workflows/ci.yml:required.needs` depends on them.

**DoD:**

* `docs/truth/required_checks.json` exists and contains the authoritative list of required merge-blocking job IDs.  
* Every entry in `docs/truth/required_checks.json` exists as a **job ID** in `.github/workflows/**` (string-exact).  
* Aggregate enforcement is complete:  
  * `.github/workflows/ci.yml` contains job `required`  
  * `required.needs` contains **all** entries from `docs/truth/required_checks.json` (string-exact)  
* Workflows are runnable on PRs (`pull_request` present; not dispatch-only).

**Proof:** `docs/proofs/2.16.4A_ci_gate_wiring_closure_<UTC>.log`  
Must include: PR HEAD SHA, contents of `docs/truth/required_checks.json`, workflow inventory (`ls .github/workflows`), grep evidence of each job ID in workflows, extracted `required.needs`, PASS/FAIL statement:  
`All docs/truth/required_checks.json entries exist as workflow job IDs and are included in required.needs.`

**Gate:** `ci-gate-wiring-closure` (merge-blocking)

**Fails if:** Any truth entry missing from workflow job IDs, any string mismatch, or any truth entry missing from `required.needs`.

---

### **2.16.4B — CI Topology Audit Gate (No Phantom Gates Enforcement)(DONE FEB 12\)**

**Objective:** Prevent silent governance drift by mechanically asserting that required merge-blocking gates are **authoritatively declared**, **wired in workflows**, and **structurally merge-blocking**, not merely present in docs or npm scripts.

**Authoritative Source:** `docs/truth/required_checks.json`

**Deliverable:** Merge-blocking PR check `ci-topology-audit` enforcing the **No Phantom Gates** rule.

**DoD:**

* `ci-topology-audit` runs on `pull_request`.  
* It loads required check names from `docs/truth/required_checks.json`.  
* It asserts:  
  1. Every truth entry exists as a **job ID** in `.github/workflows/**` (string-exact).  
  2. `.github/workflows/ci.yml` job `required` exists and `required.needs` contains the full truth set (string-exact).  
  3. Docs / `package.json` scripts are non-authoritative unless workflow wiring exists.

**Proof:** `docs/proofs/2.16.4B_ci_topology_audit_<UTC>.log`

**Gate:** `ci-topology-audit` (merge-blocking)

**Fails if:** Any truth entry missing from workflow job IDs; any truth entry missing from `required.needs`; any string mismatch.

**Failure output must include:** Expected vs found lists for (a) workflow job IDs and (b) `required.needs`, plus workflow file/line pointers where possible.

---

### **2.16.4C — Truth Sync Enforcement (Machine-Derived Truth)(DONE FEB 12\)**

**Objective:** Eliminate human-maintained drift in truth files by making `docs/truth/required_checks.json` **machine-derived** from workflow reality and enforcing a **clean regeneration invariant**.

**Deliverable:** A generator command (example) `npm run truth:sync` that regenerates `docs/truth/required_checks.json` from `.github/workflows/**` \+ `.github/workflows/ci.yml:required.needs`.

**DoD:**

* `npm run truth:sync` deterministically rewrites `docs/truth/required_checks.json` (stable ordering).  
* Running `npm run truth:sync` twice produces identical output.  
* CI runs `npm run truth:sync` and fails if regeneration produces any diff (`git diff --exit-code`).  
* Truth remains authoritative: workflow changes that affect required gates must update truth (by regeneration) in the same PR.

**Proof:** `docs/proofs/2.16.4C_truth_sync_<UTC>.log`  
Must include: PR HEAD SHA, `npm run truth:sync` output, and `git diff --name-only` showing **no changes** after sync.

**Gate:** `truth-sync-enforced` (merge-blocking)

**Fails if:** `npm run truth:sync` produces any diff, output is non-deterministic, or required checks list cannot be derived cleanly.

---

### **2.16.5 — Governance-Change Justification (Human Contract, Minimal Fields)**

Intent: reviewer-discipline spec. NOT a new CI gate / NOT a new required check.

Trigger: only when governance surface changes (workflows, required-check truth, enforcement scripts).

DoD (minimal, mechanical): the PR body must include:
\- GOV\_CHANGE:
\- IMPACT: (list exact workflow/job names affected)
\- RISK: (one line)
\- ROLLBACK: (one line)

Non-Goals:
\- no new workflow
\- no new required checks
\- no new enforcement beyond existing governance-change-guard \+ reviewer checklist

Proof:
docs/proofs/2.16.5\_governance\_change\_justification\_\<UTC\>.log (or link to PR body).
Enforcement:
existing governance-change-guard \+ human review.

---

### **2.16.5A — Foundation Boundary Contract**

Deliverable: Explicit boundary defined between Foundation (governance + core DB security layer) and Product/UI (fork-specific layer).

DoD:

* Foundation = governance + core DB security layer. Foundation owns:  
  * Tenancy model  
  * Memberships \+ roles  
  * Entitlement truth  
  * Activity log contract  
  * Baseline RLS policies \+ negative tests  
  * Core CI contracts/proofs  
* Product/UI owns (must not weaken Foundation invariants):  
  * Product domain tables  
  * WeWeb pages and flows  
  * Product-specific views/functions extending baseline  
* Any change to Foundation paths triggers merge-blocking gates.  
* Boundary documented in docs/artifacts/FOUNDATION\_BOUNDARY.md.

Proof:  
docs/proofs/2.16.5A\_foundation\_boundary\_contract\_.log

Gate:  
merge-blocking (governance)

---

### **2.16.5B — Repo Layout Separation**

Deliverable: Physical directory separation between Foundation and Product layers.

DoD:

* Foundation files reside under dedicated path (e.g., foundation/ or supabase/foundation/).  
* Product code resides under products/\<product\_name\>/.  
* "No cross-write" rule documented: product code may not modify foundation except via defined upgrade protocol.  
* CI path filters reflect separation.

Proof:  
docs/proofs/2.16.5B\_repo\_layout\_separation\_.log

Gate:  
merge-blocking (governance)

---

### **2.16.5C — Foundation Invariants Suite**

Deliverable: Baseline invariant test suite protecting shared platform guarantees.

DoD:

* Tests include:  
  * Tenant isolation  
  * Role enforcement  
  * Entitlement truth compiles  
  * Activity log write path exists  
* Negative tests prove cross-tenant access fails.  
* Suite runs as required CI check for any Foundation path change.

Proof:  
docs/proofs/2.16.5C\_foundation\_invariants\_suite\_.log

Gate:  
merge-blocking (security)

---

### **2.16.5D — Lane Separation Enforcement (Foundation vs Product)**

Deliverable: CI differentiates gating rules between Foundation and Product/UI changes.

DoD:

* Foundation path changes require:  
  * Invariant suite  
  * RLS negative suite  
  * Stop-the-line enforcement  
* Product-only changes may use lane-only checks until promotion threshold.  
* Promotion rule documented.

Proof:  
docs/proofs/2.16.5D\_lane\_separation\_enforcement\_.log

Gate:  
merge-blocking (governance)

---

### **2.16.5E — Foundation Versioning \+ Fork Protocol**

Deliverable: Foundation can be reused safely across multiple products without divergence.

DoD:

* Foundation tagged (e.g., foundation-v0.1.0).  
* Each product declares foundation version consumed.  
* Upgrade protocol defined:  
  * Only tagged releases allowed  
  * No uncontrolled direct edits inside product forks  
* Version reference recorded in artifact.

Proof:  
docs/proofs/2.16.5E\_foundation\_fork\_protocol\_.log

Gate:  
merge-blocking (governance)

---

### **2.16.5F — Anti-Divergence Drift Detector**

Deliverable: Automated detection prevents silent foundation drift across products.

DoD:

* Script compares foundation baseline against product modifications.  
* CI fails on unauthorized foundation edits.  
* Exceptions require waiver \+ proof log.

Proof:  
docs/proofs/2.16.5F\_foundation\_drift\_detector\_.log

Gate:  
merge-blocking (stop-the-line)

---

### **2.16.5G — Product Scaffold Generator**

Deliverable: Repeatable bootstrap mechanism for creating new SaaS products from shared foundation.

DoD:

* Scaffold creates:  
  * products// structure  
  * Schema placeholder  
  * RLS extension placeholder  
  * UI shell  
  * Proof template files  
* Includes product capability matrix declaration.  
* Scaffold documented in artifacts.

Proof:  
docs/proofs/2.16.5G\_product\_scaffold\_generator\_.log

Gate:  
merge-blocking (ops)

---

### **2.16.6 — Lane Policy Truth (Docs-Only / Governance / Runtime Classification)**

**Deliverable:** Machine-readable lane policy extracted from artifacts.

**DoD:**

* `docs/truth/lane_policy.json` exists and defines:  
  * path matchers for lanes (docs-only, governance, runtime/db/security)  
  * for each lane: required checks set (names must match `docs/truth/required_checks.json`)  
* Policy is deterministic (stable ordering).  
* Lane policy is referenced by CI topology audit (or lane enforcement gate).

**Proof:** `docs/proofs/2.16.6_lane_policy_truth_<UTC>.log`

**Gate:** `lane-policy-contract` (merge-blocking)

---

### **2.16.7 — Lane Enforcement Gate (No Misclassified PRs)**

**Deliverable:** PR lane is computed from changed files and required checks are enforced accordingly.

**DoD:**

* Gate computes PR lane using `docs/truth/lane_policy.json`.  
* Gate asserts:  
  * docs-only PRs cannot skip governance-required checks if governance paths changed  
  * governance PRs must run full governance set  
  * runtime/db/security PRs cannot be treated as docs-only  
* Outputs computed lane \+ matched paths \+ required checks.

**Proof:** `docs/proofs/2.16.7_lane_enforcement_<UTC>.log`

**Gate:** `lane-enforcement` (merge-blocking)

---

### **2.16.8 — Stop-the-Line XOR Gate (Incident vs Waiver Enforcement)**

**Deliverable:** Mechanical enforcement of the "exactly one" stop-the-line acknowledgement rule.

**DoD:**

* Gate enforces XOR:  
  * either an INCIDENT entry exists **or** * a WAIVER file exists with required format and explicit acknowledgement text  
* Fails if both exist or neither exists when stop-the-line is triggered.

**Proof:** `docs/proofs/2.16.8_stop_the_line_xor_<UTC>.log`

**Gate:** `stop-the-line-xor` (merge-blocking)

---

### **2.16.9 — Waiver Policy Truth \+ Rate Limit Gate**

**Deliverable:** Mechanical anti–waiver-spam limits encoded in truth and enforced.

**DoD:**

* `docs/truth/waiver_policy.json` exists with:  
  * `window_days`  
  * `max_waivers_in_window`  
  * optional per-category limits (enum)  
* Gate counts waivers in the defined window and fails if limits exceeded.  
* Gate output includes counts \+ window \+ offending waivers.

**Proof:** `docs/proofs/2.16.9_waiver_rate_limit_<UTC>.log`

**Gate:** `waiver-rate-limit` (merge-blocking or alert-only, per your chosen policy)

---

### **2.16.10 — Robot-Owned File Guard (No Hand-Edits to Generated Outputs)**

**Deliverable:** Prevent silent corruption of machine-produced artifacts.

**DoD:**

* Gate defines robot-owned path allowlist (truth or script constants), including:  
  * `generated/**`  
  * `docs/proofs/**` (except new proof logs for the current PR objective)  
  * any other machine-produced outputs you designate  
* Gate fails if robot-owned files are edited outside allowed objective patterns.

**Proof:** `docs/proofs/2.16.10_robot_owned_guard_<UTC>.log`

**Gate:** `robot-owned-guard` (merge-blocking)

---

### **2.16.11 — Governance-Change Template Contract (Structured Fields)**

**Deliverable:** Ensure governance change justifications are structured and non-empty.

**DoD:**

* For governance-touch PRs, `GOVERNANCE_CHANGE_PR*.md` must exist.  
* Must include headings (string-exact):  
  * `What changed`  
  * `Why safe`  
  * `Risk`  
  * `Rollback`  
* Minimum non-whitespace content threshold per section: 40 characters.  
* Does not attempt to judge "quality," only blocks empty boilerplate.

**Proof:** `docs/proofs/2.16.11_governance_change_template_<UTC>.log`

**Gate:** `governance-change-template-contract` (merge-blocking)

---

## **2.17 — Ported Files Stability Sweep (Authoritative)**

---

### **2.17.1 — Repository Normalization Contract**

**Deliverable:** Deterministic line-ending normalization for governed paths.

**DoD:**

* `.gitattributes` enforces LF \+ no-BOM for: `docs/**`, `generated/**`, `supabase/**`  
* `npm run sweep:normalize` runs `git add --renormalize` on allowlisted paths only.  
* Running twice produces zero diff.  
* Any renormalization diff \= failure.

**Proof:** `docs/proofs/2.17.1_normalize_sweep_<UTC>.log`

**Gate:** `ci_normalize_sweep` fails if any diff is detected.

---

### **2.17.1A — proof:finalize Invocation Hardening (Deterministic Arg Passing)**

**Deliverable:** `npm run proof:finalize docs/proofs/<ITEM>_<UTC>.log` works deterministically on Windows across shells by eliminating npm/PowerShell arg-forwarding ambiguity (no `-- -File` ceremony required), while preserving the existing proof discipline and machine-managed manifest rules.

**DoD:**

* `package.json` `proof:finalize` routes through a deterministic wrapper (Node) that:

  * accepts the proof log path as **positional arg** (primary canonical form)
  * supports legacy `-File <path>` (backward compatibility)
  * hard-fails if path is missing, repeated, non-existent, or outside `docs/proofs/**`
  * invokes `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/proof_finalize.ps1 -File <proof_path>` (string-exact)
* `SOP_WORKFLOW.md` canonical finalize command is updated to:

  * `npm run proof:finalize docs/proofs/<ITEM>_<UTC>.log`
  * direct `pwsh ... proof_finalize.ps1 ...` remains **fallback only**
* Proof behavior preserved:

  * proof log normalized to UTF-8 (no BOM) + LF
  * `PROOF_HEAD` / `PROOF_SCRIPTS_HASH` injected as before
  * `docs/proofs/manifest.json` updated **only** via finalize (never manually)

**Proof:**
`docs/proofs/2.17.1A_proof_finalize_arg_hardening_<UTC>.log`

**Gate:**
`proof-manifest` + `proof-commit-binding` must remain green; finalize must succeed using the canonical command above on Windows without `-- -File`.

---

### **2.17.2 — Encoding & Hidden Character Audit**

**Deliverable:** Forbidden character sweep.

**DoD (blocking only):**

* No BOM present.  
* No zero-width characters.  
* No control characters (except tab, LF, CR).  
* UTF-8 consistency may be reported alert-only.

**Proof:** `docs/proofs/2.17.2_encoding_audit_<UTC>.log`

**Gate:** `ci_encoding_audit` fails only on forbidden classes.

---

### **2.17.3 — Absolute Path / Machine Leak Audit**

**Deliverable:** Repo-relative path enforcement (scoped to explicit high-risk outputs).

**DoD:**

* **Blocking scope (explicit allowlist):** * `generated/**`  
  * `docs/proofs/**` (including `manifest.json`)  
* No absolute machine roots within blocking scope:  
  `C:\`, `C:/`, `/Users/`, `/home/runner/`  
* Freeform documentation (`docs/**` outside `docs/proofs/**`) is alert-only.

**Proof:** `docs/proofs/2.17.3_path_leak_audit_<UTC>.log`

**Gate:** `ci_path_leak_audit` blocks only on blocking scope.

---

### **2.17.4 — Parser Contract Resilience Check**

**Deliverable:** Behavior-based validator robustness test.

**DoD:**

* Fixture pack includes adversarial cases:  
  * CRLF  
  * Mixed bullets  
  * Trailing spaces  
  * Blank lines  
* Determinism comparator \= **hash of normalized validator output** per fixture.  
* Gate fails on any validator error class.

**Proof:** `docs/proofs/2.17.4_parser_fixture_check_<UTC>.log`

**Gate:** `ci_validator` must pass for fixture pack \+ comparator.

---

## **3 — Automation Build (required)**

### 3.0 — Section 3 Execution Constraints (LOCKED)

Section 3 modifies enforcement tools themselves
(handoff, handoff:commit, ship, green:\*, qa:verify).
Because the validation surface is under modification,
additional isolation discipline is required.

These constraints apply to all Section 3 objectives.

1. PR Isolation Rule
   - Do not modify ship and green:\* in the same PR.
   - Do not modify proof-commit-binding in the same PR as other automation.
   - Only one enforcement surface may be modified per PR.
   - One objective = one PR remains mandatory.

2. Self-Validation Discipline
   - All automation modifications must complete:
       green:once
       green:twice
     with no edits between runs before proof generation.
   - No generators may run during the green gate loop.
   - ship must remain verify-only at all times.

3. No Circular Enforcement Modification
   - If a PR modifies proof-commit-binding,
     it must not modify any other automation command.
   - If a PR modifies green:\*,
     it must not modify ship.
   - If a PR modifies ship,
     it must not modify green:\*.

4. New Truth Artifact Registration (Triple Registration Rule)
   Any new truth artifact introduced in Section 3 must, in the same PR:
     a. Be registered in robot-owned guard.
     b. Be included in CI drift/validation enforcement
        (truth-bootstrap or equivalent validation gate).
     c. Be included in handoff regeneration surface if machine-derived.

   No truth artifact may exist in-repo without all three registrations.

5. Pre-Section-3 Governance Integrity Requirement
   Section 3 implementation may not begin until:
     - Section 3 Execution Constraints are merged into Build Route.
     - Governance-change template and proof requirements are satisfied.
     - main is clean and pr:preflight passes.

Rationale:
Section 3 modifies the system that validates itself.
Strict PR isolation and artifact registration prevent circular
validation failure and partially governed enforcement surfaces.

---

### **3.1 Automation contract acceptance**

Deliverable: Scripts obey AUTOMATION.md command separation.

DoD:
- A gate script (`automation-contract`) mechanically verifies command separation. The gate must be a script that asserts behaviors programmatically, not a human-authored narrative proof.
- Gate output demonstrates each command mode behavior (handoff/ship/green).
- Automation behaviors match Checklist 3.1 exactly.

Checklist 3.1 (non-DoD):
- handoff may write truth artifacts only; cannot commit/push.
- handoff:commit is the only publisher; may push PR branch only.
- ship verify-only; no writes/commits/push; never waits/polls CI.
- green:\* gates-only; never runs generators.

Pre-implementation check:
- Determine whether `scripts/ci_automation_contract.ps1` (or equivalent) already exists from the port.
- If it exists: this item is proof-only (verify existing gate satisfies DoD).
- If it does not exist: this item is implementation + proof (create the gate script, then prove).
- The distinction must be recorded in the PR description.

Proof: docs/proofs/3.1\_automation\_contract\_.log
Gate: automation-contract (merge-blocking)

---

### **3.2 Ship guard (LOCKED choice)**

Deliverable: ship is always verify-only.

DoD:
- ship fails on dirty tree or disallowed branch.
- ship fails if it produces any diffs.

Pre-implementation check:
- `ship-guard` is already listed as a required check and appears in existing CI.
- Before starting, run `npm run ship` on main and capture output.
- If existing behavior already satisfies DoD: this item is proof-only.
- If hardening is needed (e.g., the "fails if it produces any diffs" check is missing): scope the delta explicitly in the PR description.

Proof: docs/proofs/3.2\_ship\_guard\_.log
Gate: ship-guard (merge-blocking)

---

### **3.3 Command contract contradiction closure (handoff:commit push semantics)**

Deliverable: Publishing semantics are unambiguous.

DoD:
- handoff:commit refuses detached HEAD and refuses pushing to main.
- handoff:commit pushes current branch only and prints remote ref pushed.

Relationship to 11.2:
- 3.3 creates or hardens the `handoff-commit-safety` gate.
- 11.2 (Handoff publish — branch only) re-proves the same gate at release scope.
- If the gate already exists and satisfies DoD, 3.3 is proof-only.
- Both items share gate name `handoff-commit-safety`. This is intentional: 3.3 is the implementation checkpoint; 11.2 is the release re-verification.

Proof: docs/proofs/3.3\_handoff\_commit\_push\_.log
Gate: handoff-commit-safety (merge-blocking)

---

### **3.4 Docs publish contract (docs:push) (required)**

Deliverable: Docs publishing cannot mutate robot-owned outputs.

DoD:
- docs:push refuses detached HEAD, refuses pushing to main, and requires clean tree.
- docs:push refuses if diff touches robot-owned paths.

Proof: docs/proofs/3.4\_docs\_push\_.log
Gate: docs-push-contract (merge-blocking)

---

### **3.5 QA requirements truth (schema + lock)**

Deliverable: QA checklist is structured and can't be weakened silently.

DoD:
- qa\_requirements.json validates against qa\_requirements.schema.json.
- Any change to qa\_requirements.json requires version bump + governance-change proof (enforced).
- The governance-change enforcement triggers **only when qa\_requirements.json is in the PR diff**, not unconditionally.

Triple Registration Rule (§3.0.4) applies:
- qa\_requirements.json and qa\_requirements.schema.json must be registered in robot-owned guard (§3.0.4a).
- Both must be included in truth-bootstrap or equivalent validation gate (§3.0.4b).
- If machine-derived, both must be included in handoff regeneration surface (§3.0.4c).

Pre-implementation check:
- `docs/truth/qa_requirements.json` and `docs/truth/qa_requirements.schema.json` may already exist from truth bootstrap (2.5).
- If files exist: this item adds the version-bump enforcement gate and governance-change coupling.
- If files do not exist: this item creates them with all three registrations in the same PR.

Proof: docs/proofs/3.5\_qa\_requirements\_.log
Gate: qa-requirements-contract (merge-blocking)

---

### **3.6 Robot-owned generator enforcement (NEW, mandatory)**

Deliverable: Generator outputs cannot be produced/modified outside handoff:commit.

DoD:
- CI fails if `generated/**`, `docs/proofs/**`, or `docs/handoff_latest.txt` are modified without robot-owned publisher conditions.
- This gate (`robot-owned-publish-guard`) is **distinct from** `robot-owned-guard` (2.16.10).
  - 2.16.10 (`robot-owned-guard`) prevents unauthorized **edits** to machine-produced files.
  - 3.6 (`robot-owned-publish-guard`) prevents unauthorized **generation/publication** of machine-produced files.
  - Both gates must exist independently. 3.6 must not be implemented as an extension of 2.16.10.

Proof: docs/proofs/3.6\_robot\_owned\_publish\_guard\_.log
Gate: robot-owned-publish-guard (merge-blocking)

---

### **3.7 QA verify (merge-blocking)**

Deliverable: QA verification is deterministic.

DoD:
- npm run qa:verify emits STATUS PASS/FAIL based only on truth + proofs.
- It validates manifest hashes + required proofs exist for PR scope.
- qa:verify does **not** re-implement hash validation already performed by `proof-manifest`. It validates **completeness** (required proofs exist for the PR's claimed objective), not integrity (which `proof-manifest` and `proof-commit-binding` already cover).

PR-scope mapping mechanism (MUST BE DEFINED BEFORE IMPLEMENTATION):
- The mechanism by which qa:verify determines "which proofs are required for this PR" must be explicitly defined in the PR description before coding begins.
- Acceptable mechanisms include: branch-name convention, PR label, explicit mapping file, or changed-file inference.
- The chosen mechanism must be documented in AUTOMATION.md as part of this item.
- Fragile or implicit inference (e.g., parsing Build Route item numbers from branch names without a contract) is not acceptable.

Circular dependency mitigation:
- qa:verify is the meta-gate that validates the proof system itself.
- The first test run of qa:verify must validate against existing proofs from prior sections (e.g., 2.17 proofs), not against its own proof.
- The proof for 3.7 itself must be the **last artifact generated** in this PR.
- The PR must demonstrate that qa:verify passes against known-good prior state before its own proof is finalized.

Proof: docs/proofs/3.7\_qa\_verify\_.log
Gate: qa-verify (merge-blocking)

---

### Section 3 — Execution Order (Authoritative)

| Item | Title | Rationale |
|------|-------|-----------|
| 3.1 | Automation contract acceptance | Establishes the contract all other items must satisfy |
| 3.2 | Ship guard | Likely proof-only (ship-guard may already exist); quick close |
| 3.3 | handoff:commit push semantics | Publisher safety; clean scope |
| 3.4 | Docs publish contract | Same pattern as 3.3; clean scope |
| 3.5 | QA requirements truth | Triggers triple-registration; introduces new truth artifact |
| 3.6 | Robot-owned publish guard | Depends on understanding the publisher model from 3.3 |
| 3.7 | QA verify | Meta-gate; validates all preceding Section 3 proofs |

This ordering minimizes circular dependencies. The meta-gate (3.7) is built last so it can use the other six items' proofs as its acceptance test.

---

### Section 3 — Risk Summary

| Item | Risk | Key Watch |
|------|------|-----------|
| 3.1 | Low | Confirm gate script exists vs needs creation |
| 3.2 | Low | May be proof-only; verify existing behavior before starting |
| 3.3 | Low | Relationship to 11.2 clarified (same gate, different proof checkpoint) |
| 3.4 | Low | Straightforward |
| 3.5 | Medium | Triple-registration required; governance-change coupling must be conditional on diff |
| 3.6 | Medium | Must remain distinct gate from 2.16.10 |
| 3.7 | High | Circular dependency; PR-scope mapping must be defined before coding; no gate duplication |

---

### **3.8 — Handoff Idempotency Enforcement (NEW, mandatory)**

**Deliverable:** `handoff` is idempotent — running it twice on a clean tree produces zero diffs.

**DoD (all must be true):**

1. On clean main with committed truth artifacts, `npm run handoff` produces zero diffs (`git status --porcelain` is empty after run).
2. Running `npm run handoff` twice back-to-back produces identical output (second run = zero diffs).
3. Root causes fixed:
   - `generated/schema.sql` output is deterministic (stable sorting, no timestamps, consistent encoding)
   - `generated/contracts.snapshot.json` output is deterministic
   - `docs/handoff_latest.txt` does not self-reference (no `git status` captured after its own writes)
4. Gate asserts idempotency: after handoff runs, `git status --porcelain` must be empty on a tree where artifacts are already committed.
5. `ship` can now meaningfully verify: on clean main, `npm run handoff && git status --porcelain` returns empty.

**Section 3.0 constraints apply:**
- One enforcement surface per PR
- green:once + green:twice before proof
- ship remains verify-only

**Proof:** `docs/proofs/3.8_handoff_idempotency_<UTC>.log`

**Gate:** `handoff-idempotency` (merge-blocking)

---

## **3.9 Pre-Section-4 Bridge Hardening**

**Status:** LOCKED pending merge
**Scope:** Post-Section-3-seal, pre-Section-4-entry
**Authority:** Section 3.0 constraints apply to all sub-items
**Execution order:** 3.9.1 → 3.9.2 → 3.9.3 → 3.9.4 → 3.9.5 → 3.9.6
**Section 4 entry condition:** All six sub-items merged and `ship` passes
on main with zero diffs before Section 4 is declared open.

---

## Governance Position

Section 3 was formally closed per the DEVLOG entry dated 2026-02-21.
Items 3.9.1–3.9.6 are **addenda to Section 3**, not a reopening of it.
They close structural blind spots identified during the Section 3
adversarial review. The "Section 3 Closed" DEVLOG entry documents the
state of 3.1–3.8. A second DEVLOG entry — **"Section 3.9 Bridge Closed"**
— must be added after all sub-items are merged to record the completed
bridge state. Section 4 may not be declared open until that second
entry exists.

---

## 3.9.0 — Bridge Execution Constraints (LOCKED)

These constraints apply to all items 3.9.1 through 3.9.6 without exception.

### 1. Scope Boundary

Items 3.9.1–3.9.6 close structural blind spots identified during
Section 3 adversarial review. They are automation and governance layer
work only. They do not touch DB schema, migrations, or RLS policies.
Any PR that touches those surfaces is out of scope for this block
and belongs in Section 6+.

### 2. PR Isolation

All Section 3.0 PR isolation rules apply:
- One enforcement surface per PR.
- One objective per PR.
- No bundling of any two sub-items into a single PR.

### 3. Self-Validation Discipline

All PRs in this block must complete:

    green:once
    green:twice

with no edits between runs before proof generation.
This applies even to sub-items characterized as low-risk.

### 4. Truth Artifact Registration (Triple Registration Rule)

Any new truth artifact introduced in this block must satisfy §3.0.4
in the same PR:

    a. Registered in robot-owned guard.
    b. Included in truth-bootstrap or equivalent validation gate.
    c. Included in handoff regeneration surface if machine-derived.
       If hand-authored, state the §3.0.4c exemption explicitly in the DoD.

### 5. Section 4 Entry Gate

Section 4 may not be declared open until all sub-items 3.9.1–3.9.6
are merged, the "Section 3.9 Bridge Closed" DEVLOG entry exists,
and `ship` passes on main with zero diffs.

### 6. Governance Change Guard Trigger

Any PR in this block that modifies a governance-surface file — including
`docs/artifacts/SOP_WORKFLOW.md`, `docs/artifacts/AUTOMATION.md`,
`docs/artifacts/GUARDRAILS.md`, `.github/workflows/**`,
`docs/truth/**`, or `scripts/ci_*.ps1` — must include a
`docs/governance/GOVERNANCE_CHANGE_PR<NNN>.md` file. This is not
optional. Failure to include it will produce a red governance-change-guard
gate. Pre-declare this requirement in the PR description before coding begins.

### Rationale

These items harden the governance and automation layer before the first
live DB work begins in Section 4. Stub debt must be declared, scope gaps
must be closed, the proof chain must be exfiltration-hardened, and
governance coverage must be auditable before any Supabase output enters
the proof record. These are structural prerequisites for honest Section 4
entry, not optional hardening.

---

## 3.9.1 — Deferred Proof Registry

**Objective**
Establish a machine-readable registry that explicitly catalogs every CI
gate currently passing as a DB-heavy stub — recording what invariant
each defers and what Build Route item triggers conversion — so that
stub-passing gates cannot be silently interpreted as security evidence.

**Rationale**
The handoff checkpoint confirms `stack_running: false`. Multiple
merge-blocking gates pass CI in this state via DB-heavy stubs
(confirmed: `handoff-idempotency`, `definer-safety-audit`,
`schema-drift`, `clean-room-replay`, `pgtap`). No artifact currently
exists that distinguishes a stub-passing gate from a live-verified gate.
Without this registry, Section 4+ work inherits a growing body of
formally-green but security-unverified claims. Build Route 8.0 exists
to convert all stubs to live gates — this item ensures that conversion
is tracked and cannot be silently skipped.

Additionally, AUTOMATION.md §2 lists `database-tests.yml` as a required
merge-blocking workflow, but the handoff checkpoint confirms it does not
exist. This is a live compliance gap. It must be catalogued in the
registry as a deferred item (conversion trigger: Section 6 / 8.0)
rather than left as a silent mismatch between the governance doc and
repo reality.

**Deliverable**
`docs/truth/deferred_proofs.json` — a machine-readable catalog of every
current DB-heavy stub gate, with its deferred invariant and conversion
trigger.

**DoD (all must be true)**

1. `docs/truth/deferred_proofs.json` exists with one entry per current
   DB-heavy stub gate, containing exactly these fields:
   - `gate` — job name string-exact as it appears in `required_checks.json`
   - `stub_reason` — one sentence: why this gate runs as a stub today
   - `deferred_invariant` — one sentence: what security or correctness
     property this gate does NOT currently prove
   - `conversion_trigger` — the Build Route item whose closure converts
     this stub to a live gate (e.g. `"8.0"`)

2. `docs/truth/deferred_proofs.schema.json` exists and validates the
   structure of `deferred_proofs.json`. The gate fails if JSON is
   invalid or missing required fields.

3. A CI gate (`deferred-proof-registry`) fails if any job listed in
   `required_checks.json` is declared db-heavy in the CI YAML
   but has no corresponding entry in `deferred_proofs.json`.
   The known-stub list is derived from the explicit `db-heavy`
   pattern in CI YAML — not inferred heuristically.

4. Future stub gates are self-declaring: any PR that introduces a new
   DB-heavy stub gate must include the corresponding `deferred_proofs.json`
   entry in the same PR. The `deferred-proof-registry` gate enforces
   this by failing if a CI YAML job is marked db-heavy without a
   registry entry. This closes the future-stub gap without relying on
   human discipline.

5. When Build Route 8.0 converts a stub to a live gate, the
   corresponding registry entry must be removed in that same PR.
   The `deferred-proof-registry` gate fails if a converted gate
   (i.e., one no longer marked db-heavy in CI YAML) still has
   a registry entry.

6. The AUTOMATION.md §2 compliance gap (`database-tests.yml` declared
   required but absent) is catalogued as a deferred entry with
   `conversion_trigger: "6.0/8.0"`. The entry is hand-authored.
   Resolution requires either creating the workflow (Section 6+)
   or correcting AUTOMATION.md §2 via a governance-change PR.
   This item does not resolve the gap — it makes it visible and tracked.

7. `docs/truth/deferred_proofs.json` is hand-authored (initial contents
   seeded from CI YAML inspection, then maintained manually as stubs are
   converted). §3.0.4c exemption applies: this file is not machine-derived
   and is not included in the handoff regeneration surface.
   This exemption is stated explicitly here and in the DoD to satisfy
   the Triple Registration Rule.
   Registrations required: (a) robot-owned guard, (b) truth-bootstrap.

8. `docs/truth/deferred_proofs.schema.json` is similarly hand-authored.
   Same §3.0.4c exemption applies. Same registrations required.

9. The proof explicitly lists every stub gate cataloged and confirms
   each entry validates against the schema.

**Pre-implementation check**
Inspect `.github/workflows/ci.yml` for all jobs carrying the `db-heavy`
marker before writing any code. Capture the exhaustive list. This is
the authoritative input for the initial registry contents. Do not infer
stub status from job names. Derive it from the explicit db-heavy gating
pattern in CI YAML only.

**Proof:** `docs/proofs/3.9.1_deferred_proof_registry_<UTC>.log`

**Gate:** `deferred-proof-registry` (merge-blocking)

**Section 3.0 constraints apply.**

---

## 3.9.2 — Governance Path Coverage Audit

**Objective**
Mechanically assert that `governance_change_guard.json` path matchers
cover every governance-surface file currently in the repo — closing the
class of bypass where new governance-surface paths silently escape
the guard.

**Rationale**
The governance-change-guard is merge-blocking and regression-validated.
However the guard only protects paths it knows about. This failure mode
was confirmed in production: Foundation paths were omitted from the
matcher, allowing silent governance mutation. There is currently no gate
that audits the *coverage* of the guard's path scope. A new script or
config file type not added to the matcher bypasses the guard with no CI
failure.

**Deliverable**
A gate that fails if any governance-surface file exists in the repo
that is not covered by any path matcher in `governance_change_guard.json`,
plus an explicit versioned definition of what constitutes the governance
surface.

**DoD (all must be true)**

1. `docs/truth/governance_surface_definition.json` exists with an
   explicit versioned list of path patterns that define the governance
   surface. This file is the authoritative definition — the coverage
   gate checks against it, not against heuristics or naming conventions.
   Required fields per entry:
   - `pattern` — glob pattern string
   - `rationale` — one sentence explaining why this path is governance
   - `version` — incremented when the definition changes

2. The definition covers at minimum these path classes:
   - `scripts/ci_*.ps1` and `scripts/ci_*.mjs`
   - `.github/workflows/**`
   - `docs/truth/**`
   - `docs/governance/**`
   - `docs/artifacts/SOP_WORKFLOW.md`
   - `docs/artifacts/AUTOMATION.md`
   - `docs/artifacts/GUARDRAILS.md`

3. **`package.json` governance scope — explicit decision required.**
   `package.json` defines npm scripts and is modified in many PRs.
   One of the following three options must be chosen and documented
   in the PR description before coding begins:

   - **Option A (Content-filtered scope):** `package.json` is in
     governance scope, but the guard applies content-level filtering —
     it triggers only when the `scripts` section changes. This requires
     the governance-change-guard to support content-level filtering,
     which must be proven in the same PR.
   - **Option B (Excluded from governance scope):** `package.json`
     is explicitly excluded from the governance surface definition
     with a documented rationale. npm script changes become
     unguarded; this risk must be acknowledged in the rationale field.
   - **Option C (Full-path scope):** `package.json` is in governance
     scope with full-path matching, meaning any PR that touches
     `package.json` must include a governance-change file. This is
     high-friction and must be explicitly accepted.

   The chosen option is recorded in `governance_surface_definition.json`
   as either an entry (Options A or C) or an explicit exclusion record
   (Option B). Leaving this undecided causes governance fatigue and
   silent bypass — it must be resolved before the gate passes.

4. A gate script enumerates all files in the repo matching the
   governance surface definition and cross-references against
   `governance_change_guard.json` path matchers. The gate fails if any
   governance-surface file is not covered by at least one matcher.

5. Gate output on failure lists every uncovered path by name — not
   just a count.

6. `governance_change_guard.json` is updated in this same PR to cover
   any currently uncovered paths before the gate passes for the first
   time.

7. `governance_surface_definition.json` is itself a governance artifact.
   It is added to `governance_change_guard.json` path scope so that
   any future change to the definition triggers governance-change-guard.

8. **Bootstrap trigger:** This PR modifies `governance_change_guard.json`
   and `governance_surface_definition.json` — both governance-surface
   files. Therefore this PR triggers the governance-change-guard and must
   include `docs/governance/GOVERNANCE_CHANGE_PR<NNN>.md`. Pre-declare
   this in the PR description.

9. `governance_surface_definition.json` is hand-authored and satisfies
   §3.0.4c exemption (not machine-derived).
   Registrations required: (a) robot-owned guard, (b) truth-bootstrap.

10. Gate (`governance-path-coverage`) is merge-blocking.

**Pre-implementation check**
Run the enumeration script against the current repo before writing
any gate logic. Capture the full list of currently uncovered paths.
This becomes the initial gap list in the proof log. Do not attempt to
fix uncovered paths and write the gate simultaneously. Enumerate first,
fix the coverage gaps in `governance_change_guard.json`, then write and
pass the gate — all within the same PR but in that documented order.

**Proof:** `docs/proofs/3.9.2_governance_path_coverage_<UTC>.log`

**Gate:** `governance-path-coverage` (merge-blocking)

**Section 3.0 constraints apply.**

---

## 3.9.3 — QA Scope Map Coverage Enforcement

**Objective**
Assert that `qa_scope_map.json` has an entry for every Build Route item
that has been merged into main, and prove that `qa:verify` fails
deterministically on a missing proof — closing the blind spot where an
unmapped item trivially passes the meta-gate.

**Rationale**
`qa:verify` (3.7) validates proof completeness only for items that have
an entry in `qa_scope_map.json`. Any item with no scope map entry
requires nothing and trivially passes. The scope map is human-authored
and no gate detects missing entries. Additionally, the 3.7 DEVLOG
confirms `qa:verify` passes on good proofs but does not document a
deliberate-failure regression test confirming it fails on missing proofs.
Both gaps are closed here.

**DEVLOG format prerequisite**
The existing DEVLOG format uses inconsistent status strings:
`Status: PASS`, `Status: COMPLETE`, and `* PASS` all appear across
entries. Free-text status detection is not acceptable per DoD item 1.
Before writing the coverage gate, a DEVLOG format constraint must be
established. This is a governance artifact change and requires its own
governance-change PR if the DEVLOG format amendment cannot be scoped
entirely within this PR.

**Decision required before coding begins:** Determine whether the DEVLOG
format correction can be scoped as a prerequisite sub-step within this
PR (documented explicitly in the PR description and DoD before any code
is written), or whether it requires a prior standalone governance PR.
Attempting to resolve this mid-implementation is a Section 3.0 violation.

**DoD (all must be true)**

1. **DEVLOG parsing contract is defined and implemented before the
   coverage gate is written.**
   The parsing approach must be one of:
   - A structured machine-readable status block in DEVLOG entries
     using a contract-validated format, OR
   - A separate machine-readable status registry file that DEVLOG
     entries reference.
   If the DEVLOG format requires amendment, that amendment is either
   included as a documented sub-step in this PR or completed in a
   prior standalone governance PR. The choice is declared in the
   PR description. Free-text detection of status strings is forbidden.

2. If the DEVLOG format is amended in this PR, the amended format
   applies to all future entries. Existing entries are not retroactively
   modified — the parser must handle both legacy format (alert-only)
   and new format (authoritative for coverage checking).

3. A gate script (`scripts/ci_qa_scope_coverage.ps1` or equivalent)
   reads the completed item list per the parsing contract and
   cross-references against `qa_scope_map.json`. Gate fails if any
   completed item has no scope map entry.

4. Gate output on failure names every unmapped completed item
   explicitly — not just a count.

5. `qa_scope_map.json` is updated in this same PR to include entries
   for all currently completed items before the gate passes for the
   first time.

6. If the DEVLOG format changes in the future, the gate fails loudly
   on an unrecognized format — not silently passes. This behavior is
   asserted in the proof.

7. **Deliberate-failure regression proof (complete sequence required):**
   - One `qa_scope_map.json` entry is temporarily removed on a local branch.
   - `npm run qa:verify` is run.
   - FAIL is confirmed. The output is captured and must name the
     missing item explicitly — not just exit non-zero.
   - The entry is restored.
   - `npm run qa:verify` is run again.
   - PASS is confirmed.
   - The full sequence (remove → fail output showing item name →
     restore → pass output) is included in the proof log.

8. Gate (`qa-scope-coverage`) is merge-blocking.

9. Triple Registration Rule §3.0.4 applies to any new truth artifacts
   introduced by this item.

**Pre-implementation check**
Read the existing DEVLOG format before writing any code. Confirm whether
the current format supports deterministic status parsing. Document the
finding in the PR description before any code is written. Do not assume
the format is parseable. Prove it or define the fix first.

**Proof:** `docs/proofs/3.9.3_qa_scope_coverage_<UTC>.log`

**Gate:** `qa-scope-coverage` (merge-blocking)

**Section 3.0 constraints apply.**

---

## 3.9.4 — Job Graph Ordering Verification

**Objective**
Prove that `lane-enforcement` is a provable prerequisite of
`docs-only-ci-skip` in the CI job dependency graph — closing the
structural race where a governance-touching PR miscategorized as
docs-only has its required governance checks skipped before lane
classification can catch the error.

**Rationale**
`docs-only-ci-skip` (2.7) intentionally skips DB-heavy jobs on
docs-only PRs. `lane-enforcement` (2.16.7) classifies PRs by lane
and asserts required checks. If `docs-only-ci-skip` runs before
`lane-enforcement` in the job graph, a governance-touching PR
miscategorized as docs-only will have its governance checks skipped
before lane enforcement fires. The ordering of these two jobs has never
been explicitly verified or documented.

**Deliverable**
A structural graph validation confirming that `lane-enforcement` is a
provable prerequisite of `docs-only-ci-skip`, with a CI gate asserting
this ordering is maintained in perpetuity.

**DoD (all must be true)**

1. A gate script (`scripts/ci_job_graph_contract.ps1` or equivalent)
   parses `.github/workflows/ci.yml` using a proper YAML parser — not
   grep or regex string matching. The script constructs the actual job
   dependency graph from `needs:` declarations and walks it.

2. The script asserts the following safe ordering — listed in preference
   order. Option A is strongly preferred:

   - **Option A (preferred):** `docs-only-ci-skip` has `lane-enforcement`
     in its `needs:` array (direct dependency). This is a true ordering
     guarantee in the GitHub Actions scheduling model.
   - **Option B (acceptable with caveat):** `docs-only-ci-skip` is gated
     on the output of `lane-enforcement` via an `if:` condition referencing
     `jobs.lane-enforcement.result`. This provides a runtime gate but not
     a strict scheduling guarantee — both jobs may start in the same
     scheduling wave. If Option B is chosen, this limitation must be
     documented in the proof and in `governance_surface_definition.json`.

   String-matching against YAML text does not satisfy this requirement.
   The assertion must be graph-theoretic (walk the `needs:` graph).

3. Gate output prints the full resolved dependency chain for both jobs —
   not just pass/fail. On failure, it prints the actual ordering found
   and why it is unsafe.

4. **If the current CI YAML does not satisfy the ordering requirement,
   it is corrected in this same PR.** Only the job ordering is touched —
   no other CI changes are in scope.

   **Section 3.0 compliance note:** Modifying CI YAML job ordering is a
   governance-surface change and constitutes a second enforcement surface
   in the same PR as the gate script. This is permitted only because the
   YAML correction is a direct prerequisite for the gate to pass — not an
   independent objective. The PR description must explicitly state this
   dependency and scope it to ordering-only. Any CI YAML change beyond
   job ordering re-ordering is out of scope and belongs in a separate PR.

5. The proof documents which ordering option was chosen (A or B) and why.
   The choice is treated as a governance decision — documented, not
   implicit.

6. Gate (`job-graph-ordering`) is merge-blocking for any PR touching
   `.github/workflows/**`.

**Pre-implementation check**
Before writing any code, manually inspect the current `needs:` declarations
for `docs-only-ci-skip` and `lane-enforcement` in `ci.yml`. Document the
current state in the PR description.
- If the current state already satisfies Option A or B: this item is
  proof-only. Prove the existing ordering satisfies DoD without changing
  CI YAML.
- If the current state is unsafe: scope the YAML correction explicitly
  in the PR description before coding begins.

**Proof:** `docs/proofs/3.9.4_job_graph_ordering_<UTC>.log`

**Gate:** `job-graph-ordering` (merge-blocking, governance-surface)

**Section 3.0 constraints apply.**

---

### **3.9.5 — Proof Secret Scan**

**Objective**
Harden `proof:finalize` to reject proof log files containing strings
matching defined secret patterns before they enter the append-only
proof chain — preventing secrets from becoming permanently embedded
in `manifest.json`.

**Rationale**
PowerShell `Write-Error` and `Write-Host` paths in CI scripts can
inadvertently interpolate `$env:*` variables (including
`SUPABASE_SERVICE_ROLE_KEY`) into verbose error output. Proof logs are
append-only once finalized and hashed into `manifest.json`. A secret
captured in a proof log cannot be removed without breaking the proof
chain. Section 4 will produce the first proofs containing live Supabase
output — `supabase status`, cloud inventory captures, and toolchain
verification commands that may expose connection strings or keys. The
path-leak audit (2.17.3) covers absolute path disclosure but does not
cover secret value interpolation. This item is additive and does not
replace or overlap 2.17.3.

**This item must be merged before the first Section 4 proof is
finalized.** Section 4.2 (`supabase status` output) is the first proof
expected to contain live Supabase connection output. 3.9.5 must be on
main before that proof is generated.

**Deliverable**
A pre-finalization secret scan integrated into `proof:finalize` that
fails before normalizing or writing to manifest if any defined secret
pattern is matched in the proof log content.

**DoD (all must be true)**

1. `docs/truth/secret_scan_patterns.json` exists with the following
   initial pattern set — and only this set:
   - Supabase service role key format: the known static JWT header prefix
     (`eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9`) that prefixes all
     Supabase service role JWTs.
   - Postgres connection string: structural match on `postgresql://` or
     `postgres://` scheme prefix.
   - Supabase personal access token: structural match on `sbp_` prefix.

   No other patterns are included in the initial set.
   No entropy-based or generic "long random string" heuristics.
   No general three-segment base64 matching (this would false-positive
   on migration hashes, proof file content, and other legitimate outputs).

2. Each entry in `secret_scan_patterns.json` contains:
   - `name` — human-readable pattern class name
   - `pattern` — the structural match expression
   - `false_positive_analysis` — one sentence documenting what
     legitimate content this pattern could match and why it is safe
   - `rationale` — one sentence explaining what secret type this detects

3. `scripts/proof_finalize.ps1` is hardened to run the secret scan
   against the proof log file content before normalizing encoding or
   writing to manifest. If any pattern matches, the script:
   - Exits non-zero.
   - Prints the matched pattern `name` only — not the matched value
     and not the surrounding text.
   - Prints the line number of the match.
   - Does NOT write to manifest.
   - Does NOT normalize the file.

   **Output sufficiency note:** Line number alone may be insufficient
   for the operator to locate and redact the source without re-reading
   the full proof log. The script should additionally print a sanitized
   excerpt: the matched line with all characters between position 5 and
   the last 4 replaced with `****` — enough to confirm which pattern
   fired without exposing the secret value. This behavior is asserted
   in the deliberate-failure proof.

4. **Deliberate-failure regression proof (complete sequence required,
   one per pattern):**
   A proof log file containing a test string matching each of the three
   initial patterns is run through `proof:finalize`. FAIL is confirmed
   for each. For each failure, the proof log captures: the exit code,
   the printed pattern name, the line number, and the sanitized excerpt.
   The full sequence is included in the proof log.

5. **False-positive regression proof:**
   A proof log file containing a legitimate base64 migration hash, a
   legitimate proof manifest hash, and a legitimate UTC timestamp string
   is run through `proof:finalize`. PASS is confirmed — none of the
   three patterns false-positive on these inputs.

6. Adding new patterns to `secret_scan_patterns.json` requires a
   governance-change PR (the file is in governance-guard scope) and must
   include a false-positive analysis for each new pattern. This
   constraint is documented in `docs/artifacts/AUTOMATION.md` as part
   of this item.

7. `docs/artifacts/AUTOMATION.md` is updated in this PR to document
   the secret scan step and the pattern governance policy.
   `docs/artifacts/SOP_WORKFLOW.md` is updated to document the
   hardened `proof:finalize` behavior.

   **Governance guard trigger:** Both `AUTOMATION.md` and
   `SOP_WORKFLOW.md` are governance-surface files. This PR triggers
   the governance-change-guard and must include
   `docs/governance/GOVERNANCE_CHANGE_PR<NNN>.md`. Pre-declare this
   in the PR description.

8. `secret_scan_patterns.json` is hand-authored. §3.0.4c exemption
   applies (not machine-derived).
   Registrations required: (a) robot-owned guard, (b) truth-bootstrap.

9. The hardening of `proof:finalize` is the only script enforcement
   surface in this PR. No other scripts are modified.

**Pre-implementation check**
Verify the three initial patterns do not false-positive against any
existing proof log in `docs/proofs/**` before writing any code. If any
false-positive is found, resolve it before implementation begins —
either by tightening the pattern or by documenting why the matching
content is acceptable and must be cleaned. Document this verification
result in the PR description.

**Proof:** `docs/proofs/3.9.5_proof_secret_scan_<UTC>.log`

**Gate:** Pre-finalization enforcement built into `proof:finalize`.
No separate CI job. Downstream enforcement is `proof-manifest` —
a failed finalize produces no manifest entry, which causes
`proof-manifest` to fail on the next CI run.

**Section 3.0 constraints apply.**

---

### **3.9.6 — Section 3.9 Bridge Close Verification**

**Objective**
Verify all Section 3.9 sub-items are complete and main is stable before
Section 4 is declared open.

**This item is verification-only. No implementation changes.**

**Verification sequence (per SOP §17):**

    git checkout main
    git pull
    git status              → clean
    npm run pr:preflight    → PASS
    npm run ship            → PASS, zero diffs
    npm run handoff         → zero diffs (idempotency check)
    git status              → still clean
    npm run green:twice     → PASS

**DoD (all must be true)**

1. All sub-items 3.9.1–3.9.5 have merged PRs with QA APPROVE.
2. DEVLOG entries exist for every sub-item.
3. The verification sequence above passes without error.
4. `docs/truth/required_checks.json` is current — no phantom or missing
   gates relative to the new gates introduced in this block.
5. The deferred proof registry (3.9.1) is current — all db-heavy stub
   gates are catalogued.
6. Governance path coverage (3.9.2) passes — no uncovered governance
   paths.

**DEVLOG entry format:**

    YYYY-MM-DD — Build Route v2.4 — Section 3.9 Bridge Closed

    Objective
    Verify all Section 3.9 sub-items complete and main is stable
    per SOP §17.

    Changes
    No implementation changes. Verification only.

    Verification evidence
    - git status: clean
    - pr:preflight: PASS
    - ship: PASS, zero diffs
    - handoff: zero diffs
    - green:twice: PASS
    - required_checks.json: current
    - deferred_proofs.json: current
    - governance-path-coverage: PASS

    Status: COMPLETE

**Proof:** No separate proof artifact required. The DEVLOG entry and
the verification command outputs (captured in that entry) constitute
the proof for this item.

**Gate:** Enforced by existing `ship`, `green:twice`, and
`required-checks-contract` gates. No new gate introduced.

---

## Section 3.9 Completion Checklist

| Item  | Title                            | Gate                        | Status |
|-------|----------------------------------|-----------------------------|--------|
| 3.9.1 | Deferred Proof Registry          | deferred-proof-registry     | OPEN   |
| 3.9.2 | Governance Path Coverage Audit   | governance-path-coverage    | OPEN   |
| 3.9.3 | QA Scope Map Coverage            | qa-scope-coverage           | OPEN   |
| 3.9.4 | Job Graph Ordering Verification  | job-graph-ordering          | OPEN   |
| 3.9.5 | Proof Secret Scan                | proof:finalize hardening    | OPEN   |
| 3.9.6 | Bridge Close Verification        | existing gates (no new)     | OPEN   |

**Execution order:** 3.9.1 → 3.9.2 → 3.9.3 → 3.9.4 → 3.9.5 → 3.9.6

**Section 4 entry condition:**
All items above show DONE, main is clean,
"Section 3.9 Bridge Closed" DEVLOG entry exists,
`ship` passes with zero diffs, `green:twice` passes.

---

## **4 — Fresh Supabase Project Baseline (No Reuse)**

### **4.1 Create brand-new Supabase project**

Deliverable:  
Fresh project ref, no imports.  
DoD:  
New project is created and project ref is captured in proof.  
Proof asserts no legacy schema/data import occurred.  
Proof: docs/proofs/4.1\_cloud\_baseline\_.md  
Gate: lane-only cloud-baseline

### **4.2 — Deliverable: Supabase Toolchain Contract**

DoD: CI hard-fails on any mismatch for Supabase CLI \+ psql versions against docs/truth/toolchain.json.  
Proof: docs/proofs/4.2\_toolchain\_versions\_supabase\_.log  
Gate: toolchain-contract-supabase (merge-blocking)

### **4.2a Command Smoke (DB lane) (mandatory)**

**Deliverable:** DB-coupled commands run end-to-end.  
**DoD:** On a machine with Supabase running, these complete without crash:

* `green:once`  
* `green:twice`  
* `handoff` *(may write artifacts)*
* `ship` *(verify-only; must produce zero diffs on main)*

**Proof:** `docs/proofs/4.2a_command_smoke_db_<UTC>.log`  
**Gate:** lane-only `command-smoke-db` (promote to merge-blocking only after stable)

### **4.3 — Cloud Baseline Inventory (DB-metadata lane) [HARDENED]**

Deliverable:
Baseline inventory is real, schema-validated, and pins critical
Supabase infrastructure versions alongside the existing inventory.
DoD additions (appended to existing 4.3 DoD):

Inventory captures PostgREST version and Supabase Auth version from
the live cloud project (response headers or /_internal/health
equivalent).
docs/truth/toolchain.json is extended to include postgrest_version
and supabase_auth_version fields.
Version capture and pinning runs in the cloud-inventory lane only.
It requires live cloud credentials and is not part of the
merge-blocking toolchain-contract-supabase gate, which covers local
toolchain assertions only and is not extended by this item.
A new lane-only gate (cloud-version-pin) asserts PostgREST and Auth
versions match pinned truth when cloud credentials are present. Gate
fails if either version drifts from pinned values, naming the service
and the expected vs found version.
Proof explicitly records which assertions ran in which lane (local vs
cloud) and shows both version values captured and pinned.

Proof: docs/proofs/4.3_cloud_baseline_inventory_<UTC>.log
Gate: toolchain-contract-supabase (merge-blocking, local assertions
only — unchanged) + cloud-version-pin (lane-only, cloud assertions).

---

### **4.4 — anon Role Default Privilege Audit (REVISED)**

#### Deliverable

Explicit proof that:

1. `anon` holds zero privileges on all core tables through any path.
2. `authenticated` holds exactly the controlled exception privileges defined in CONTRACTS.md §12.
3. Default privileges for new objects in schema `public` are private-by-default for all operator-owned roles.

---

#### DoD

##### A. Direct Object-Level Privilege Audit (Materialization Check)

* `docs/truth/anon_privilege_truth.json` exists and is generated from a live database catalog query.
* Gate asserts zero `anon` privileges on every core table named in CONTRACTS.md §12:

  * `tenants`
  * `tenant_memberships`
  * `tenant_invites`
  * `deals`
  * `documents`
* Gate asserts zero `anon` privileges on `user_profiles`.
* Gate asserts `authenticated` holds exactly `SELECT` and `UPDATE` on `user_profiles` — no more, no less.
* Gate fails if any privilege exists outside the CONTRACTS.md §12 controlled exception.

Authority: CONTRACTS.md §12 (privilege firewall evaluated on final database state).

---

##### B. Default Privilege Posture — Operator-Owned Roles

* Gate queries `pg_default_acl` for entries where `defaclrole` resolves to:

  * `postgres`
  * Any application-owned role created via migrations
* Gate fails if any such entry grants privileges to:

  * `anon`
  * `authenticated`
    on schema `public`.

This enforces private-by-default posture for all roles that create repo-owned objects.

---

##### C. Platform-Managed Role Carve-Out (Supabase Boundary)

* Roles matching `supabase_%` are explicitly excluded from the default ACL cleanliness requirement.
* Rationale:

  * These roles are platform-managed superusers.
  * Migrations do not execute as these roles.
  * PostgreSQL default privileges apply only to objects created by the owning role.

Exclusion is valid only if materialization proof confirms:

* No object-level privileges exist for `anon` or `authenticated`
* On any `public` schema object created by our migrations

If materialization is detected, the carve-out is invalid and the gate fails.

---

##### D. Gate Failure Requirements

Gate must fail naming:

* Object
* Privilege type
* Source (direct grant vs default ACL)
* Role
* CONTRACTS.md section violated

---

##### E. Truth Artifact Requirements

`anon_privilege_truth.json` must be:

* Machine-derived from live catalog queries
* Registered in robot-owned guard
* Included in truth-bootstrap validation gate
* Included in handoff regeneration surface

Triple Registration Rule applies in full.

---

##### F. Proof Log Authoring Requirement (STUB_GATES_ACTIVE)

Proof log must include STUB_GATES_ACTIVE block per SOP requirements if stub gates remain active at proof time.

---

#### Proof

`docs/proofs/4.4_anon_privilege_audit_<UTC>.log`

---

#### Gate

`anon-privilege-audit`
(merge-blocking, DB/runtime lane)

---

### **4.5 — Tenancy Resolution Contract Enforcement (NEW)**

Deliverable:
Mechanical detection of forbidden tenant resolution patterns in
migrations. The resolution strategy itself is already frozen in
CONTRACTS.md §3 and is not re-adjudicated here.
DoD:

scripts/ci_rls_strategy_lint.ps1 (or equivalent) scans all RLS
policies in supabase/migrations/** and fails on either of the two
forbidden patterns:

Raw auth.uid() or auth.jwt() used directly to resolve tenant
context. All tenant resolution must use current_tenant_id() or
the approved helper per CONTRACTS.md §3.
Inline JWT claim parsing for tenant ID within a policy body.


Gate does NOT validate the full resolution logic structure. It detects
only the two forbidden patterns above. The authoritative resolution
order (profile → app.tenant_id → JWT) is frozen in CONTRACTS.md §3
and is not re-defined by this gate.
Gate output references CONTRACTS.md §3 as the authority.
Gate fails naming the migration file, the policy name, and which
forbidden pattern was matched.

Proof: docs/proofs/4.5_tenancy_resolution_enforcement_<UTC>.log
Gate: rls-strategy-consistent (merge-blocking, migration lane).

---

### **4.6 — Two-Tier CI Execution Contract (NEW)**

**Deliverable:** Machine-readable truth defining Tier 1 (Pooler/Stateless) and Tier 2 (Direct/Sessionful) execution constraints to prevent session-state tests from silently failing.
**DoD:**
* `docs/truth/ci_execution_surface.json` exists, defining the two tiers.
* Tier 1 explicit ban list: Gate scripts executing via the pooler must not use `SET`, `SET LOCAL`, temporary tables/schemas, advisory locks, or prepared statements/cursors.
* Existing gates (4.4 and 4.5) are explicitly registered as Tier 1 to validate them retroactively.
* Triple Registration Rule applies.
**Proof:** `docs/proofs/4.6_two_tier_execution_contract_<UTC>.log`
**Gate:** `merge-blocking` (enforced via `truth-sync-enforced`).

---

### **4.7 — Tier-1 Gate Surface Normalization**

## Objective

Normalize the CI enforcement surface so that every Tier-1 gate declared in `docs/truth/ci_execution_surface.json` is:

* Implemented as a top-level GitHub Actions job
* Explicitly merge-blocking via inclusion in the `required:` job `needs:` list
* Topology-deterministic and audit-visible

No gate logic changes permitted.
No enforcement semantic changes permitted.
No renaming of existing required check contexts permitted.

---

## Deliverables

1. Extract any Tier-1 gate currently implemented only as a step inside another job into its own top-level GitHub Actions job.

2. Ensure every Tier-1 job ID is explicitly listed in the `required:` job `needs:` block.

3. Remove embedded-only execution of Tier-1 gates (no gate may exist solely as a step inside another job).

4. Verify that required check contexts remain string-exact stable (no branch protection drift).

5. Ensure `truth:sync` (or equivalent required-check truth generator) produces no unintended diff after topology normalization.

---

## Definition of Done (DoD)

All must be true:

* CI run displays a distinct top-level job row for every Tier-1 gate.
* `required` cannot pass unless all Tier-1 jobs pass.
* No Tier-1 gate exists only as an embedded step.
* Required check contexts remain valid and unchanged.
* CI green twice with no edits between runs.

---

## Proof

Proof artifact must include:

* Printed `required.needs` block showing all Tier-1 job IDs.
* CI run output showing each Tier-1 job as a separate row.
* Confirmation that no Tier-1 gates remain embedded-only.
* Output of `truth:sync` showing no unintended required-check drift.

Proof must follow canonical proof discipline:

* `<UTC>.log`
* `proof:finalize`
* No non-proof changes after PROOF_HEAD

---

## Gate

Merge blocked unless:

* All Tier-1 jobs pass.
* `required` job passes.
* Proof-commit-binding passes.
* CI topology validation passes.

---

## Non-Goals

This item does NOT:

* Promote Tier-2 gates.
* Modify DB-heavy execution logic.
* Change enforcement semantics.
* Rename existing required check contexts.
* Refactor CI for aesthetics.

---

## **5 — Governance Gates (CI required-now)**

### **5.0 — Required Gates Inventory [HARDENED]**

DoD additions (appended to existing 5.0 DoD):

The following new gates are added to docs/truth/required_checks.json
each in the PR that creates the corresponding CI job — not in a batch
update. No gate may be registered before its CI job exists string-exact
in .github/workflows/**.

anon-privilege-audit (registered in 4.4 PR)
rls-strategy-consistent (registered in 4.5 PR)
migration-rls-colocation (registered in 5.1 PR)
unregistered-table-access (registered in 6.3A PR)
calc-version-registry (registered in 7.6 PR)


Each registration PR triggers the governance-change-guard and must
include docs/governance/GOVERNANCE_CHANGE_PR<NNN>.md.
npm run truth:sync must be run in each registration PR to regenerate
required_checks.json from workflow reality before submission.

---

### **5.1 — Migration RLS Co-location Lint (NEW)**

Deliverable:
A lint gate that fails if any migration creates a table without enabling
RLS and revoking default privileges in the same file — closing the
partial-migration exposure window where a table exists with RLS disabled
between steps.
DoD:

scripts/ci_migration_rls_lint.ps1 (or equivalent) asserts: any
CREATE TABLE or CREATE TABLE IF NOT EXISTS statement in a migration
file must be accompanied, in the same file, by all three of:

ALTER TABLE ... ENABLE ROW LEVEL SECURITY
REVOKE ALL ON ... FROM authenticated
REVOKE ALL ON ... FROM anon


RLS enabled in a later migration within the same PR is rejected.
Same-file co-location is required without exception.
Gate fails naming the migration file, the table name, and which of
the three required statements is missing.
Baseline migration pre-check (mandatory): Before this gate is
activated, 20260219000003_baseline_deals.sql is verified against the
co-location rule. If it does not satisfy the rule, a corrective forward
migration is authored and merged before this gate is activated.
Retroactive editing of 20260219000003 is forbidden per migration
discipline (GUARDRAILS §Forbidden: Dynamic SQL in Migrations).
The pre-check result — pass or corrective migration required — is
documented in the proof log.
Authoring constraint is documented in docs/ops/ as a standing rule
for all future migrations.

Proof: docs/proofs/5.1_migration_rls_colocation_<UTC>.log
Gate: migration-rls-colocation (merge-blocking).

---

### **5.2 — Direct IPv4 Provisioning (NEW)**

**Deliverable:** Direct DB connectivity established to unblock future Tier-2 session-state tests.
**DoD:**
* Direct IPv4 host is captured and pinned in `docs/truth/toolchain.json`.
* Smoke-test proof log confirms `psql` connectivity directly to the host, completely bypassing the session pooler.
**Proof:** `docs/proofs/5.2_direct_ipv4_provisioning_<UTC>.log`
**Gate:** Operator-run only (Configuration + truth update).

### **5.3 — Static Migration-Schema Coupling Gate (NEW)**

**Deliverable:** Merge-blocking CI gate ensuring `generated/schema.sql` is updated whenever migrations change, enforcing static coupling without requiring a live CI DB.
**DoD:**
* If a PR diff includes any changes in `supabase/migrations/**`, `generated/schema.sql` MUST be present in the diff.
* Gate fails immediately if migrations are modified but the schema artifact is not.
**Proof:** `docs/proofs/5.3_migration_schema_coupling_<UTC>.log`
**Gate:** `migration-schema-coupling` (merge-blocking).

---

## **6 — Greenfield Schema Build (REBUILD MODE)**

### **6.1 — Baseline migrations (from scratch) [HARDENED]**

**Deliverable:**
Initial baseline migrations authored new, with a local ephemeral replay proof requirement to prevent unverified schema drift during active migration authoring.

**DoD:**
* Baseline migrations exist and are authored new (no copied legacy files).
* Every migration PR must include a local operator proof log demonstrating schema correctness against a live point-in-time database.
* The operator script must spin up a clean local ephemeral DB, apply migrations in order, dump the schema deterministically, and assert the dump matches `generated/schema.sql` exactly via `git diff --exit-code`.

**Proof:**
`docs/proofs/6.1_greenfield_baseline_migrations_<UTC>.log` (Must explicitly include the local ephemeral dump and diff transcript).

**Gate:**
Operator-run local proof (verified by QA), mechanically reinforced by the `migration-schema-coupling` CI gate from 5.3. *(Note: The legacy 6.1 gates `clean-room-replay` and `schema-drift` remain stubbed until Section 8 per the revised dependency chain)*.

### **6.1A — Handoff Preconditions Hardening (DB-State Tripwire, must_contain parity)**

**Deliverable**
Harden `handoff` by adding a **DB-state** precondition gate that runs **before** truth artifact generation, upgrading from schema-text regex checks to **live database** validation of the same minimum invariants currently enforced by `must_contain`.

**DoD (all must be true)**

1. **New DB-state gate exists**

   * Script exists: `scripts/ci_handoff_preconditions.ps1` (or equivalent).
   * Gate connects to the **local** database and validates **catalog state** (tables/columns/RLS), not `generated/schema.sql` text.

2. **Minimum baseline preconditions (must_contain parity)**
   Gate asserts **all** of the following from DB-state:

   **Tables exist**

   * `public.tenants`
   * `public.tenant_memberships`
   * `public.user_profiles`
   * `public.deals`

   **Deals column requirements**

   * `public.deals.tenant_id` exists, type `uuid`, and is **NOT NULL**
   * `public.deals.row_version` exists, type `bigint`
   * `public.deals.calc_version` exists, type `integer`

   **RLS enabled**

   * RLS is enabled on `public.tenants`
   * RLS is enabled on `public.deals`

3. **Handoff integration (must run first)**

   * `npm run handoff` executes `handoff-preconditions` **before** writing any of:

     * `generated/schema.sql`
     * `generated/contracts.snapshot.json`
     * `docs/handoff_latest.txt`
   * If preconditions fail, `handoff` exits non-zero and **does not** write/overwrite truth artifacts.

4. **Failure output contract**

   * On failure, the gate prints:

     * the missing table/column/RLS state
     * the exact expected vs found state
   * Exit code is non-zero.

5. **CI wiring**

   * Workflow job exists with job id: `handoff-preconditions` (string-exact).
   * Gate is **merge-blocking** for DB/runtime lane PRs; docs-only lane may skip.

**Proof**
`docs/proofs/6.1A_handoff_preconditions_<UTC>.log`
Must include:

* PR HEAD SHA
* gate output showing each precondition PASS
* `RESULT=PASS`

**Gate**
`handoff-preconditions` (merge-blocking)

---

### **6.2 — SECURITY DEFINER Safety [HARDENED]**

Deliverable:
SD functions are allowlisted, audited, negative-tested, and statically
proven to have search_path set at the catalog level — not just in
source text.
DoD additions (appended to existing 6.2 DoD):

definer-safety-audit gate is extended to assert, for every function
on definer_allowlist.json, that pg_proc.proconfig contains a
search_path entry.
Note: pg_proc.proconfig is the correct catalog field for
function-level SET search_path declarations. pg_proc.prosrc
contains only the function body and is insufficient for this check.
Gate fails naming the function and the missing proconfig entry.
Helper functions called by SD functions are explicitly enumerated in
the proof. Each helper is confirmed to use only schema-qualified object
references — no unqualified identifiers.

---

### **6.3 — Tenant Integrity Suite [HARDENED]**

**Deliverable:**
Tenant isolation proven with negative proofs against populated data, with view and FK embedding coverage, and a catalog-validated background context review. Atomic creation of `database-tests.yml` to close the `AUTOMATION.md §2` compliance gap without producing a vacuous pass.

**DoD:**
* All negative isolation tests must seed at least 2 rows in Tenant A and 2 rows in Tenant B before asserting that Tenant A's session cannot read or write Tenant B's rows. Empty-table negative tests do not satisfy this requirement.
* Suite includes negative tests for view-based access: authenticated cannot use any view to reach another tenant's rows.
* Suite includes negative tests for FK embedding via PostgREST `?select=*,related(*)` syntax. These tests must run against a live local Supabase instance as HTTP-layer tests against the local PostgREST endpoint — pure pgTAP unit tests do not satisfy this requirement.
* `docs/truth/background_context_review.json` exists, hand-authored, listing every trigger, pg_cron job, or other function that executes outside a request context, with explicit confirmation that each has tenant parameter binding and does not rely on session-level JWT context.
* §3.0.4c exemption applies (hand-authored, not machine-derived). Triple Registration: (a) robot-owned guard, (b) truth-bootstrap.
* A gate cross-checks `background_context_review.json` against `pg_catalog` at runtime and fails if any trigger or background function exists in the catalog that is absent from the review file. This prevents the review file from silently drifting as new triggers are added.
* PR must create `.github/workflows/database-tests.yml` alongside the first real pgTAP negative tests to execute the suite.
* The `docs/truth/deferred_proofs.json` conversion triggers for **both** the `database-tests.yml` entry and the `pgtap` entry are updated to `"6.3"` in this same PR.

**Proof:**
`docs/proofs/6.3_tenant_integrity_suite_<UTC>.log`

**Gate:**
`background-context-review` (merge-blocking) + `database-tests.yml` / `pgtap` (merge-blocking CI workflow created and executed in this PR).

### **6.3A — Unregistered Table Access Gate (NEW)**

Deliverable:
Fails if any table accessible to authenticated is absent from
tenant_table_selector.json — closing the gap where a new table
receives default privileges without revocation and escapes the selector.
DoD:

Script enumerates every table in the public schema on which
authenticated holds any privilege (SELECT, INSERT, UPDATE,
or DELETE) via direct grant or default ACL.
Script cross-references the enumerated set against
tenant_table_selector.json.
Gate fails if any accessible table is absent from the selector,
naming the table and the specific privilege that exposes it.

Proof: docs/proofs/6.3A_unregistered_table_access_<UTC>.log
Gate: unregistered-table-access (merge-blocking).

### **6.4 — Tenant-Owned Table Selector [HARDENED]**

Deliverable:
Tenant-owned table definition is auditable, permissive policy patterns
are rejected by name, and full policy expression enumeration is
captured in the proof artifact.
DoD additions (appended to existing 6.4 DoD):

pgTAP suite explicitly tests and rejects the following specific
patterns on every tenant-owned table:

USING (true)
USING (1=1)
Any policy with no tenant_id predicate.
Any policy that does not include either auth.uid() or a call
to the approved tenant resolution helper (current_tenant_id()
or equivalent as defined in CONTRACTS.md §3).


Gate enumerates all existing RLS policy expressions on tenant-owned
tables and prints each policy name and expression text.
Policy expression enumeration output is part of the proof artifact —
not just a PASS/FAIL line.

### **6.5 Blocked identifiers lint**

Deliverable: Ghost carriers denylisted mechanically.  
DoD:  
blocked\_identifiers.json exists and lint fails on references.  
Proof shows lint run and PASS condition.  
Proof: docs/proofs/6.5\_blocked\_identifiers\_.log  
Gate: blocked-identifiers (merge-blocking)

### **6.6 — Product Core Tables [HARDENED]**

Deliverable:
Core domain tables exist with calc_version binding, all write paths
are registered, and concurrent row_version enforcement is proven by
test.
DoD additions (appended to existing 6.6 DoD):

docs/truth/write_path_registry.json exists enumerating every write
path to core tables (RPC names, trigger names, and any background
write paths).
write_path_registry.json is machine-derived (generated from
schema and RPC surface). §3.0.4c exemption does NOT apply. Triple
Registration Rule §3.0.4 applies in full:
a. Registered in robot-owned guard.
b. Included in truth-bootstrap validation gate.
c. Included in handoff regeneration surface.
For each registered write path: proof that it increments row_version
and checks the expected value on update via WHERE row_version = $expected.
A write path without this clause fails the proof.
pgTAP test: two concurrent UPDATEs are issued against the same row
using the same row_version value. Test asserts exactly one succeeds
and the other returns a conflict response. A stale-version update must
never silently overwrite.

---

### **6.7 — Share-Link Surface [HARDENED]**

Deliverable:
Public share-link mechanism exists without breaking tenant isolation,
with tenant-scoped token lookup proven at the query planner level —
not just at the source level.
DoD additions (appended to existing 6.7 DoD):

The share token lookup RPC WHERE clause must include both
token = $token AND tenant_id = $tenant_id. Token uniqueness alone
is not sufficient.
Negative test: a valid token from Tenant A, looked up in a context
that resolves to Tenant B's tenant ID, returns no result.
Token expiry behavior is explicitly defined: expired tokens return a
distinguishable code value per the RPC envelope contract
(CONTRACTS.md §1).
Query plan evidence required: Proof includes EXPLAIN output or
equivalent confirming the planner uses the tenant_id predicate.
A source-level assertion is not sufficient — index selection can cause
the planner to skip a predicate that is syntactically present in the
WHERE clause.

### **6.8 Seat \+ role model (per-seat billing-ready)**

Deliverable: Tenant membership \+ roles modeled cleanly for per-seat pricing.  
DoD:

* Tables exist for: tenants, memberships (user\_id, tenant\_id, role), seat\_state (optional).

* Roles are minimal: owner/admin/member (no fantasy roles).

* RLS (Row Level Security) policies align with role model.  
Proof: docs/proofs/6.8\_seat\_role\_model\_.md  
Gate: merge-blocking (security)

---

### **6.9 — Foundation Surface Ready Trigger (Unblocks 2.16.5C)**

**Deliverable:**
Declare that the minimum Foundation database surface exists so invariant testing can be executed.

**DoD:**

* Core Foundation tables exist.
* Tenancy model baseline exists.
* Roles/RLS baseline implemented.
* Activity log write path exists.
* Foundation schema is runnable in CI/local clean-room.

**Outcome:**

* This item **unblocks Build Route 2.16.5C — Foundation Invariants Suite**.
* 2.16.5C must be executed and closed immediately after 6.9 before further Foundation expansion.

**Proof:**
`docs/proofs/6.9_foundation_surface_ready_<UTC>.log`

**Gate:**
merge-blocking (security)

---

## **7 — Schema \+ Privilege Truth (Deterministic)**

### **7.1 Schema snapshot generation**

Deliverable: Schema truth reproducible.  
DoD:  
generated/schema.sql is generated deterministically.  
Drift check passes with no unexpected delta.  
Proof: docs/proofs/7.1\_schema\_snapshot\_.log  
Gate: schema-drift (merge-blocking)

### **7.2 — Privilege Truth + Default Privileges Lockdown [HARDENED]**

Deliverable:
Privileges and default privileges are truth for all roles including
anon, with contract-based enforcement preventing unauthorized GRANTs
in migrations.
DoD additions (appended to existing 7.2 DoD):

privilege_truth.json explicitly includes anon role grants and
default ACL entries alongside authenticated entries. Absence of
anon entries must be stated explicitly — it is not implied.
A lint gate fails if any migration contains a GRANT to anon or
authenticated that is not on the explicit allowlist defined in
CONTRACTS.md §12 and privilege_truth.json. A documentation comment
in the migration is not the control mechanism. The allowlist is the
single authority — an undocumented GRANT fails the gate regardless of
any comments present.

### **7.3 Contracts snapshot discipline**

Deliverable: Contracts snapshot changes are coupled to docs.  
DoD:  
If contracts snapshot changes, CONTRACTS.md changes in same PR.  
Gate fails on snapshot change without doc change.  
Proof: docs/proofs/7.3\_contracts\_policy\_.log  
Gate: policy-coupling (merge-blocking)

### **7.4 Entitlement truth (plan/seat source of truth)**

Deliverable: Entitlement truth is deterministic and auditable (no "magic UI gates").  
DoD:

* A single "entitled?" function/view exists (server-side truth).

* Entitlement is derived from persisted state (not client flags).

* Drift check exists: entitlement truth changes require doc update.  
Proof: docs/proofs/7.4\_entitlement\_truth\_.md  
Gate: merge-blocking (runtime)

### **7.5 RLS negative suite for product tables**

Deliverable: Product tables are tenant-isolated and negative-tested.  
DoD:

* pgTAP tests include: cross-tenant read/write attempts fail.

* Share-link access cannot bypass tenant boundaries.  
Proof: docs/proofs/7.5\_product\_rls\_negative\_suite\_.md  
Gate: merge-blocking (security)

### **7.6 — calc_version Change Protocol (NEW)**

Deliverable:
Gate-enforced protocol ensuring calculation logic changes always trigger
a version bump — guaranteeing historical deals cannot silently produce
different results after a logic update.
DoD:

docs/truth/calc_version_registry.json exists listing every
calc_version value with its associated calculation logic description
and the PR that introduced it.
A lint gate (scripts/ci_calc_version_lint.ps1 or equivalent) fails
if any PR modifies calculation logic files without an accompanying
calc_version_registry.json update in the same PR. Gate names the
logic files changed and the missing registry update.
calc_version_registry.json is machine-derived (updated by the
calculation logic build process). §3.0.4c exemption does NOT apply.
Triple Registration Rule §3.0.4 applies in full:
a. Registered in robot-owned guard.
b. Included in truth-bootstrap validation gate.
c. Included in handoff regeneration surface.
pgTAP test: a deal row seeded at calc_version = N returns identical
input and output values on reopen after the current calculator version
is incremented to N+1. Value identity is asserted field by field —
not as a JSON blob comparison.

Proof: docs/proofs/7.6_calc_version_protocol_<UTC>.log
Gate: calc-version-registry (merge-blocking).

### **7.7 — Supabase Studio Direct-Mutation Guard (NEW)**

Deliverable:
Operational policy and operator-run drift detection preventing out-of-band
DB mutations via the cloud console from silently diverging from
migration history.
DoD:

docs/ops/STUDIO_MUTATION_POLICY.md exists stating: all schema
changes must go through migrations; any emergency Studio write must
be immediately followed by a compensating migration merged via PR.
No exceptions without a stop-the-line acknowledgment per
AUTOMATION.md §6.
scripts/cloud_schema_drift_check.ps1 connects to the live cloud
project and compares its schema against generated/schema.sql. Script
exits non-zero with a named diff if any drift is detected.
This script is never run in CI. Cloud credentials must not be
exposed in workflow logs. It is operator-run only, with output
captured in a proof log and finalized via npm run proof:finalize.
STUDIO_MUTATION_POLICY.md is added to the governance-change-guard
path scope and to docs/truth/governance_surface_definition.json
(3.9.2) so that any future change to the policy triggers the
governance-change-guard.

Proof: docs/proofs/7.7_studio_mutation_guard_<UTC>.log
Gate: Operator-run only. No CI job. Policy-governed.

---

## **8 — Clean-Room Replay (Core)**

## Governance prerequisite

Before any PR in this block is opened, a Build Route amendment
governance PR must be merged that:

1. Replaces the current 8.0 DoD with the revised DoD below.
2. Adds items 8.0.1–8.0.5 to the Build Route.
3. Updates docs/truth/deferred_proofs.json conversion_trigger
   fields from the current value "8.0" to the specific item
   for each stub (see table at end of this document).

That PR requires docs/governance/GOVERNANCE_CHANGE_PR<NNN>.md
because it modifies the Build Route (a governance-surface file).

---

### **8.0 — CI Database Infrastructure [REVISED]**

**Objective**
Prove that CI runners can start Supabase and reach a live database.
This is infrastructure-only. No stub gates are converted in this PR.

**Deliverable**
A CI job that starts Supabase in a GitHub Actions runner and confirms
DB connectivity via a smoke query. The job passes before any
stub conversion work begins.

**DoD (all must be true)**

1. `.github/workflows/ci.yml` (or a new `database-tests.yml`)
   includes a job that runs `supabase start` in the runner
   environment and succeeds without error.

2. A smoke query confirms the DB is reachable:
   `psql -c "SELECT 1"` (or equivalent) returns successfully
   in the CI runner context.

3. Proof captures: supabase CLI startup output, DB connection
   confirmation, runner OS, Node version, Supabase CLI version
   (must match `docs/truth/toolchain.json`).

4. **No stub gates are converted in this PR.**
   `docs/truth/deferred_proofs.json` entries are not touched.
   `deferred-proof-registry` gate must still pass — all six
   stub entries remain present.

5. `docs/truth/completed_items.json` updated with 8.0.
   `docs/truth/qa_claim.json` updated to 8.0.
   `docs/truth/qa_scope_map.json` updated with 8.0 entry.
   `scripts/ci_robot_owned_guard.ps1` updated with 8.0 proof
   log pattern.

6. Section 3.0 constraints apply: one enforcement surface per PR.
   The only new enforcement surface is the CI DB smoke job.

**Pre-implementation check**
Confirm the runner has sufficient memory to start Supabase. The
Supabase local dev stack requires approximately 4GB RAM. GitHub
Actions `ubuntu-latest` runners provide 7GB. Verify this before
writing the workflow step. If memory is insufficient, document
the limitation in the proof log and in `deferred_proofs.json`
as a new entry before opening the PR.

**Proof:** `docs/proofs/8.0_ci_db_infrastructure_<UTC>.log`

**Gate:** `ci-db-smoke` (merge-blocking)

**Section 3.0 constraints apply.**

---

### **8.0.1 — clean-room-replay Stub Conversion**

**Objective**
Convert the `clean-room-replay` merge-blocking gate from a
db-heavy stub to live execution against the CI database.

**Context from DEVLOG**
3.9.1 catalogued `clean-room-replay` in `deferred_proofs.json`
with `conversion_trigger: "8.0"` (updated to "8.0.1" in the
amendment PR). This is the foundational DB gate — every other
stub conversion depends on CI being able to replay migrations.

**Deliverable**
`clean-room-replay` gate runs full migration replay on an empty
CI DB and passes.

**DoD (all must be true)**

1. On CI (live DB via 8.0 infrastructure), `supabase db reset`
   replays all migrations in `supabase/migrations/**` in order
   on an empty database without error.

2. The `clean-room-replay` CI job is updated to run actual
   replay instead of the db-heavy stub pass-through. The stub
   pattern is removed from this job only.

3. Gate fails if any migration errors during replay. Proof
   captures the full migration list and replay output.

4. **Deliberate-failure proof required:** Introduce a syntax
   error into a migration file locally, run the gate, confirm
   FAIL with migration name in output, restore the file, confirm
   PASS. Full sequence captured in proof log.

5. `docs/truth/deferred_proofs.json` entry for `clean-room-replay`
   is removed in this PR. `deferred-proof-registry` gate must
   pass after removal — the gate fails if a converted gate still
   has a registry entry (DEVLOG 3.9.1 DoD item 4).

6. `docs/truth/completed_items.json` updated with 8.0.1.
   `docs/truth/qa_claim.json` updated to 8.0.1.
   `docs/truth/qa_scope_map.json` updated with 8.0.1 entry.
   `scripts/ci_robot_owned_guard.ps1` updated with 8.0.1 proof
   log pattern.

7. `STUB_GATES_ACTIVE` block in this proof log reflects the
   remaining active stubs after this conversion:
   schema-drift, definer-safety-audit, handoff-idempotency,
   pgtap, database-tests.yml.

**Prerequisite:** 8.0 merged and main clean.

**Proof:** `docs/proofs/8.0.1_clean_room_replay_conversion_<UTC>.log`

**Gate:** `clean-room-replay` (merge-blocking, now live)

**Section 3.0 constraints apply.**

---

### **8.0.2 — schema-drift Stub Conversion**

**Objective**
Convert the `schema-drift` merge-blocking gate from a db-heavy
stub to live execution — comparing a schema dump from the live
CI DB against `generated/schema.sql`.

**Context from DEVLOG**
3.9.1 catalogued `schema-drift` in `deferred_proofs.json` with
`conversion_trigger: "8.0"` (updated to "8.0.2" in amendment PR).
Currently the gate performs a text-match check on the static
`generated/schema.sql` file without a live DB comparison. After
conversion it will dump the schema from the live post-replay DB
and diff it against the committed artifact.

**Deliverable**
`schema-drift` gate compares a live CI DB schema dump against
`generated/schema.sql` and fails on any delta.

**DoD (all must be true)**

1. After `clean-room-replay` runs in CI, `schema-drift` dumps
   the schema from the live DB (`pg_dump --schema-only` or
   `supabase db dump` equivalent) and diffs against
   `generated/schema.sql`.

2. Gate fails if any drift is detected, printing the exact diff.
   Gate passes if schema matches byte-for-byte after encoding
   normalization (LF, UTF-8 no BOM per GUARDRAILS §29–31).

3. The db-heavy stub pass-through is removed from the
   `schema-drift` CI job.

4. **Deliberate-failure proof required:** Introduce a column
   addition to a migration locally without regenerating
   `generated/schema.sql`, run the gate, confirm FAIL with
   diff output showing the added column, restore and re-run
   handoff to regenerate schema, confirm PASS.

5. `docs/truth/deferred_proofs.json` entry for `schema-drift`
   removed. `deferred-proof-registry` gate must pass after removal.

6. `docs/truth/completed_items.json` updated with 8.0.2.
   `docs/truth/qa_claim.json` updated to 8.0.2.
   `docs/truth/qa_scope_map.json` updated with 8.0.2 entry.
   `scripts/ci_robot_owned_guard.ps1` updated with 8.0.2 proof
   log pattern.

7. `STUB_GATES_ACTIVE` block reflects remaining active stubs:
   definer-safety-audit, handoff-idempotency, pgtap,
   database-tests.yml.

**Prerequisite:** 8.0.1 merged and main clean.

**Proof:** `docs/proofs/8.0.2_schema_drift_conversion_<UTC>.log`

**Gate:** `schema-drift` (merge-blocking, now live)

**Section 3.0 constraints apply.**

---

### **8.0.3 — handoff-idempotency Stub Conversion**

**Objective**
Convert the `handoff-idempotency` merge-blocking gate from a
db-heavy stub to live execution against the CI database.

**Context from DEVLOG**
3.8 confirmed the gate was introduced as a CI-stub: "CI stub
passes (db-heavy pattern)" (DEVLOG 3.8 DoD item 3). The local
proof demonstrates zero diffs on a live local DB. The CI gate
currently passes the stub without running the actual handoff
cycle. After conversion it will run `npm run handoff` against
the CI DB and assert zero diffs in the working tree.

**Deliverable**
`handoff-idempotency` gate runs the full handoff cycle in CI
against a live DB and asserts zero diffs.

**DoD (all must be true)**

1. In CI, after clean-room-replay has run, `npm run handoff`
   is executed. `git status --porcelain` must be empty
   (zero diffs) on a tree where truth artifacts are already
   committed.

2. A second consecutive `npm run handoff` run also produces
   zero diffs. Both runs are captured in the proof log.

3. The db-heavy stub pass-through is removed from the
   `handoff-idempotency` CI job.

4. Gate fails if first or second run produces any diff,
   printing the diff output.

5. **Deliberate-failure proof required:** Introduce a
   determinism bug locally (e.g. inject a timestamp into
   schema output), run the gate, confirm FAIL with diff shown,
   restore, confirm PASS.

6. `docs/truth/deferred_proofs.json` entry for
   `handoff-idempotency` removed. `deferred-proof-registry`
   gate must pass after removal.

7. `docs/truth/completed_items.json` updated with 8.0.3.
   `docs/truth/qa_claim.json` updated to 8.0.3.
   `docs/truth/qa_scope_map.json` updated with 8.0.3 entry.
   `scripts/ci_robot_owned_guard.ps1` updated with 8.0.3 proof
   log pattern.

8. `STUB_GATES_ACTIVE` block reflects remaining active stubs:
   definer-safety-audit, pgtap, database-tests.yml.

**Prerequisite:** 8.0.2 merged and main clean.

**Proof:** `docs/proofs/8.0.3_handoff_idempotency_conversion_<UTC>.log`

**Gate:** `handoff-idempotency` (merge-blocking, now live)

**Section 3.0 constraints apply.**

---

### **8.0.4 — definer-safety-audit Stub Conversion**

**Objective**
Convert the `definer-safety-audit` merge-blocking gate from a
db-heavy stub to live catalog queries against the CI database,
implementing the full 6.2 hardening spec.

**Context from DEVLOG**
3.9.1 catalogued `definer-safety-audit` in `deferred_proofs.json`
with `conversion_trigger: "8.0"` (updated to "8.0.4" in amendment
PR). The DEVLOG advisor review entry (2026-02-21) confirmed the
original gate used `pg_proc.prosrc` for search_path detection,
which is incorrect — the correct field is `pg_proc.proconfig`.
The 6.2 hardening (Build Route item 6.2 hardened) specifies the
correct catalog field and adds CONTRACTS.md §8 tenant membership
enforcement assertion. Both requirements are implemented here.

**HARD BLOCK: This item cannot be opened until Build Route item
6.2 hardening is merged to main. The live gate must implement the
full 6.2 DoD additions, not just convert the stub. Opening this
PR before 6.2 would produce a live gate less rigorous than the
hardened spec.**

**Deliverable**
`definer-safety-audit` gate queries the live CI DB catalog and
asserts all SECURITY DEFINER functions on the allowlist satisfy
CONTRACTS.md §8 requirements.

**DoD (all must be true)**

1. Gate queries `pg_proc.proconfig` (not `pg_proc.prosrc`) on
   the live CI DB for every function listed in
   `docs/truth/definer_allowlist.json`. Confirms `search_path`
   is present in proconfig for each function.

2. Gate additionally asserts, per CONTRACTS.md §8, that every
   allowlisted SD function:
   - Has `search_path` set in `pg_proc.proconfig`
   - Has schema-qualified object references (confirmed via
     `pg_proc.prosrc` text scan for unqualified identifiers)
   - Enforces tenant membership internally (confirmed via
     `pg_proc.prosrc` text scan for `current_tenant_id()` or
     approved equivalent per CONTRACTS.md §3)

3. Gate fails naming the function and the specific missing
   requirement if any assertion fails.

4. Helper functions called by SD functions are enumerated in
   the proof. Each is confirmed to use only schema-qualified
   references.

5. The db-heavy stub pass-through is removed from the
   `definer-safety-audit` CI job.

6. **Deliberate-failure proof required:** Add a test SD function
   to a non-production migration locally with missing
   `SET search_path`, run the gate, confirm FAIL naming the
   function and the missing proconfig entry, remove the test
   function, confirm PASS.

7. `docs/truth/deferred_proofs.json` entry for
   `definer-safety-audit` removed. `deferred-proof-registry`
   gate must pass after removal.

8. `docs/truth/completed_items.json` updated with 8.0.4.
   `docs/truth/qa_claim.json` updated to 8.0.4.
   `docs/truth/qa_scope_map.json` updated with 8.0.4 entry.
   `scripts/ci_robot_owned_guard.ps1` updated with 8.0.4 proof
   log pattern.

9. `STUB_GATES_ACTIVE` block reflects remaining active stubs:
   pgtap, database-tests.yml.

**Prerequisites:**
- 8.0.3 merged and main clean.
- Build Route item 6.2 hardening merged and main clean.
  Do not open this PR before both conditions are met.

**Proof:** `docs/proofs/8.0.4_definer_safety_audit_conversion_<UTC>.log`

**Gate:** `definer-safety-audit` (merge-blocking, now live)

**Section 3.0 constraints apply.**

---

### **8.0.5 — pgtap + database-tests.yml Stub Conversion**

**Objective**
Convert the `pgtap` merge-blocking gate from a db-heavy stub to
live test execution, and create `database-tests.yml` to close the
AUTOMATION.md §2 compliance gap catalogued in `deferred_proofs.json`.

**Context from DEVLOG**
3.9.1 catalogued two entries with this conversion:
- `pgtap` (db-heavy stub, conversion_trigger: "8.0" → "8.0.5")
- `database-tests.yml` (AUTOMATION.md §2 gap, conversion_trigger:
  "6.0/8.0" → "8.0.5")

AUTOMATION.md §2 lists `.github/workflows/database-tests.yml` as
a required merge-blocking workflow. That file does not exist.
Its absence means the full DB test suite has never run in CI.
This item creates it and converts the pgtap stub simultaneously
because they are the same enforcement surface: live DB tests.

**HARD BLOCK: This item cannot be opened until Build Route items
6.3 (tenant integrity suite with populated data, view tests, FK
embedding tests) and 6.4 (RLS structural audit with specific
forbidden pattern enumeration) are both merged to main. A live
pgtap gate with an empty or incomplete test suite produces a
vacuous pass — worse than a stub because it appears enforced.**

**Deliverable**
`.github/workflows/database-tests.yml` exists and runs the full
pgTAP suite against a live CI DB. `pgtap` gate passes on real
test execution. Both `deferred_proofs.json` entries removed.

**DoD (all must be true)**

1. `.github/workflows/database-tests.yml` exists with:
   - Trigger: `pull_request` (main target) and `push` to main
   - Steps: `supabase start`, migration replay, `supabase test db`
   - Required check context string-exact: `database-tests / pgtap`
     (or equivalent matching `required_checks.json` entry)

2. All pgTAP test files satisfy GUARDRAILS §25–28:
   - SQL-only (no `DO` blocks, no PL/pgSQL)
   - No lines beginning with `\`
   - Every file declares `plan(n)` or `no_plan()` and reaches
     `finish()`
   - Tests fail deterministically (no swallowed errors)
   A pre-conversion audit of all existing pgTAP files against
   these rules is performed and documented in the proof log
   before the stub is removed. Any violations are fixed in this
   same PR as a documented sub-step.

3. `npx supabase test db` passes on the live CI DB against the
   full test suite including:
   - Tenant isolation negative tests (from 6.3) with populated
     data in both Tenant A and Tenant B
   - RLS structural audit (from 6.4) with policy expression
     enumeration
   - Any other pgTAP tests authored by the time this item runs

4. The db-heavy stub pass-through is removed from the `pgtap`
   CI job.

5. `docs/truth/required_checks.json` is updated to include the
   `database-tests.yml` workflow check context string-exact.

6. **Deliberate-failure proof required:** Temporarily introduce
   a failing pgTAP assertion (e.g. `ok(false, 'deliberate fail')`),
   run the gate, confirm FAIL with test name in output, restore,
   confirm PASS.

7. Both `deferred_proofs.json` entries removed in this PR:
   - `pgtap`
   - `database-tests.yml`
   `deferred-proof-registry` gate must pass after both removals.
   If this is the last remaining entry, the registry becomes
   empty — the gate must pass on an empty registry (no entries
   required when no stubs remain).

8. `STUB_GATES_ACTIVE` block is removed from all future proof
   logs after this item merges. No stubs remain.

9. `docs/truth/completed_items.json` updated with 8.0.5.
   `docs/truth/qa_claim.json` updated to 8.0.5.
   `docs/truth/qa_scope_map.json` updated with 8.0.5 entry.
   `scripts/ci_robot_owned_guard.ps1` updated with 8.0.5 proof
   log pattern.

**Prerequisites:**
- 8.0.4 merged and main clean.
- Build Route 6.3 (tenant integrity suite, populated-data
  negative tests, view tests, FK embedding HTTP tests) merged.
- Build Route 6.4 (RLS structural audit, specific forbidden
  pattern enumeration) merged.
  Do not open this PR before all three conditions are met.

**Proof:** `docs/proofs/8.0.5_pgtap_conversion_<UTC>.log`

**Gate:** `pgtap` (merge-blocking, now live) +
          `database-tests.yml` workflow created (closes
          AUTOMATION.md §2 compliance gap)

**Section 3.0 constraints apply.**

---

## deferred_proofs.json Trigger Update Table

To be applied in the Build Route amendment governance PR:

| Gate                | Current trigger | Updated trigger        |
|---------------------|-----------------|------------------------|
| clean-room-replay   | 8.0             | 8.0.1                  |
| schema-drift        | 8.0             | 8.0.2                  |
| handoff-idempotency | 8.0             | 8.0.3                  |
| definer-safety-audit| 8.0             | 8.0.4 (requires 6.2)   |
| pgtap               | 8.0             | 8.0.5 (requires 6.3+6.4)|
| database-tests.yml  | 6.0/8.0         | 8.0.5 (requires 6.3+6.4)|

---

## Execution Order Summary

```
Amendment governance PR    (revises 8.0, adds 8.0.1–8.0.5,
updates deferred_proofs.json triggers)
↓
8.0  CI DB Infrastructure  (smoke only, no stubs converted)
↓
8.0.1 clean-room-replay    (foundational — all others depend on this)
↓
8.0.2 schema-drift         (requires 8.0.1)
↓
8.0.3 handoff-idempotency  (requires 8.0.2)
↓
8.0.4 definer-safety-audit (requires 8.0.3 + 6.2 hardening)
↓
8.0.5 pgtap +              (requires 8.0.4 + 6.3 + 6.4)
database-tests.yml
→ deferred_proofs.json now empty
→ STUB_GATES_ACTIVE block removed from all future proofs
→ AUTOMATION.md §2 compliance gap closed
```

### **8.1 Local clean-room replay proof**

Deliverable: Replay is deterministic.  
DoD:  
Empty local DB replays all migrations in order and succeeds.  
Proof contains full replay output and command line.  
Proof: docs/proofs/8.1\_clean\_room\_replay\_.log  
Gate: clean-room-replay (merge-blocking)

### **8.2 Local DB tests proof (pgTAP)**

Deliverable: Tests pass after replay.  
DoD:  
npx supabase test db passes after clean-room replay.  
Proof contains test output and versions.  
Proof: docs/proofs/8.2\_clean\_room\_tests\_.log  
Gate: pgtap (merge-blocking)

### **8.3 Cloud migration parity guard (new baseline, pinned)**

Deliverable: Cloud applied migrations match repo baseline onward.  
DoD:  
Cloud project ref \+ migration tip are pinned in truth files.  
Guard proves cloud tip equals pinned tip and fails on mismatch.  
Proof: docs/proofs/8.3\_cloud\_migration\_parity\_.log  
Gate: lane-only cloud-migration-parity

---

## **9 — Surface Truth (PostgREST Exposure)**

Promotion Rule: surface-truth is lane-only until stable.

### **9.1 Surface truth schema \+ canonicalization**

Deliverable: Surface equality enforceable.  
DoD:  
Truth schema exists and harness canonicalizes deterministically.  
Proofs contain actual surface outputs under docs/proofs//.  
Proof: docs/proofs/9.1\_surface\_truth\_schema\_.log  
Gate: lane-only surface-truth

### **9.2 Expected surface \+ executable allowlist invariants**

Deliverable: DB surface, OpenAPI surface, and allowlist cannot diverge.  
DoD:  
expected\_surface equals normalized DB surface and normalized OpenAPI /rpc surface.  
execute\_allowlist is a strict subset and mismatches hard-fail.  
Proof: docs/proofs/9.2\_surface\_truth\_.log  
Gate: lane-only surface-truth

### **9.3 Reload mechanism (single canonical path)**

Deliverable: Reload isn't contradictory.  
DoD:  
Canonical reload is deploy-lane only and documented.  
Cloud harness includes reload evidence; local harness does not claim reload.  
Proof: docs/proofs/9.3\_reload\_contract\_.md  
Gate: enforced in deploy lane \+ release lane

---

## **10 — WeWeb Integration (Scope-controlled)**

### **10.1 WeWeb smoke (optional until "WeWeb in scope")**

Deliverable: WeWeb connects using contracts.  
DoD:  
WeWeb uses allowed RPC surfaces per contract.  
Proof shows access patterns and no forbidden direct calls.  
Proof: docs/proofs/10.1\_weweb\_smoke\_.md  
Gate: lane-only unless promoted

### **10.2 WeWeb drift guard (if WeWeb in scope)**

Deliverable: WeWeb can't silently switch to direct table calls.  
DoD:  
Endpoints truth exists and verifier detects forbidden /rest/v1/ usage.  
Gate enforcement matches PR scope rules for WeWeb changes.  
Proof: docs/proofs/10.2\_weweb\_drift\_.log  
Gate: lane-only weweb-drift until promoted

### **10.3 MAO calculator golden-path smoke**

Deliverable: MAO calculator works end-to-end (WeWeb → Supabase) on the golden path.  
DoD:

* Inputs → MAO output renders correctly.

* Output includes offer range (best/expected/worst) using same calc\_version.

* No forbidden direct table calls (contract surfaces only).  
Proof: docs/proofs/10.3\_mao\_golden\_path\_.md  
Gate: lane-only until promoted

### **10.4 Save deal \+ reopen deal**

Deliverable: Saved deals are reliable and re-open exactly (no silent recompute drift).  
DoD:

* Save persists inputs \+ outputs \+ calc\_version.

* Reopen shows identical values to what was saved.

* Activity log records mutations.  
Proof: docs/proofs/10.4\_save\_reopen\_deal\_.md  
Gate: merge-blocking once Hub is in scope

### **10.5 Deal packet share-link smoke**

Deliverable: Share link renders a buyer-ready packet and respects allowlist.  
DoD:

* Share link works unauthenticated (if intended).

* Only allowlisted fields appear.

* Negative probe: cannot access non-shared deal.  
Proof: docs/proofs/10.5\_share\_link\_smoke\_.md  
Gate: merge-blocking (security) once enabled

### **10.6 Seat enforcement UX \+ API consistency**

Deliverable: Seat/entitlement enforcement is consistent between UI and API.  
DoD:

* Over-seat condition blocks actions at API (not just UI).

* UI displays a deterministic "blocked because entitlement" state.

* No "partial access" inconsistencies.  
Proof: docs/proofs/10.6\_seat\_enforcement\_consistency\_.md  
Gate: merge-blocking once billing is enabled

---

## **11 — Release \+ Handoff Discipline**

### **11.1 Handoff artifacts updated**

Deliverable: Handoff pointer is current.  
DoD:  
docs/handoff\_latest.txt points to HEAD and required proofs.  
Handoff verification command returns PASS.  
Proof: docs/proofs/11.1\_handoff\_.log  
Gate: handoff-contract (merge-blocking)

### **11.2 Handoff publish (branch only)**

Deliverable: Truth artifacts published via PR branch only.  
DoD:  
handoff:commit pushes current PR branch only and refuses main.  
Proof prints the remote ref pushed and requires clean tree.  
Proof: docs/proofs/11.2\_handoff\_commit\_.log  
Gate: handoff-commit-safety (merge-blocking)

### **11.3 Ship verify-only on main**

Deliverable: Post-merge verification is safe.  
DoD:  
On main/HEAD, ship produces zero diffs and PASS.  
Proof includes git status before/after and ship output.  
Proof: docs/proofs/11.3\_ship\_.log  
Gate: ship-guard (merge-blocking)

### **11.4 Release workflow guard (no PR triggers)**

Deliverable: Release workflow cannot run on pull\_request.  
DoD:  
release workflow triggers are restricted to main/tag/manual dispatch.  
Guard detects and fails if pull\_request trigger exists.  
Proof: docs/proofs/11.4\_release\_workflow\_guard\_.log  
Gate: lane-only release-workflow-guard unless promoted

### **11.5 E2E gates (Playwright) (when introduced)**

Deliverable: Golden path \+ negative tests.  
DoD:  
E2E suite includes forbidden-access negative tests and passes deterministically.  
Proof includes E2E run output and artifact references.  
Proof: docs/proofs/11.5\_e2e\_.log  
Gate: lane-only e2e until promoted

### **11.6 Stable declaration (tag \+ releases entry \+ one-time proofs)**

Deliverable: Stable is a gated event.  
DoD:  
Stable checklist is satisfied (one\_time\_proofs \+ MAIN\_HEAD \== HANDOFF\_HEAD).  
Proof lists required one-time proofs with hashes.  
Proof: docs/proofs/11.6\_stable\_.md  
Gate: lane-only stable-declare

### **11.7 Cloud surface proof (HTTP-only lane)**

Deliverable: Cloud matches expected surface and probes.  
DoD:  
Cloud harness passes expected\_surface/probes using anon key GET-only.  
Proof includes deploy-lane reload evidence.  
Proof: docs/proofs/11.7\_cloud\_surface\_.log  
Gate: lane-only cloud-surface

### **11.8 Billing webhook idempotency (provider-agnostic)**

Deliverable: Billing events cannot double-apply (idempotent entitlement updates).  
DoD:

* Webhook handler uses idempotency key (event\_id) and is retry-safe.

* Entitlement updates are atomic (no partial seat state).

* Proof includes replay of same event twice → no double seats.  
Proof: docs/proofs/11.8\_billing\_webhook\_idempotency\_.md  
Gate: merge-blocking once billing is enabled

### **11.9 Entitlement cutover checklist (free → paid)**

Deliverable: Clear cutover rules for free caps and paid unlock.  
DoD:

* Free caps are explicit (saved deals count, share links, seats).

* Upgrade preserves saved work (no re-entry).

* Support playbook exists for "payment failed → access degraded" states.  
Proof: docs/proofs/11.9\_entitlement\_cutover\_checklist\_.md  
Gate: merge-blocking (release)

---

## **12 — PR Scope Rules (prevents "cheat" PRs)**

### **12.1 Scope taxonomy (machine-defined)**

Deliverable: PR classification is deterministic.  
DoD:  
Scope taxonomy truth exists and mixed scopes are rejected unless objective allows.  
Gate enforces PR classification deterministically.  
Proof: docs/proofs/12.1\_pr\_scope\_.log  
Gate: pr-scope (merge-blocking)

---

## **13 — Recovery \+ Rollback (Integrated)**

### **13.1 Rollback \+ recovery mini rehearsal (one-time stable prerequisite)**

Deliverable: You can recover without improvising.  
DoD:  
RELEASES defines rollback \+ recovery steps and LKG tag discipline.  
One rehearsal is executed and captured as proof.  
Proof: docs/proofs/13.1\_recovery\_rehearsal\_.log  
Gate: lane-only; required for stable

---

### **13.2 — Incident Resolution Deadline Enforcement**

**Hardening target:**
Item 2.16.8 (stop-the-line-xor) requires an INCIDENT entry when a stop-the-line condition is triggered. However 2.16.8 only enforces that the entry exists — it does not enforce that it is ever resolved. Under operational pressure, INCIDENTS.md can accumulate unresolved entries indefinitely while CI stays green. This item closes that gap.

**Deliverable:**
Mechanical enforcement that open INCIDENT entries do not accumulate beyond a defined resolution window.

**DoD:**

* `docs/truth/incident_policy.json` exists with:
  * `max_open_days` — maximum days an INCIDENT entry may remain unresolved
  * `resolution_marker` — exact string marking an incident closed (e.g. `RESOLVED:`)
* Gate scans `docs/threats/INCIDENTS.md` for entries missing the resolution marker beyond `max_open_days`.
* Gate output includes: incident identifier, age in days, deadline.
* Gate fails if any incident exceeds `max_open_days` without a resolution marker.
* Waiver path is explicitly forbidden for this gate. An unresolved incident cannot be waivered — it must be resolved or escalated via a new INCIDENT entry.
* Gate is merge-blocking.

**Proof:**
`docs/proofs/13.2_incident_resolution_deadline_<UTC>.log`

**Gate:**
`incident-resolution-deadline` (merge-blocking)
