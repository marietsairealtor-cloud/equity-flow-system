# Governance Change — PR087

## What changed
Fixed `scripts/gen_write_path_registry.ps1` to use `$env:OS -ne "Windows_NT"` instead of `$IsLinux` for cross-platform psql path resolution. The `$IsLinux` automatic variable does not exist in Windows PowerShell 5 (powershell.exe), only in PowerShell 7 (pwsh). This caused `npm run handoff` to fail on Windows.

## Why safe
Single-line conditional change. No logic change — same branch paths, same psql resolution. Only the platform detection method changed. Behavior on Linux CI is identical ($env:OS is not set on Linux, so the condition evaluates the same as $IsLinux = $true).

## Risk
None. The fix restores handoff functionality on Windows that was broken by the 8.0.3 cross-platform change. CI behavior unchanged.

## Rollback
Revert the single file change to scripts/gen_write_path_registry.ps1. Single-commit revert.