$ErrorActionPreference = "Stop"

# robot-owned-publish-guard (3.6)
# Distinct from robot-owned-guard (2.16.10).
# robot-owned-guard: prevents unauthorized EDITS to machine-produced files.
# robot-owned-publish-guard: prevents unauthorized GENERATION/PUBLICATION of machine-produced files.
# This gate asserts generator outputs only appear when published via handoff:commit.

git fetch origin main | Out-Null
$base = "origin/main"

$generatorPaths = @(
  "^generated/",
  "^docs/handoff_latest\.txt$"
)

$changed = (& git diff --name-only "$base...HEAD" 2>$null) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

Write-Host "=== robot-owned-publish-guard ==="
Write-Host "BASE=$base"
Write-Host "CHANGED_FILES=$($changed.Count)"

$violations = @()
foreach ($file in $changed) {
  $isGenerator = $false
  foreach ($pat in $generatorPaths) {
    if ($file -match $pat) { $isGenerator = $true; break }
  }
  if (-not $isGenerator) { continue }
  # Generator file in diff -- verify it was published via handoff:commit
  # handoff:commit commits with message "Update handoff artifacts"
  $commitMsg = (& git log --oneline "$base...HEAD" -- $file 2>$null)
  $validPublish = $commitMsg | Where-Object { $_ -match "Update handoff artifacts|handoff" }
  if (-not $validPublish) {
    $violations += $file
    Write-Host "VIOLATION: $file -- generator output modified outside handoff:commit"
  } else {
    Write-Host "OK: $file -- published via handoff:commit"
  }
}

if ($violations.Count -gt 0) {
  Write-Error "ROBOT_OWNED_PUBLISH_GUARD_FAIL: $($violations.Count) violation(s). Generator outputs must be produced via handoff:commit only."
  exit 1
}

Write-Host "ROBOT_OWNED_PUBLISH_GUARD_OK"
exit 0