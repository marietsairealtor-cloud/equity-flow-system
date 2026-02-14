# Governance Change PR004 — proof-commit-binding Windows parse hardening

## Summary
Harden scripts/ci_proof_commit_binding.ps1 to avoid Windows PowerShell parse failure caused by non-ASCII em dash usage in the authority header string.

## Why

pm run proof:commit-binding failed to parse on Windows due to mojibake / em dash tokenization (â€”), blocking governed proof enforcement.

## Change
- Replace embedded em dash byte usage with explicit [char]0x2014 construction for the header marker match.
- No change to policy semantics, marker text, or authority source (docs/artifacts/AUTOMATION.md).

## Safety / Impact
- Scope: enforcement script parsing reliability only.
- Behavior: same header marker requirement; same script list extraction; same hashing rules.
- Risk: low; reduces platform-specific false failures.

## Evidence
- Proof log: docs/proofs/fix_proof_commit_binding_windows_parse_20260214_220325Z.log
- Gates: 
pm run proof:manifest PASS; 
pm run proof:commit-binding PASS.