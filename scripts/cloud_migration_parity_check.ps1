# scripts/cloud_migration_parity_check.ps1
# Gate: cloud-migration-parity (lane-only, operator-run)
# Build Route: 8.3 — Cloud migration parity guard
# Requires SUPABASE_DB_URL environment variable set to the live cloud DB connection string.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== cloud-migration-parity ==="

if (-not $env:SUPABASE_DB_URL) {
  Write-Error "cloud-migration-parity FAIL: SUPABASE_DB_URL not set. Set it to the live cloud DB connection string."
  exit 1
}

# Load pinned truth
$truthPath = "docs/truth/cloud_migration_parity.json"
if (-not (Test-Path $truthPath)) { Write-Error "cloud-migration-parity FAIL: $truthPath not found"; exit 1 }
$truth = Get-Content $truthPath -Raw | ConvertFrom-Json
Write-Host "Pinned migration tip: $($truth.migration_tip)"
Write-Host "Pinned migration count: $($truth.migration_count)"
Write-Host "Cloud project ref: $($truth.cloud_project_ref)"

# Find psql
if ($env:OS -ne "Windows_NT") {
  $psql = (Get-Command psql -ErrorAction SilentlyContinue).Source
  if (-not $psql) { $psql = "/usr/bin/psql" }
} else {
  $psql = "C:\Program Files\PostgreSQL\16\bin\psql.exe"
}

# Query cloud for applied migrations
Write-Host "Querying cloud DB for applied migrations..."
$cloudVersions = "SELECT version FROM supabase_migrations.schema_migrations ORDER BY version ASC;" | & $psql --tuples-only --no-align $env:SUPABASE_DB_URL 2>&1
if ($LASTEXITCODE -ne 0) { Write-Error "cloud-migration-parity FAIL: psql query failed: $cloudVersions"; exit 1 }

$cloudList = @($cloudVersions | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim() })
$cloudTip = $cloudList | Select-Object -Last 1
$cloudCount = $cloudList.Count

Write-Host "Cloud migration tip: $cloudTip"
Write-Host "Cloud migration count: $cloudCount"

# Compare repo migrations against cloud
$repoVersions = @(Get-ChildItem supabase/migrations/ -Name | Sort-Object | ForEach-Object { ($_ -split '_')[0] })

$fail = $false

# Check tip matches
if ($cloudTip -ne $truth.migration_tip) {
  Write-Host "FAIL: cloud tip ($cloudTip) does not match pinned tip ($($truth.migration_tip))"
  $fail = $true
} else {
  Write-Host "Cloud tip matches pinned tip: PASS"
}

# Check count matches
if ($cloudCount -ne $truth.migration_count) {
  Write-Host "FAIL: cloud count ($cloudCount) does not match pinned count ($($truth.migration_count))"
  $fail = $true
} else {
  Write-Host "Cloud count matches pinned count: PASS"
}

# Check repo versions are subset of cloud (all repo migrations applied)
foreach ($rv in $repoVersions) {
  if ($cloudList -notcontains $rv) {
    Write-Host "FAIL: repo migration $rv not found in cloud applied migrations"
    $fail = $true
  }
}
if (-not $fail) {
  Write-Host "All repo migrations present in cloud: PASS"
}

if ($fail) {
  Write-Host "cloud-migration-parity: FAIL"
  exit 1
}

Write-Host "cloud-migration-parity: PASS"
exit 0