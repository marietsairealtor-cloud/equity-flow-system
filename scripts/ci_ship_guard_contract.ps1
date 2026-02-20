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

Write-Host "=== ship-guard-contract ==="

# ci_ship_guard.ps1 exists
if (!(Test-Path "scripts/ci_ship_guard.ps1")) { Fail "scripts/ci_ship_guard.ps1 missing" }
Pass "ci_ship_guard.ps1 exists"

# Branch enforcement
Assert-Contains    "scripts/ci_ship_guard.ps1" "branch.*main|main.*branch" "ship-guard: branch enforcement exists"
Assert-Contains    "scripts/ci_ship_guard.ps1" "throw.*Blocked" "ship-guard: throws on violation"

# Clean tree enforcement
Assert-Contains    "scripts/ci_ship_guard.ps1" "git status --porcelain" "ship-guard: clean tree check exists"

# Artifact diff check
Assert-Contains    "scripts/ci_ship_guard.ps1" "git diff" "ship-guard: artifact diff check exists"

# ship.mjs does not commit or push
Assert-NotContains "scripts/ship.mjs" "git commit" "ship.mjs: no git commit"
Assert-NotContains "scripts/ship.mjs" "(?m)^\s*[^/].*git push" "ship.mjs: no git push"

# ship.mjs does not run generators
Assert-NotContains "scripts/ship.mjs" "gen_schema|gen_contracts|run handoff|npm.*handoff" "ship.mjs: no generators"

Write-Host "SHIP_GUARD_CONTRACT_OK"
exit 0