$ErrorActionPreference = "Stop"

function Pass([string]$msg) { Write-Host ("PASS: " + $msg) }
function Fail([string]$msg) { Write-Error ("FAIL: " + $msg); exit 1 }
function Assert-Contains([string]$file, [string]$pattern, [string]$label) {
  if (!(Test-Path $file)) { Fail ("MISSING FILE: " + $file) }
  $txt = Get-Content $file -Raw
  if ($txt -match $pattern) { Pass $label }
  else { Fail $label }
}
function Assert-NotContains([string]$file, [string]$pattern, [string]$label) {
  if (!(Test-Path $file)) { Fail ("MISSING FILE: " + $file) }
  $txt = Get-Content $file -Raw
  if ($txt -notmatch $pattern) { Pass $label }
  else { Fail $label }
}

Write-Host "=== handoff-commit-safety-contract ==="

# handoff_commit.ps1 exists
if (!(Test-Path "scripts/handoff_commit.ps1")) { Fail "scripts/handoff_commit.ps1 missing" }
Pass "handoff_commit.ps1 exists"

# Detached HEAD refusal
Assert-Contains "scripts/handoff_commit.ps1" "HEAD.*detached|detached.*HEAD|abbrev-ref HEAD.*HEAD" "handoff:commit: refuses detached HEAD"
Assert-Contains "scripts/handoff_commit.ps1" "throw.*Blocked.*detached|throw.*detached" "handoff:commit: throws on detached HEAD"

# Refuses main -- auto-creates PR branch
Assert-Contains "scripts/handoff_commit.ps1" "branch.*eq.*main|main.*branch" "handoff:commit: refuses main branch"
Assert-Contains "scripts/handoff_commit.ps1" "pr/handoff-artifacts" "handoff:commit: auto-creates PR branch"

# Pushes current branch only
Assert-Contains "scripts/handoff_commit.ps1" "git push.*origin.*branch|push.*origin.*branch" "handoff:commit: pushes current branch only"
Assert-Contains "scripts/handoff_commit.ps1" "Pushed:" "handoff:commit: prints remote ref pushed"

Write-Host "HANDOFF_COMMIT_SAFETY_CONTRACT_OK"
exit 0