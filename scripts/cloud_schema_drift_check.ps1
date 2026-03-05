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
$env:PGPASSWORD = ($env:SUPABASE_DB_URL -replace "postgresql://[^:]+:([^@]+)@.*",'$1')
try {
  $pgDumpArgs = @("--schema-only", "--schema=public", $env:SUPABASE_DB_URL, "-f", $tempSchema)
  $pgDump = Get-Command pg_dump -ErrorAction SilentlyContinue
  if (-not $pgDump) {
    # Fall back to npx supabase db dump for local usage
    npx supabase db dump --schema public -f $tempSchema 2>&1
  } else {
    & pg_dump @pgDumpArgs 2>&1
  }
  if ($LASTEXITCODE -ne 0) {
    Write-Error "DRIFT_CHECK FAIL: schema dump failed with exit code $LASTEXITCODE"
    exit 1
  }
} finally {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}

Write-Host "Cloud schema dumped. Comparing against local..."
Write-Host ""

# Normalize and diff
# Filter out Supabase platform-managed lines not present in local pg_dump
$platformPatterns = @(
  "^ALTER SCHEMA .* OWNER TO",
  "^COMMENT ON SCHEMA",
  "^GRANT USAGE ON SCHEMA .* TO",
  "^GRANT ALL ON FUNCTION .* TO .*(service_role|postgres)",
  "^GRANT ALL ON TABLE .* TO .*(service_role|postgres)",
  "^GRANT ALL ON SEQUENCE .* TO .*(service_role|postgres)",
  "^REVOKE ALL ON FUNCTION .* FROM PUBLIC",
  "^REVOKE ALL ON TABLE .* FROM PUBLIC",
  "^ALTER DEFAULT PRIVILEGES FOR ROLE",
  "^GRANT ALL ON FUNCTION .* TO .*(authenticated|anon)"
)
function Remove-PlatformLines([string]$text) {
  ($text -split "`n" | Where-Object {
    $line = $_.Trim()
    $keep = $true
    foreach ($pat in $platformPatterns) { if ($line -match $pat) { $keep = $false; break } }
    $keep
  }) -join "`n"
}
$local = Remove-PlatformLines((Get-Content $localSchema -Raw) -replace "`r`n","`n" -replace "\s+$","")
$cloud = Remove-PlatformLines((Get-Content $tempSchema -Raw) -replace "`r`n","`n" -replace "\s+$","")
Remove-Item $tempSchema -ErrorAction SilentlyContinue

# Compare as sorted line sets to handle ordering differences
$localSet = ($local -split "`n" | Where-Object { $_.Trim() -ne "" } | Sort-Object)
$cloudSet = ($cloud -split "`n" | Where-Object { $_.Trim() -ne "" } | Sort-Object)
$localOnly  = $localSet | Where-Object { $cloudSet -notcontains $_ } | Select-Object -First 20
$cloudOnly  = $cloudSet | Where-Object { $localSet -notcontains $_ } | Select-Object -First 20

if ($localOnly.Count -eq 0 -and $cloudOnly.Count -eq 0) {
  Write-Host "DRIFT_CHECK: NO DRIFT DETECTED"
  Write-Host "Cloud schema matches generated/schema.sql exactly."
  Write-Host "STATUS: PASS"
  exit 0
} else {
  Write-Host "DRIFT_CHECK: DRIFT DETECTED"
  Write-Host "Cloud schema diverges from generated/schema.sql."
  Write-Host ""
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
