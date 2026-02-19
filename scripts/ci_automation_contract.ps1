$ErrorActionPreference = "Stop"

function Pass([string]$msg) { Write-Host ("PASS: " + $msg) }
function Fail([string]$msg) { Write-Error ("FAIL: " + $msg); exit 1 }

# Assert a file contains a pattern
function Assert-Contains([string]$file, [string]$pattern, [string]$label) {
  $txt = Get-Content $file -Raw
  if ($txt -match $pattern) { Pass $label }
  else { Fail $label }
}

# Assert a file does NOT contain a pattern
function Assert-NotContains([string]$file, [string]$pattern, [string]$label) {
  $txt = Get-Content $file -Raw
  if ($txt -notmatch $pattern) { Pass $label }
  else { Fail $label }
}

Write-Host "=== automation-contract ==="

# handoff: must write artifacts; must NOT commit or push
Assert-Contains    "scripts/handoff.ps1" "Write-Utf8NoBomLf|gen_schema|gen_contracts" "handoff: writes truth artifacts"
Assert-NotContains "scripts/handoff.ps1" "gits+commit" "handoff: no git commit"
Assert-NotContains "scripts/handoff.ps1" "gits+push" "handoff: no git push"

# handoff:commit: must commit and push; must refuse main
Assert-Contains    "scripts/handoff_commit.ps1" "git commit" "handoff:commit: commits"
Assert-Contains    "scripts/handoff_commit.ps1" "git push" "handoff:commit: pushes"
Assert-Contains    "scripts/handoff_commit.ps1" "branch.*main|main.*branch" "handoff:commit: main branch guard"

# ship: must not commit, push, or run generators
Assert-NotContains "scripts/ship.mjs" "gits+commit" "ship: no git commit"
Assert-NotContains "scripts/ship.mjs" "gits+push" "ship: no git push"
Assert-NotContains "scripts/ship.mjs" "gen_schema|gen_contracts|run handoff|npm.*handoff" "ship: no generators"

# green:*: must not run generators
Assert-NotContains "scripts/green_gate.mjs" "gen_schema|gen_contracts|run handoff|npm.*handoff" "green:*: no generators"
Assert-Contains    "scripts/green_gate.mjs" "lint|build|pgtap" "green:*: runs gates"

Write-Host "AUTOMATION_CONTRACT_OK"
exit 0