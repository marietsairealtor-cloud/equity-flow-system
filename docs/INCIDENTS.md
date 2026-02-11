
## 2026-02-11 — Incident: Absolute Path in Proof Manifest (2.16.2A)

### Summary
A proof artifact commit (dd38caa) wrote an absolute Windows path into docs/proofs/manifest.json:

C:/Users/.../docs/proofs/2.16.2A_hash_authority_contract_20260211_140739Z.log

This violated the repo-relative key requirement and caused gate instability.

### Root Cause Class
Contract fragility + path normalization omission.

- Manifest generator allowed absolute path input.
- No explicit repo-relative enforcement at write time.
- Authority contract newly introduced → surfaced hidden assumption.

### Detection
Detected during QA validation and byte-level inspection.
Gate also triggered POST_PROOF_NON_PROOF_CHANGE when proof discipline was violated.

### Remediation
- Removed absolute-path key.
- Rewrote manifest deterministically.
- Enforced repo-relative keys under docs/proofs/.
- Verified JSON validity.
- Confirmed no drive-letter patterns remain.

### Preventive Controls
- Manifest keys must be repo-relative POSIX.
- Authority section declares deterministic behavior.
- Validator enforces binding discipline.
- CI gate validates no post-proof non-proof changes.

Status: CLOSED

