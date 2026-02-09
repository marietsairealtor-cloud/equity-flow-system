# PROOF_REDACTION__ (Escape Hatch)

Use ONLY for: accidental secrets or corrupted proof artifacts.

Rule:
- Any edit/delete of an existing file under docs/proofs/** MUST be paired in the same PR with this file (updated) explaining:
  - what changed (file path)
  - why (secret/corruption)
  - what replaced it (new proof filename, if any)
  - how integrity was restored (updated manifest.json)

If secret-related:
- Add an INCIDENTS entry and ensure secrets-scan passes.

Template (fill per event):
- Date (UTC):
- PR:
- File(s) redacted/changed:
- Reason:
- Replacement proof (if any):
- Verification (commands + output):