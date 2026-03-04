$ErrorActionPreference = "Stop"
Write-Host "=== entitlement-policy-coupling gate ==="

$base = if ($env:BASE_REF) { $env:BASE_REF } else { "origin/main" }

# Get changed files in PR
$changed = (git diff --name-only $base -- 2>&1 | Out-String) -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() }

# Check if entitlement function changed (migration or schema)
$entitlementChanged = $false
foreach ($f in $changed) {
  if ($f -match 'supabase/migrations/.*\.sql$' -or $f -eq 'generated/schema.sql') {
    $content = Get-Content $f -Raw -ErrorAction SilentlyContinue
    if ($content -and $content -match 'get_user_entitlements_v1') {
      $entitlementChanged = $true
      Write-Host "ENTITLEMENT_CHANGED: $f"
      break
    }
  }
}

if (-not $entitlementChanged) {
  Write-Host "ENTITLEMENT_POLICY_COUPLING: no entitlement function changes detected"
  Write-Host "STATUS: PASS"
  exit 0
}

# Entitlement changed — CONTRACTS.md must also change
$contractsChanged = $changed | Where-Object { $_ -match 'docs/artifacts/CONTRACTS\.md$' }
if (-not $contractsChanged) {
  Write-Host "FAIL: entitlement function changed but docs/artifacts/CONTRACTS.md was not updated in this PR"
  Write-Host "STATUS: FAIL"
  exit 1
}

Write-Host "ENTITLEMENT_POLICY_COUPLING: entitlement function changed AND CONTRACTS.md updated"
Write-Host "STATUS: PASS"
exit 0
