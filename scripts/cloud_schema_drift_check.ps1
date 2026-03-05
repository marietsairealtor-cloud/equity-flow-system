# cloud_schema_drift_check.ps1
# Operator-run only. Never executed in CI.
# Compares live cloud project schema against generated/schema.sql.
# Requires SUPABASE_DB_URL environment variable set to the live cloud DB connection string.
# Output should be captured and finalized via: npm run proof:finalize

$ErrorActionPreference = "Stop"

Write-Host "=== cloud_schema_drift_check: Studio mutation guard ==="
Write-Host "Date: $(Get-Date -Format 'o')"
Write-Host ""

if (-not $env:SUPABASE_DB_URL) {
  Write-Error "DRIFT_CHECK FAIL: SUPABASE_DB_URL environment variable is not set. Set it to the live cloud DB connection string before running this script."
  exit 1
}

$localSchema = "generated/schema.sql"
if (-not (Test-Path $localSchema)) {
  Write-Error "DRIFT_CHECK FAIL: $localSchema not found. Run npm run handoff first."
  exit 1
}

Write-Host "Local schema: $localSchema"
Write-Host "Cloud DB: [REDACTED — connection string not logged]"
Write-Host ""

# Dump cloud schema to temp file
$tempSchema = [System.IO.Path]::GetTempFileName() + ".sql"
Write-Host "Dumping cloud schema..."
try {
  $env:PGPASSWORD = ($env:SUPABASE_DB_URL -replace '.*:(.*)@.*','$1')
  pg_dump --schema-only --schema=public $env:SUPABASE_DB_URL -f $tempSchema 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Error "DRIFT_CHECK FAIL: pg_dump failed with exit code $LASTEXITCODE"
    exit 1
  }
} finally {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}

Write-Host "Cloud schema dumped. Comparing against local..."
Write-Host ""

# Normalize and diff
$local = (Get-Content $localSchema -Raw) -replace "`r`n","`n" -replace "\s+$",""
$cloud = (Get-Content $tempSchema -Raw) -replace "`r`n","`n" -replace "\s+$",""
Remove-Item $tempSchema -ErrorAction SilentlyContinue

if ($local -eq $cloud) {
  Write-Host "DRIFT_CHECK: NO DRIFT DETECTED"
  Write-Host "Cloud schema matches generated/schema.sql exactly."
  Write-Host "STATUS: PASS"
  exit 0
} else {
  Write-Host "DRIFT_CHECK: DRIFT DETECTED"
  Write-Host "Cloud schema diverges from generated/schema.sql."
  Write-Host ""
  # Print a simple diff summary
  $localLines = $local -split "`n"
  $cloudLines = $cloud -split "`n"
  $localOnly  = $localLines | Where-Object { $cloudLines -notcontains $_ } | Select-Object -First 20
  $cloudOnly  = $cloudLines | Where-Object { $localLines -notcontains $_ } | Select-Object -First 20
  if ($localOnly) {
    Write-Host "=== In local schema.sql but NOT in cloud (missing from cloud) ==="
    $localOnly | ForEach-Object { Write-Host "  - $_" }
  }
  if ($cloudOnly) {
    Write-Host "=== In cloud but NOT in local schema.sql (unauthorized drift) ==="
    $cloudOnly | ForEach-Object { Write-Host "  + $_" }
  }
  Write-Host ""
  Write-Host "STATUS: FAIL — compensating migration required per STUDIO_MUTATION_POLICY.md"
  exit 1
}
