$ErrorActionPreference = "Stop"

$base = if ($env:GITHUB_BASE_REF) { "origin/$env:GITHUB_BASE_REF" } else { "origin/main" }

Write-Host "=== calc-version-registry: calc_version change protocol ==="
Write-Host "Base ref: $base"

$changed = (git diff --name-only "$base...HEAD" 2>&1) -split "`n" | Where-Object { $_ -ne "" }

$registryPath = "docs/truth/calc_version_registry.json"
$tokens = @("calc_version","calc_versions","calculate_","compute_","pricing_","commission_","fee_","rate_")

$calcLogicFiles = @()

foreach ($file in $changed) {
  if ($file -notmatch "^supabase/migrations/.*\.sql$") { continue }
  if (-not (Test-Path $file)) { continue }
  $content = Get-Content $file -Raw
  foreach ($token in $tokens) {
    if ($content -imatch [Regex]::Escape($token)) {
      $calcLogicFiles += $file
      Write-Host "  CALC-LOGIC: $file (matched token: $token)"
      break
    }
  }
}

$registryChanged = $changed -contains $registryPath

Write-Host ""
Write-Host "Calc-logic files changed: $($calcLogicFiles.Count)"
Write-Host "calc_version_registry.json changed: $registryChanged"
Write-Host ""

if ($calcLogicFiles.Count -gt 0 -and -not $registryChanged) {
  Write-Host "Changed calc-logic files:"
  $calcLogicFiles | ForEach-Object { Write-Host "  - $_" }
  Write-Error "CALC_VERSION_REGISTRY FAIL: calc-logic files changed without docs/truth/calc_version_registry.json update in the same PR."
  exit 1
}

Write-Host "calc-version-registry: PASS"
exit 0
