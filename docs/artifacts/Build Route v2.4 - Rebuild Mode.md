FEB 8, 2026 11 AM

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
docs/proofs/0.0\_rebuild\_mode\_.md exists and explicitly states “no legacy migration import.”  
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

Nothing is “done” unless all are true:  
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
No database/schema artifacts are ported as “truth” (per Checklist 1.4/regen policy).  
Checklist 1.1 (non-DoD):  
Repo enforcement  
.gitattributes  
.editorconfig  
lockfile (package-lock.json or equivalent)  
CODEOWNERS  
.github/workflows/\*\*  
Docs (policy)  
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

Deliverable: Ported governance/tooling is runnable and not “dead on arrival”.  
DoD:  
All required repo scripts/targets run successfully locally (per Checklist 1.2).  
Workflows parse (YAML valid) and referenced scripts exist on disk.  
Checklist 1.2 (non-DoD):  
npm ci succeeds  
npm run lint:migrations succeeds (runner exists; OK if “no migrations”)  
npm run lint:sql succeeds  
npm run lint:pgtap succeeds (runner exists; OK if “no tests” is permitted PASS)  
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
All “ship publishes” statements are removed/replaced with “handoff:commit publishes; ship verifies.”  
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

DoD: CI hard-fails if git add \--renormalize would change any allowlisted truth/robot paths.

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

**2.8 Command Smoke (Gov-only) (mandatory)(DONE FEB 9\)**

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

Deliverable: Clean-room replay can’t run on contaminated docker context.  
DoD:  
env\_sanity passes and fails on contamination conditions (defined in script).  
Proof shows env\_sanity output run immediately before clean-room replay.  
Proof: docs/proofs/2.13\_env\_sanity\_.log  
Gate: env-sanity (merge-blocking)

### **2.14 Stop-the-line incident coupling (solo-friendly)(DONE FEB 9\)**

Deliverable: Incident-class patterns can’t be silently ignored.  
DoD:  
CI stop-the-line conditions require INCIDENTS entry OR a one-PR waiver file.  
Waiver validity is mechanically enforceable (PRNUM+commit+“QA: NOT AN INCIDENT”).  
Proof: docs/proofs/2.14\_stop\_the\_line\_.log  
Gate: stop-the-line (merge-blocking)

### **2.15 Governance-change guard(DONE FEB 9\)**

Deliverable: Changes to core truth/policy require explicit justification.  
DoD:  
Any PR touching core truth requires a GOVERNANCE\_CHANGE\_*.md.*  
*Guard prevents “docs-only” classification on such PRs.*  
*Proof: docs/proofs/2.15\_governance\_change*.log  
Gate: governance-change-guard (merge-blocking)

---

## **Section 2.16 — Additive Governance Hardening (Post-Close)**

*(Section 2 remains closed; all items are additive only)*

---

### **2.16.1 — GitHub Policy Drift Attestation (Scheduled)(DONE FEB 10\)**

**Deliverable**  
Scheduled CI workflow that detects GitHub governance drift outside repo control.

**DoD**

* Workflow runs on schedule (and manual trigger).  
* Fetches via GitHub API:  
  * branch protection / rulesets  
  * required checks  
  * admin bypass flags  
* Diffs against committed snapshot `docs/truth/github_policy_snapshot.json`.  
* Any mismatch produces a loud signal (CI fail or issue).

**Proof**  
`docs/proofs/2.16.1_policy_drift_attestation_<UTC>.log`

**Gate**  
`policy-drift-attestation` (scheduled, non-merge-blocking)

---

### **2.16.2 — Proof Commit-Binding (Validity Enforcement, Minimal)(DONE FEB 10\)**

**Deliverable**  
Proof header contract \+ validator binding proofs to reality.

**DoD**  
**All must be true:**

1. **Build Route updated**  
   * **`PROOF_HEAD` defined as tested SHA at runtime**  
   * **Valid if `PROOF_HEAD` is an ancestor of PR\_HEAD**  
   * **`git diff --name-only PROOF_HEAD..PR_HEAD` contains only:**  
     * **`docs/proofs/**`**  
     * **optionally `docs/DEVLOG.md`**  
   * **SKIP rule documented: if no `docs/proofs/**` touched, gate exits `0` with `PROOF_COMMIT_BINDING_SKIP`**  
2. **Validator implemented**  
   * **Gate `proof-commit-binding` enforces the above rules**  
   * **Fails on:**  
     * **non-ancestor `PROOF_HEAD`**  
     * **non-proof tail changes**  
     * **missing/mismatched `PROOF_SCRIPTS_HASH`**  
   * **Uses deterministic, normalized script-hash algorithm per AUTOMATION**  
3. **Proof artifact committed**  
   * **`docs/proofs/2.16.2_proof_commit_binding_<UTC>.log`**  
   * **Contains:**  
     * **`PROOF_HEAD`**  
     * **`PROOF_SCRIPTS_HASH`**  
     * **`RESULT=PASS`**  
4. **Manifest updated**  
   * **`docs/proofs/manifest.json` includes the new proof log with correct sha256**  
5. **CI wired \+ merge-blocking**  
   * **Job `proof-commit-binding` exists in `.github/workflows/ci.yml`**  
   * **Registered as required check**  
   * **CI is green**

**Proof**  
`docs/proofs/2.16.2_proof_commit_binding_<UTC>.log`

**Gate**  
`proof-commit-binding` (merge-blocking)

---

### **2.16.2A Hash Authority Contract (NEW, mandatory)(DONE FEB 11\)**

**Deliverable:** `PROOF_SCRIPTS_HASH` authority is declared once and cannot drift.

**DoD:**

* `docs/AUTOMATION.md` contains a subsection **“proof-commit-binding — scripts hash authority”** that defines, **string-exact**:  
  * the **script file list** included in `PROOF_SCRIPTS_HASH`  
  * the **ordering rule** (explicit order or path-sorted)  
  * the **normalization rule** (**CRLF→LF** before hashing)  
* `scripts/ci_proof_commit_binding.ps1` computes `PROOF_SCRIPTS_HASH` **exactly per `docs/AUTOMATION.md`** (no inference, no globbing).  
* The 2.16.2 proof log shows **matching** `PROOF_SCRIPTS_HASH` between proof header and validator output.

**Proof:** `docs/proofs/2.16.2A_hash_authority_contract_<UTC>.log`

**Gate:** `proof-commit-binding` (merge-blocking)

---

### **2.16.3 — CI Semantic Contract (Targeted Anti–No-Op)(DONE FEB 11\)**

**Deliverable**  
Semantic validation that required CI jobs actually execute gates.

**DoD**

* If `.github/workflows/**` **changes** in PR:  
  * semantic contract is **merge-blocking**  
* Otherwise:  
  * runs **alert-only** (PR \+ scheduled)  
* Validator asserts required jobs:  
  * invoke allowlisted gate scripts  
  * are not noop / echo-only exits

**Proof**  
`docs/proofs/2.16.3_ci_semantic_contract_<UTC>.log`

**Gate**  
`ci-semantic-contract`  
(merge-blocking **only** on workflow changes)

---

### **2.16.4 — Waiver Debt Enforcement (Low-Ceiling Hard Fail)(DONE FEB 11\)**

**Deliverable**  
Mechanical limit preventing waiver normalization.

**DoD**

* CI computes waiver usage from `docs/waivers/` \+ repo history.  
* Threshold rules:  
  * **\>1 waiver in last 14 days → hard FAIL**  
* Below threshold:  
  * WARN \+ signal only  
* Forces cleanup: convert to INCIDENT or remove waiver.

**Proof**  
`docs/proofs/2.16.4_waiver_debt_enforcement_<UTC>.log`

**Gate**  
`waiver-debt-enforcement` (merge-blocking at low ceiling)

---

## **2.16.4A — CI Gate Wiring Closure (Authoritative)(DONE FEB 12\)**

**Objective:**  
Close known governance gate wiring gaps by ensuring all merge-blocking governance gates **required up to this section** are present in CI as **string-exact job IDs** and are structurally merge-blocking via the repo’s aggregate `required` job. Structural enforcement only.

**Authoritative Source:**  
`truth/required_checks.json`

**Deliverable:**  
`.github/workflows/**` contains jobs with **string-exact job IDs** for every required check in `truth/required_checks.json`, and `.github/workflows/ci.yml:required.needs` depends on them.

**DoD:**

* `truth/required_checks.json` exists and contains the authoritative list of required merge-blocking job IDs.  
* Every entry in `truth/required_checks.json` exists as a **job ID** in `.github/workflows/**` (string-exact).  
* Aggregate enforcement is complete:  
  * `.github/workflows/ci.yml` contains job `required`  
  * `required.needs` contains **all** entries from `truth/required_checks.json` (string-exact)  
* Workflows are runnable on PRs (`pull_request` present; not dispatch-only).

**Proof:**  
`docs/proofs/2.16.4A_ci_gate_wiring_closure_<UTC>.log`  
Must include: PR HEAD SHA, contents of `truth/required_checks.json`, workflow inventory (`ls .github/workflows`), grep evidence of each job ID in workflows, extracted `required.needs`, PASS/FAIL statement:  
`All truth/required_checks.json entries exist as workflow job IDs and are included in required.needs.`

**Gate:**  
`ci-gate-wiring-closure` (merge-blocking)

**Fails if:**  
Any truth entry missing from workflow job IDs, any string mismatch, or any truth entry missing from `required.needs`.

---

## **2.16.4B — CI Topology Audit Gate (No Phantom Gates Enforcement)(DONE FEB 12\)**

**Objective:**  
Prevent silent governance drift by mechanically asserting that required merge-blocking gates are **authoritatively declared**, **wired in workflows**, and **structurally merge-blocking**, not merely present in docs or npm scripts.

**Authoritative Source:**  
`docs/truth/required_checks.json`

**Deliverable:**  
Merge-blocking PR check `ci-topology-audit` enforcing the **No Phantom Gates** rule.

**DoD:**

* `ci-topology-audit` runs on `pull_request`.  
* It loads required check names from `truth/required_checks.json`.  
* It asserts:  
  1. Every truth entry exists as a **job ID** in `.github/workflows/**` (string-exact).  
  2. `.github/workflows/ci.yml` job `required` exists and `required.needs` contains the full truth set (string-exact).  
  3. Docs / `package.json` scripts are non-authoritative unless workflow wiring exists.

**Proof:**  
`docs/proofs/2.16.4B_ci_topology_audit_<UTC>.log`

**Gate:**  
`ci-topology-audit` (merge-blocking)

**Fails if:**  
Any truth entry missing from workflow job IDs; any truth entry missing from `required.needs`; any string mismatch.

**Failure output must include:**  
Expected vs found lists for (a) workflow job IDs and (b) `required.needs`, plus workflow file/line pointers where possible.

---

## **2.16.4C — Truth Sync Enforcement (Machine-Derived Truth)(DONE FEB 12\)**

**Objective:**  
Eliminate human-maintained drift in truth files by making `truth/required_checks.json` **machine-derived** from workflow reality and enforcing a **clean regeneration invariant**.

**Deliverable:**  
A generator command (example) `npm run truth:sync` that regenerates `truth/required_checks.json` from `.github/workflows/**` \+ `.github/workflows/ci.yml:required.needs`.

**DoD:**

* `npm run truth:sync` deterministically rewrites `truth/required_checks.json` (stable ordering).  
* Running `npm run truth:sync` twice produces identical output.  
* CI runs `npm run truth:sync` and fails if regeneration produces any diff (`git diff --exit-code`).  
* Truth remains authoritative: workflow changes that affect required gates must update truth (by regeneration) in the same PR.

**Proof:**  
`docs/proofs/2.16.4C_truth_sync_<UTC>.log`  
Must include: PR HEAD SHA, `npm run truth:sync` output, and `git diff --name-only` showing **no changes** after sync.

**Gate:**  
`truth-sync-enforced` (merge-blocking)

**Fails if:**  
`npm run truth:sync` produces any diff, output is non-deterministic, or required checks list cannot be derived cleanly.

---

2.16.5 — Governance-Change Justification (Human Contract, Minimal Fields)

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

# **2.16.5A — Foundation Boundary Contract**

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

# **2.16.5B — Repo Layout Separation**

Deliverable: Physical directory separation between Foundation and Product layers.

DoD:

* Foundation files reside under dedicated path (e.g., foundation/ or supabase/foundation/).  
* Product code resides under products/\<product\_name\>/.  
* “No cross-write” rule documented: product code may not modify foundation except via defined upgrade protocol.  
* CI path filters reflect separation.

Proof:  
docs/proofs/2.16.5B\_repo\_layout\_separation\_.log

Gate:  
merge-blocking (governance)

---

# **2.16.5C — Foundation Invariants Suite**

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

# **2.16.5D — Lane Separation Enforcement (Foundation vs Product)**

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

# **2.16.5E — Foundation Versioning \+ Fork Protocol**

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

# **2.16.5F — Anti-Divergence Drift Detector**

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

# **2.16.5G — Product Scaffold Generator**

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

## **2.16.6 — Lane Policy Truth (Docs-Only / Governance / Runtime Classification)**

**Deliverable:** Machine-readable lane policy extracted from artifacts.

**DoD:**

* `truth/lane_policy.json` exists and defines:  
  * path matchers for lanes (docs-only, governance, runtime/db/security)  
  * for each lane: required checks set (names must match `truth/required_checks.json`)  
* Policy is deterministic (stable ordering).  
* Lane policy is referenced by CI topology audit (or lane enforcement gate).

**Proof:**  
`docs/proofs/2.16.6_lane_policy_truth_<UTC>.log`

**Gate:**  
`lane-policy-contract` (merge-blocking)

---

## **2.16.7 — Lane Enforcement Gate (No Misclassified PRs)**

**Deliverable:** PR lane is computed from changed files and required checks are enforced accordingly.

**DoD:**

* Gate computes PR lane using `truth/lane_policy.json`.  
* Gate asserts:  
  * docs-only PRs cannot skip governance-required checks if governance paths changed  
  * governance PRs must run full governance set  
  * runtime/db/security PRs cannot be treated as docs-only  
* Outputs computed lane \+ matched paths \+ required checks.

**Proof:**  
`docs/proofs/2.16.7_lane_enforcement_<UTC>.log`

**Gate:**  
`lane-enforcement` (merge-blocking)

---

## **2.16.8 — Stop-the-Line XOR Gate (Incident vs Waiver Enforcement)**

**Deliverable:** Mechanical enforcement of the “exactly one” stop-the-line acknowledgement rule.

**DoD:**

* Gate enforces XOR:  
  * either an INCIDENT entry exists **or**  
  * a WAIVER file exists with required format and explicit acknowledgement text  
* Fails if both exist or neither exists when stop-the-line is triggered.

**Proof:**  
`docs/proofs/2.16.8_stop_the_line_xor_<UTC>.log`

**Gate:**  
`stop-the-line-xor` (merge-blocking)

---

## **2.16.9 — Waiver Policy Truth \+ Rate Limit Gate**

**Deliverable:** Mechanical anti–waiver-spam limits encoded in truth and enforced.

**DoD:**

* `truth/waiver_policy.json` exists with:  
  * `window_days`  
  * `max_waivers_in_window`  
  * optional per-category limits (enum)  
* Gate counts waivers in the defined window and fails if limits exceeded.  
* Gate output includes counts \+ window \+ offending waivers.

**Proof:**  
`docs/proofs/2.16.9_waiver_rate_limit_<UTC>.log`

**Gate:**  
`waiver-rate-limit` (merge-blocking or alert-only, per your chosen policy)

---

## **2.16.10 — Robot-Owned File Guard (No Hand-Edits to Generated Outputs)**

**Deliverable:** Prevent silent corruption of machine-produced artifacts.

**DoD:**

* Gate defines robot-owned path allowlist (truth or script constants), including:  
  * `generated/**`  
  * `docs/proofs/**` (except new proof logs for the current PR objective)  
  * any other machine-produced outputs you designate  
* Gate fails if robot-owned files are edited outside allowed objective patterns.

**Proof:**  
`docs/proofs/2.16.10_robot_owned_guard_<UTC>.log`

**Gate:**  
`robot-owned-guard` (merge-blocking)

---

## **2.16.11 — Governance-Change Template Contract (Structured Fields)**

**Deliverable:** Ensure governance change justifications are structured and non-empty.

**DoD:**

* For governance-touch PRs, `GOVERNANCE_CHANGE_PR*.md` must exist.  
* Must include headings (string-exact):  
  * `What changed`  
  * `Why safe`  
  * `Risk`  
  * `Rollback`  
* Minimum non-whitespace content threshold per section (length floor).  
* Does not attempt to judge “quality,” only blocks empty boilerplate.

**Proof:**  
`docs/proofs/2.16.11_governance_change_template_<UTC>.log`

**Gate:**  
`governance-change-template-contract` (merge-blocking)

---

---

## 

## 

## **2.17 — Ported Files Stability Sweep (Authoritative)**

---

### **2.17.1 — Repository Normalization Contract**

**Deliverable:** Deterministic line-ending normalization for governed paths.

**DoD:**

* `.gitattributes` enforces LF \+ no-BOM for: `docs/**`, `generated/**`, `supabase/**`  
* `npm run sweep:normalize` runs `git add --renormalize` on allowlisted paths only.  
* Running twice produces zero diff.  
* Any renormalization diff \= failure.

**Proof:**  
`docs/proofs/2.17.1_normalize_sweep_<UTC>.log`

**Gate:**  
`ci_normalize_sweep` fails if any diff is detected.

---

### **2.17.2 — Encoding & Hidden Character Audit**

**Deliverable:** Forbidden character sweep.

**DoD (blocking only):**

* No BOM present.  
* No zero-width characters.  
* No control characters (except tab, LF, CR).  
* UTF-8 consistency may be reported alert-only.

**Proof:**  
`docs/proofs/2.17.2_encoding_audit_<UTC>.log`

**Gate:**  
`ci_encoding_audit` fails only on forbidden classes.

---

### **2.17.3 — Absolute Path / Machine Leak Audit**

**Deliverable:** Repo-relative path enforcement (scoped to explicit high-risk outputs).

**DoD:**

* **Blocking scope (explicit allowlist):**  
  * `generated/**`  
  * `docs/proofs/**` (including `manifest.json`)  
* No absolute machine roots within blocking scope:  
  `C:\`, `C:/`, `/Users/`, `/home/runner/`  
* Freeform documentation (`docs/**` outside `docs/proofs/**`) is alert-only.

**Proof:**  
`docs/proofs/2.17.3_path_leak_audit_<UTC>.log`

**Gate:**  
`ci_path_leak_audit` blocks only on blocking scope.

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

**Proof:**  
`docs/proofs/2.17.4_parser_fixture_check_<UTC>.log`

**Gate:**  
`ci_validator` must pass for fixture pack \+ comparator.

## ---

## **3 — Automation Build (required)**

### **3.1 Automation contract acceptance**

Deliverable: Scripts obey AUTOMATION.md command separation.  
DoD:  
Automation behaviors match Checklist 3.1 exactly.  
Proof log demonstrates each command mode behavior (handoff/ship/green).  
Checklist 3.1 (non-DoD):  
handoff may write truth artifacts only; cannot commit/push.  
handoff:commit is the only publisher; may push PR branch only.  
ship verify-only; no writes/commits/push; never waits/polls CI.  
green:\* gates-only; never runs generators.  
Proof: docs/proofs/3.1\_automation\_contract\_.log  
Gate: automation-contract (merge-blocking)

### **3.2 Command contract contradiction closure (handoff:commit push semantics)**

Deliverable: Publishing semantics are unambiguous.  
DoD:  
handoff:commit refuses detached HEAD and refuses pushing to main.  
handoff:commit pushes current branch only and prints remote ref pushed.  
Proof: docs/proofs/3.2\_handoff\_commit\_push\_.log  
Gate: handoff-commit-safety (merge-blocking)

### **3.3 Ship guard (LOCKED choice)**

Deliverable: ship is always verify-only.  
DoD:  
ship fails on dirty tree or disallowed branch.  
ship fails if it produces any diffs.  
Proof: docs/proofs/3.3\_ship\_guard\_.log  
Gate: ship-guard (merge-blocking)

### **3.4 QA requirements truth (schema \+ lock)**

Deliverable: QA checklist is structured and can’t be weakened silently.  
DoD:  
qa\_requirements.json validates against qa\_requirements.schema.json.  
Any change requires version bump \+ governance-change proof (enforced).  
Proof: docs/proofs/3.4\_qa\_requirements\_.log  
Gate: qa-requirements-contract (merge-blocking)

### **3.5 QA verify (merge-blocking)**

Deliverable: QA verification is deterministic.  
DoD:  
npm run qa:verify emits STATUS PASS/FAIL based only on truth \+ proofs.  
It validates manifest hashes \+ required proofs exist for PR scope.  
Proof: docs/proofs/3.5\_qa\_verify\_.log  
Gate: qa-verify (merge-blocking)

### **3.6 Docs publish contract (docs:push) (required)**

Deliverable: Docs publishing cannot mutate robot-owned outputs.  
DoD:  
docs:push refuses detached HEAD, refuses pushing to main, and requires clean tree.  
docs:push refuses if diff touches robot-owned paths.  
Proof: docs/proofs/3.6\_docs\_push\_.log  
Gate: docs-push-contract (merge-blocking)

### **3.7 Robot-owned generator enforcement (NEW, mandatory)**

Deliverable: Generator outputs cannot be produced/modified outside handoff:commit.  
DoD:  
CI fails if `generated/**`, `docs/proofs/**`, or `docs/handoff_latest.txt` are modified without robot-owned publisher conditions.  
Proof: docs/proofs/3.7\_robot\_owned\_publish\_guard\_.log  
Gate: robot-owned-publish-guard (merge-blocking)

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

**4.2a Command Smoke (DB lane) (mandatory)**  
 **Deliverable:** DB-coupled commands run end-to-end.  
 **DoD:** On a machine with Supabase running, these complete without crash:

* `green:once`  
* `green:twice`  
* `handoff` *(may write artifacts)*  
* `ship` *(verify-only; must produce zero diffs on main)*

 **Proof:** `docs/proofs/4.2a_command_smoke_db_<UTC>.log`  
 **Gate:** lane-only `command-smoke-db` (promote to merge-blocking only after stable)

### **4.3 — Cloud baseline inventory (DB-metadata lane)**

Deliverable: Baseline inventory is real and schema-validated.  
DoD:  
Inventory JSON is produced under docs/proofs//cloud\_baseline\_inventory.json and validates.  
Proof includes least-priv evidence for inventory credentials.  
Checklist 4.3 (non-DoD):  
Inventory includes at minimum: extensions, schemas, roles, grants, default privileges, publications, functions, triggers.  
Proof: docs/proofs/4.2\_cloud\_inventory\_.log (+ 4.2b...)  
Gate: lane-only cloud-inventory

---

## **5 — Governance Gates (CI required-now)**

Deliverable: Required merge-blocking gates exist before feature work.  
DoD:  
All merge-blocking gates listed below exist as workflow jobs string-exact and are in required\_checks.json.  
required\_checks\_contract proves there are no missing/phantom gates.

Required merge-blocking checks (must be in docs/truth/required\_checks.json):  
rebuild-mode-declared  
port-manifest  
port-governance-runnable  
truth-bootstrap  
policy-coupling  
required-checks-contract  
toolchain-contract-core  
**gitattributes-renormalize** (NEW)  
**docs-only-ci-skip** (NEW)  
proof-manifest  
proofs-append-only  
pr-scope  
qa-verify  
ship-guard  
automation-contract  
handoff-commit-safety  
docs-push-contract  
**robot-owned-publish-guard** (NEW)  
secrets-scan  
env-sanity  
stop-the-line  
governance-change-guard  
blocked-identifiers  
clean-room-replay  
pgtap  
schema-drift  
definer-safety-audit  
handoff-contract  
toolchain-contract-supabase

Lane-only (must be in docs/truth/lane\_checks.json until promoted):  
cloud-baseline, cloud-inventory, cloud-migration-parity, cloud-surface  
surface-truth, e2e, weweb-drift, stable-declare, release-workflow-guard

Proof: docs/proofs/5.0\_required\_gates\_.md  
Gate: enforced by required-checks-contract

---

## **6 — Greenfield Schema Build (REBUILD MODE)**

### **6.1 Baseline migrations (from scratch)**

Deliverable: Initial baseline migrations authored new.  
DoD:  
Baseline migrations exist and are authored new (no copied legacy files).  
Clean-room replay passes on empty DB for the baseline.  
Proof: docs/proofs/6.1\_greenfield\_baseline\_migrations\_.log  
Gate: clean-room-replay \+ schema-drift (merge-blocking)

### **6.2 SECURITY DEFINER safety (mandatory)**

Deliverable: SD is allowlisted, audited, and negative-tested.  
DoD:  
Any SD function is allowlisted and audit passes.  
pgTAP negative proof exists for SD membership checks.  
Proof: docs/proofs/6.2\_definer\_audit\_.log  
Gate: definer-safety-audit (merge-blocking)

### **6.3 Tenant integrity suite**

Deliverable: Tenant isolation proven with negative proofs.  
DoD:  
pgTAP tenant isolation suite passes.  
Suite includes negative tests for teleportation/write bypass.  
Proof: docs/proofs/6.3\_tenant\_integrity\_.log  
Gate: pgtap (merge-blocking)

### **6.4 Tenant-owned table selector (mechanical)**

Deliverable: Tenant-owned table definition is auditable.  
DoD:  
Selector truth exists and enumerator asserts RLS enabled on selected tables.  
pgTAP rejects permissive policy patterns on selected tables.  
Proof: docs/proofs/6.4\_rls\_structural\_audit\_.log  
Gate: pgtap (merge-blocking)

### **6.5 Blocked identifiers lint**

Deliverable: Ghost carriers denylisted mechanically.  
DoD:  
blocked\_identifiers.json exists and lint fails on references.  
Proof shows lint run and PASS condition.  
Proof: docs/proofs/6.5\_blocked\_identifiers\_.log  
Gate: blocked-identifiers (merge-blocking)

### **6.6 Product core tables (MAO \+ Deals)**

Deliverable: Core domain tables exist (deals \+ MAO inputs/outputs) with calc\_version binding.  
 DoD:

* Tables exist for: deals, deal\_inputs, deal\_outputs (or equivalent), calc\_versions.

* Every persisted MAO/Deal row stores: calc\_version \+ assumptions snapshot reference.

* No nullable “tenant\_id” on tenant-owned tables.  
   Proof: docs/proofs/6.6\_product\_core\_tables\_.md  
   Gate: merge-blocking (runtime)

### **6.7 Share-link surface (public deal packet)**

Deliverable: Public share-link mechanism exists without breaking tenant isolation.  
 DoD:

* Share token table exists (random, non-guessable token; expiry optional).

* Share link only exposes explicitly allowlisted fields (packet view).

* Negative tests prove: token cannot reveal other tenant data.  
   Proof: docs/proofs/6.7\_share\_link\_surface\_.md  
   Gate: merge-blocking (security)

### **6.8 Seat \+ role model (per-seat billing-ready)**

Deliverable: Tenant membership \+ roles modeled cleanly for per-seat pricing.  
 DoD:

* Tables exist for: tenants, memberships (user\_id, tenant\_id, role), seat\_state (optional).

* Roles are minimal: owner/admin/member (no fantasy roles).

* RLS (Row Level Security) policies align with role model.  
   Proof: docs/proofs/6.8\_seat\_role\_model\_.md  
   Gate: merge-blocking (security)

---

## **7 — Schema \+ Privilege Truth (Deterministic)**

### **7.1 Schema snapshot generation**

Deliverable: Schema truth reproducible.  
DoD:  
generated/schema.sql is generated deterministically.  
Drift check passes with no unexpected delta.  
Proof: docs/proofs/7.1\_schema\_snapshot\_.log  
Gate: schema-drift (merge-blocking)

### **7.2 Privilege truth \+ default privileges lockdown**

Deliverable: Privileges \+ default privileges are truth.  
DoD:  
Privilege truth exists including default privileges state.  
Drift check detects and fails privilege/default privilege regressions.  
Proof: docs/proofs/7.2\_privilege\_truth\_.log  
Gate: schema-drift \+ pgtap (merge-blocking)

### **7.3 Contracts snapshot discipline**

Deliverable: Contracts snapshot changes are coupled to docs.  
DoD:  
If contracts snapshot changes, CONTRACTS.md changes in same PR.  
Gate fails on snapshot change without doc change.  
Proof: docs/proofs/7.3\_contracts\_policy\_.log  
Gate: policy-coupling (merge-blocking)

### **7.4 Entitlement truth (plan/seat source of truth)**

Deliverable: Entitlement truth is deterministic and auditable (no “magic UI gates”).  
 DoD:

* A single “entitled?” function/view exists (server-side truth).

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

---

## **8 — Clean-Room Replay (Core)**

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

## **9 — Surface Truth (PostgREST Exposure) (Introduced Later)**

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

Deliverable: Reload isn’t contradictory.  
DoD:  
Canonical reload is deploy-lane only and documented.  
Cloud harness includes reload evidence; local harness does not claim reload.  
Proof: docs/proofs/9.3\_reload\_contract\_.md  
Gate: enforced in deploy lane \+ release lane

---

## **10 — WeWeb Integration (Scope-controlled)**

### **10.1 WeWeb smoke (optional until “WeWeb in scope”)**

Deliverable: WeWeb connects using contracts.  
DoD:  
WeWeb uses allowed RPC surfaces per contract.  
Proof shows access patterns and no forbidden direct calls.  
Proof: docs/proofs/10.1\_weweb\_smoke\_.md  
Gate: lane-only unless promoted

### **10.2 WeWeb drift guard (if WeWeb in scope)**

Deliverable: WeWeb can’t silently switch to direct table calls.  
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

* UI displays a deterministic “blocked because entitlement” state.

* No “partial access” inconsistencies.  
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

* Support playbook exists for “payment failed → access degraded” states.  
   Proof: docs/proofs/11.9\_entitlement\_cutover\_checklist\_.md  
   Gate: merge-blocking (release)

---

## **12 — PR Scope Rules (prevents “cheat” PRs)**

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

