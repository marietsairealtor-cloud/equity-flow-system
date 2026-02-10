
## Stop-the-line procedure
1. CI reports stop-the-line failure class.
2. Choose exactly one:
   - Add INCIDENT entry (with PR + FailureClass), or
   - Add WAIVER_PR<NNN>.md with text: QA: NOT AN INCIDENT (valid for that PR only).
3. Re-run CI; merge only after PASS.


## 2026-02-10 — Governance-change justification (2.15)
- If PR touches governance paths (docs/truth/**, .github/workflows/**, scripts/**, governance artifacts), PR MUST include: docs/governance/GOVERNANCE_CHANGE_PR<NNN>.md
- DEVLOG-only PRs are exempt.
