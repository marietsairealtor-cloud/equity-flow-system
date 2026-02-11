2026-02-11 — Build Route v2.16 — CI Semantic Contract
Objective
- Merge 2.16.3 CI Semantic Contract (Targeted Anti–No-Op)

Changes
- scripts/ci_semantic_contract.mjs parser + allowlist updates
- docs/proofs/manifest.json updated
- docs/proofs/2.16.3_ci_semantic_contract_20260211_180456Z.log

Proof
- Non-strict: RESULT=PASS EXITCODE=0
- Strict: RESULT=PASS EXITCODE=0
- PROOF_COMMIT_BINDING_OK
- PROOF_MANIFEST_OK

DoD
- Gate script updated
- Proof log exists
- Manifest updated
- Strict-mode behavior verified

Status
✅ PASS


2026-02-11 — Build Route v2.16 — CI Semantic Contract (Targeted Anti–No-Op)
Deliverable
- Semantic validation that required CI jobs actually execute gates.

DoD
- If .github/workflows/** changes in PR:
  * semantic contract is merge-blocking
- Otherwise:
  * runs alert-only (PR + scheduled)
- Validator asserts required jobs:
  * invoke allowlisted gate scripts
  * are not noop / echo-only exits

Proof
- docs/proofs/2.16.3_ci_semantic_contract_20260211_180456Z.log

Gate
- ci-semantic-contract
(merge-blocking only on workflow changes)

