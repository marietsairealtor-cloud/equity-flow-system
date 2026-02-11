
## Contract — PROOF_SCRIPTS_HASH Authority

Authority Source:
docs/artifacts/AUTOMATION.md

### Contract Guarantees

1. Script list declared exactly once.
2. Order is authoritative.
3. Encoding explicitly UTF-8 (no BOM).
4. In-memory newline normalization before hashing.
5. Deterministic framing.
6. SHA-256 lowercase hex output.

### Validator Obligations

Validator must:
- Parse authority section markers exactly.
- Extract script list deterministically.
- Reject missing header or end marker.
- Reject empty script list.
- Reject hash mismatch.
- Reject post-proof non-proof changes.

No inference.
No globbing.
No silent fallback.

