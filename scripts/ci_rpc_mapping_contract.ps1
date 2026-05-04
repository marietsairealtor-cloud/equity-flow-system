$ErrorActionPreference = "Stop"
$base = if ($env:GITHUB_BASE_REF) { "origin/$env:GITHUB_BASE_REF" } else { "origin/main" }

Write-Host "=== rpc-mapping-contract: Public RPC mapping enforcement ==="
Write-Host "Base ref: $base"

$changed = (git diff --name-only "$base...HEAD" 2>&1) -split "`n" | Where-Object { $_ -ne "" }
Write-Host "Changed files:"
$changed | ForEach-Object { Write-Host "  $_" }
Write-Host ""

# Check if any migration files changed
$migrationsChanged = $changed | Where-Object { $_ -match "^supabase/migrations/" }

if (-not $migrationsChanged) {
  Write-Host "No migration changes detected. Skipping RPC mapping check."
  Write-Host "rpc-mapping-contract: PASS"
  exit 0
}

Write-Host "Migration changes detected. Checking for RPC additions/changes..."

# Scan changed migrations for function definitions
$rpcPattern = "CREATE\s+(OR\s+REPLACE\s+)?FUNCTION\s+public\.(\w+_v\d+)"
$newRpcs = @()
foreach ($mig in $migrationsChanged) {
  if (Test-Path $mig) {
    $content = Get-Content $mig -Raw
    $matches = [regex]::Matches($content, $rpcPattern, "IgnoreCase")
    foreach ($m in $matches) {
      $rpcName = $m.Groups[2].Value
      # Exclude known internal helpers
      if ($rpcName -notin @("require_min_role_v1", "current_tenant_id", "auth_user_exists_v1",
                             "check_workspace_write_allowed_v1", "create_active_workspace_seed_v1",
                             "process_workspace_retention_v1", "confirm_trial_v1",
                             "_intake_validate_pricing_assumptions_v1", "_intake_apply_mao_to_assumptions_v1",
                             "_intake_validate_deal_property_jsonb_v1")) {
        $newRpcs += $rpcName
      }
    }
  }
}

$newRpcs = $newRpcs | Sort-Object -Unique

if ($newRpcs.Count -eq 0) {
  Write-Host "No public RPC additions/changes in migrations."
  Write-Host "rpc-mapping-contract: PASS"
  exit 0
}

Write-Host "Public RPCs found in changed migrations:"
$newRpcs | ForEach-Object { Write-Host "  $_" }
Write-Host ""

# Check CONTRACTS.md for mapping entries
$contractsPath = "docs/artifacts/CONTRACTS.md"
$contractsContent = Get-Content $contractsPath -Raw
$contractsChanged = $changed -contains $contractsPath

$missing = @()
foreach ($rpc in $newRpcs) {
  if ($contractsContent -notmatch [regex]::Escape($rpc)) {
    $missing += $rpc
  }
}

if ($missing.Count -gt 0 -and -not $contractsChanged) {
  Write-Error "RPC_MAPPING_CONTRACT FAIL: PR adds/changes public RPCs but docs/artifacts/CONTRACTS.md was not updated."
  Write-Host "RPCs requiring mapping entry:"
  $missing | ForEach-Object { Write-Host "  $_" }
  Write-Host ""
  Write-Host "Required fields per RPC: name, Build Route item, purpose, security class, tenancy rule."
  exit 1
}

if ($missing.Count -gt 0) {
  Write-Error "RPC_MAPPING_CONTRACT FAIL: The following RPCs are missing from the mapping table in CONTRACTS.md:"
  $missing | ForEach-Object { Write-Host "  $_" }
  Write-Host ""
  Write-Host "Required fields per RPC: name, Build Route item, purpose, security class, tenancy rule."
  exit 1
}

# Validate mapping fields exist for each RPC
$requiredFields = @("Build Route", "Purpose", "Security", "Tenancy", "SECURITY DEFINER", "current_tenant_id")
$incomplete = @()
foreach ($rpc in $newRpcs) {
  # Find the table row for this RPC
  $rowPattern = "\|\s*" + [regex]::Escape($rpc) + "\s*\|([^|]*\|){4}"
  if ($contractsContent -notmatch $rowPattern) {
    $incomplete += "$rpc — missing or malformed table row (need 5 fields)"
  }
}

if ($incomplete.Count -gt 0) {
  Write-Error "RPC_MAPPING_CONTRACT FAIL: Incomplete mapping entries:"
  $incomplete | ForEach-Object { Write-Host "  $_" }
  exit 1
}

Write-Host "All public RPCs in changed migrations have complete mapping entries."
Write-Host "rpc-mapping-contract: PASS"
exit 0