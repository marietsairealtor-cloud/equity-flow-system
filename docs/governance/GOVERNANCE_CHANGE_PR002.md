# GOVERNANCE CHANGE — PR002
Item: 2.16.4 — proof-commit-binding ignores deleted proof files
- proof-commit-binding validates only added/modified proof artifacts (A/M).
- Deleted proof paths (D) are excluded from validation since content no longer exists.
