GOVERNANCE_CHANGE_PR127.md
What changed

docs/artifacts/BUILD_ROUTE_V2_4.md — Added item 10.8.12 (Automate Cloud Migration Parity Registry). Converts cloud_migration_parity.json from hand-authored (§3.0.4c exempt) to machine-derived via handoff.

Why safe

Eliminates manual step that has caused CI failures when forgotten. DEVLOG shows manual bump required on nearly every migration PR since 8.3.
No enforcement change — same file, same validation, same CI checks. Only the authoring path changes (manual → handoff).
§3.0.4c exemption removal is correct — file becomes machine-derived, which is the standard path for truth artifacts.

Risk
None. Build Route specification addition only. No implementation in this PR.
Rollback
Revert PR. 10.8.12 removed. Manual authoring continues.