# GOVERNANCE_CHANGE_PR<PR005>.md

## Summary

This PR updates governance workflow sequencing in docs/SOP_WORKFLOW.md.

Change:

* QA review timing moved to occur **after CI reaches green**.
* Workflow is now:

Implement → Proof → Open PR → CI green → QA APPROVE → Merge.

---

## Reason for Change

Recent objectives experienced repeated CI instability, creating repeated QA cycles before CI became stable.
This caused process churn where QA validation had to be repeated multiple times without meaningful signal.

Moving QA review to occur after CI green:

* Reduces non-actionable QA loops.
* Ensures QA reviews only stable candidate states.
* Improves workflow efficiency without weakening enforcement.

---

## Safety / Governance Impact

No reduction in governance guarantees.

Completion law remains unchanged:

PR opened → CI green → approved → merged.

Safety controls retained:

* Proof artifacts still required before PR.
* Manifest discipline unchanged.
* CI remains merge-blocking.
* QA approval still required before merge.

---

## Files Affected

* docs/SOP_WORKFLOW.md (Sections 3 and 4)

---

## Risk Assessment

Risk level: LOW.

This change modifies sequencing only; it does not alter:

* CI enforcement
* Required checks
* Proof binding
* Merge protections

---

## Validation

* SOP reviewed for internal coherence.
* Completion law remains consistent with Command for Chat.
* Workflow remains audit-compatible.

---

## Decision

Approved governance adjustment to reduce CI-related QA churn while preserving merge safety guarantees.