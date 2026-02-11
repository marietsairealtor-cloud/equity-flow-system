
## 2.16.2A — Proof Binding Workflow (Hard Rule)

### Commit Order Discipline

1. Non-proof changes commit first.
2. Proof log + manifest commit second.
3. After proof commit:
   - Only files under docs/proofs/** may change.

Any violation triggers:
POST_PROOF_NON_PROOF_CHANGE

### PROOF_HEAD Requirements

- Must be full 40-hex SHA.
- Must bind correctly within PR graph (validator enforced).

### Manifest Requirements

- Keys must be repo-relative.
- Keys must use forward slashes.
- No absolute drive paths allowed.
- JSON must parse cleanly.

### Hash Authority Discipline

PROOF_SCRIPTS_HASH is derived only from:

### proof-commit-binding — scripts hash authority

- Script list is string-exact.
- No globbing.
- Files hashed in listed order.
- UTF-8 (no BOM).
- CRLF and CR normalized to LF.
- Framing:
  FILE:<relpath>\n
  normalized text
  \n
- SHA-256 lowercase hex.

This section is the single source of truth.
Validator must implement it exactly.

