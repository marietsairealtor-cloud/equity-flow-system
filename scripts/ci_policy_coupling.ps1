$ErrorActionPreference = "Stop"

$base = if ($env:GITHUB_BASE_REF) { "origin/$env:GITHUB_BASE_REF" } else { "origin/main" }

Write-Host "=== policy-coupling: contracts snapshot discipline ==="
Write-Host "Base ref: $base"

$changed = (git diff --name-only "$base...HEAD" 2>&1) -split "`n" | Where-Object { $_ -ne "" }

Write-Host "Changed files:"
$changed | ForEach-Object { Write-Host "  $_" }

$snapshotPath   = "generated/contracts.snapshot.json"
$contractsMdPath = "docs/artifacts/CONTRACTS.md"

$snapshotChanged  = $changed -contains $snapshotPath
$contractsChanged = $changed -contains $contractsMdPath

Write-Host ""
Write-Host "Snapshot file ($snapshotPath) changed: $snapshotChanged"
Write-Host "CONTRACTS.md ($contractsMdPath) changed: $contractsChanged"
Write-Host ""

if ($snapshotChanged -and -not $contractsChanged) {
  Write-Error "POLICY_COUPLING FAIL: generated/contracts.snapshot.json changed without docs/artifacts/CONTRACTS.md changing in the same PR."
  exit 1
}

Write-Host "policy-coupling: PASS"
exit 0
