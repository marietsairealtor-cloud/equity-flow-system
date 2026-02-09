
## Stop-the-line procedure
1. CI reports stop-the-line failure class.
2. Choose exactly one:
   - Add INCIDENT entry (with PR + FailureClass), or
   - Add WAIVER_PR<NNN>.md with text: QA: NOT AN INCIDENT (valid for that PR only).
3. Re-run CI; merge only after PASS.

