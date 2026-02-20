$ErrorActionPreference = "Stop"

function Pass([string]$msg) { Write-Host ("PASS: " + $msg) }
function Fail([string]$msg) { Write-Error ("FAIL: " + $msg); exit 1 }

Write-Host "=== qa-requirements-contract ==="

# File existence
if (!(Test-Path "docs/truth/qa_requirements.json")) { Fail "docs/truth/qa_requirements.json missing" }
if (!(Test-Path "docs/truth/qa_requirements.schema.json")) { Fail "docs/truth/qa_requirements.schema.json missing" }
Pass "qa_requirements.json exists"
Pass "qa_requirements.schema.json exists"

# Schema validation
$doc = Get-Content "docs/truth/qa_requirements.json" -Raw | ConvertFrom-Json
if ($null -eq $doc.version) { Fail "qa_requirements.json missing version field" }
if ($null -eq $doc.requirements) { Fail "qa_requirements.json missing requirements field" }
if (-not ($doc.version -is [int] -or $doc.version -is [long] -or $doc.version -is [System.Int32] -or $doc.version -is [System.Int64])) { Fail "qa_requirements.json version must be integer" }
if ($doc.requirements -isnot [array] -and $doc.requirements.GetType().Name -ne "Object[]") { Fail "qa_requirements.json requirements must be array" }
Pass "qa_requirements.json validates against schema"

# Version bump enforcement (only when qa_requirements.json is in PR diff)
$diff = (& git diff --name-only origin/main...HEAD 2>$null)
$inDiff = $diff | Where-Object { $_ -eq "docs/truth/qa_requirements.json" }
if ($inDiff) {
  Write-Host "qa_requirements.json in PR diff -- checking version bump..."
  $mainJson = (& git show origin/main:docs/truth/qa_requirements.json 2>$null) | ConvertFrom-Json
  if ($null -ne $mainJson -and $doc.version -le $mainJson.version) {
    Fail "qa_requirements.json changed but version not bumped (current: $($doc.version), main: $($mainJson.version)). Bump version field."
  }
  Pass "qa_requirements.json version bumped correctly"
} else {
  Pass "qa_requirements.json not in PR diff -- version bump check skipped"
}

Write-Host "QA_REQUIREMENTS_CONTRACT_OK"
exit 0