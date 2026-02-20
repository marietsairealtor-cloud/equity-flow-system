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

Write-Host "=== docs-push-contract ==="

# docs_push.ps1 exists
if (!(Test-Path "scripts/docs_push.ps1")) { Fail "scripts/docs_push.ps1 missing" }
Pass "docs_push.ps1 exists"

# Detached HEAD refusal
Assert-Contains "scripts/docs_push.ps1" "abbrev-ref HEAD" "docs:push: detached HEAD check exists"
Assert-Contains "scripts/docs_push.ps1" "throw.*Blocked.*detached|throw.*detached" "docs:push: throws on detached HEAD"

# Refuses main
Assert-Contains "scripts/docs_push.ps1" "branch.*eq.*main|main.*branch" "docs:push: refuses main branch"
Assert-Contains "scripts/docs_push.ps1" "throw.*Blocked.*main|throw.*main" "docs:push: throws on main"

# Requires clean tree
Assert-Contains "scripts/docs_push.ps1" "git status --porcelain" "docs:push: clean tree check exists"
Assert-Contains "scripts/docs_push.ps1" "throw.*Blocked.*clean|throw.*clean" "docs:push: throws on dirty tree"

# Refuses robot-owned paths
Assert-Contains "scripts/docs_push.ps1" "robot[Oo]wned|docs/proofs|generated/" "docs:push: robot-owned path check exists"
Assert-Contains "scripts/docs_push.ps1" "throw.*Blocked.*robot|throw.*robot" "docs:push: throws on robot-owned diff"

Write-Host "DOCS_PUSH_CONTRACT_OK"
exit 0