# ci_write_lock_coverage.ps1
# 10.8.11N1: Workspace Write Lock Coverage Gate
# Merge-blocking: verifies every in-scope workspace-write RPC calls
# check_workspace_write_allowed_v1() in its definition.
# Approved inline-check exceptions: submit_form_v1, lookup_share_token_v1
# Approved full exceptions: update_display_name_v1, restore_workspace_v1, billing/renewal path

$ErrorActionPreference = "Stop"

Write-Host "=== write-lock-coverage: Workspace write lock enforcement gate ==="

# Authoritative in-scope workspace-write RPCs that must call the helper
$helperRequiredRpcs = @(
  "create_deal_v1",
  "update_deal_v1",
  "create_farm_area_v1",
  "delete_farm_area_v1",
  "create_reminder_v1",
  "complete_reminder_v1",
  "create_share_token_v1",
  "update_workspace_settings_v1",
  "update_member_role_v1",
  "remove_member_v1",
  "invite_workspace_member_v1"
)

# Approved inline-check RPCs -- use subscription check without the shared helper
# because they resolve tenant via slug, not membership context
$inlineCheckRpcs = @(
  "submit_form_v1",
  "lookup_share_token_v1"
)

# Approved full exceptions: intentionally omit check_workspace_write_allowed_v1 (not normal
# workspace writes under expired lock — profile, archived restore after active billing, etc.)
$approvedFullExemptRpcs = @(
  "update_display_name_v1",
  "restore_workspace_v1"
)

foreach ($rpc in $approvedFullExemptRpcs) {
  if ($helperRequiredRpcs -contains $rpc) {
    Write-Error "WRITE_LOCK_COVERAGE: $rpc cannot be both helper-required and approved full-exempt"
    exit 1
  }
}

# Build final function definition map from migrations (last definition wins)
$migrationsDir = "supabase/migrations"
$migrationFiles = Get-ChildItem "$migrationsDir/*.sql" | Sort-Object Name

$functionDefs = @{}
foreach ($file in $migrationFiles) {
  $content = Get-Content $file.FullName -Raw
  # Match each function definition block individually
  $pattern = '(?is)CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+public\.(\w+)\s*\(.*?\)\s*RETURNS.*?\$\w*\$(.*?)\$\w*\$\s*;'
  $matches = [regex]::Matches($content, $pattern)
  foreach ($m in $matches) {
    $name = $m.Groups[1].Value
    $body = $m.Groups[2].Value
    $functionDefs[$name] = $body
  }
}

Write-Host "Functions found in migrations: $($functionDefs.Count)"
Write-Host ""

$missing = @()
$inlineMissing = @()

# Check helper-required RPCs
Write-Host "--- Checking helper-required RPCs ---"
foreach ($rpc in $helperRequiredRpcs) {
  if (-not $functionDefs.ContainsKey($rpc)) {
    Write-Host "  WARN: $rpc not found in migrations (may be defined in earlier baseline)"
    continue
  }
  $body = $functionDefs[$rpc]
  if ($body -notmatch "check_workspace_write_allowed_v1") {
    $missing += $rpc
    Write-Host "  FAIL: $rpc -- missing check_workspace_write_allowed_v1()"
  } else {
    Write-Host "  PASS: $rpc"
  }
}

Write-Host ""
Write-Host "--- Checking inline-check RPCs ---"
foreach ($rpc in $inlineCheckRpcs) {
  if (-not $functionDefs.ContainsKey($rpc)) {
    Write-Host "  WARN: $rpc not found in migrations"
    continue
  }
  $body = $functionDefs[$rpc]
  # Inline check RPCs must contain a subscription status check
  if ($body -notmatch "tenant_subscriptions" -or $body -notmatch "current_period_end") {
    $inlineMissing += $rpc
    Write-Host "  FAIL: $rpc -- missing inline subscription check"
  } else {
    Write-Host "  PASS: $rpc (inline check)"
  }
}

Write-Host ""
Write-Host "--- Approved full-exempt RPCs (documented; not helper-required) ---"
foreach ($rpc in $approvedFullExemptRpcs) {
  if ($functionDefs.ContainsKey($rpc)) {
    Write-Host "  SKIP: $rpc (approved exemption)"
  } else {
    Write-Host "  WARN: $rpc not found in migrations (may be baseline or renamed)"
  }
}

Write-Host ""
Write-Host "Helper-required failures: $($missing.Count)"
Write-Host "Inline-check failures: $($inlineMissing.Count)"

if ($missing.Count -gt 0 -or $inlineMissing.Count -gt 0) {
  Write-Host ""
  if ($missing.Count -gt 0) {
    Write-Host "RPCs missing check_workspace_write_allowed_v1():"
    $missing | ForEach-Object { Write-Host "  - $_" }
  }
  if ($inlineMissing.Count -gt 0) {
    Write-Host "RPCs missing inline subscription check:"
    $inlineMissing | ForEach-Object { Write-Host "  - $_" }
  }
  Write-Error "WRITE_LOCK_COVERAGE FAIL: One or more workspace-write RPCs are missing write lock enforcement."
  exit 1
}

Write-Host "write-lock-coverage: PASS"
exit 0