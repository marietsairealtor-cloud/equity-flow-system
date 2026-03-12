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
  "get_complete_schema",
  "^ALTER FUNCTION .* OWNER TO",
  "^\\restrict",
  "^\\unrestrict",
  "^SET transaction_timeout",
  "^ALTER TABLE .* OWNER TO",
  "^ALTER SEQUENCE .* OWNER TO",
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
# Strip Supabase platform-managed function blocks from cloud dump using line-range deletion.
# get_complete_schema: Supabase Table Editor introspection helper. Not created by product
# migrations. Confirmed platform-managed 2026-03-12. Must be excluded from drift comparison.
# This filter operates only on the in-memory cloud dump string — generated/schema.sql is never modified.
function Remove-PlatformFunctionBlocks([string[]]$lines) {
  $skip = $false
  $stripped = $false
  $result = foreach ($line in $lines) {
    if ($line -match "CREATE (OR REPLACE )?FUNCTION `"?public`"?\.`"?get_complete_schema`"?") {
      $skip = $true
      $stripped = $true
    }
    if (-not $skip) { $line }
    if ($skip -and $line -match "^\`$\`$;") {
      $skip = $false
    }
  }
  if ($stripped) {
    Write-Host "  [platform-exclusion] get_complete_schema stripped from cloud dump (Supabase platform-managed, not a product migration)"
  }
  return $result -join "`n"
}

$local = Remove-PlatformLines((Get-Content $localSchema -Raw) -replace "`r`n","`n" -replace "\s+$","")
$cloudRaw = Remove-PlatformFunctionBlocks((Get-Content $tempSchema) -replace "`r`n","")
$cloud = Remove-PlatformLines($cloudRaw -replace "`r`n","`n" -replace "\s+$","")
Remove-Item $tempSchema -ErrorAction SilentlyContinue

# Normalize pg_dump version differences (v16 vs v17 quoting/formatting)
function Normalize-SchemaLine([string]$line) {
  $l = $line.Trim()
  # Skip pure comment lines (pg_dump version differences in comment placement)
  if ($l -match '^--') { return $null }
  # Strip inline trailing comments
  $l = $l -replace '\s*--[^'']*$', ''
  # Strip unnecessary double-quoting of identifiers (pg_dump v16 quotes, v17 does not)
  $l = [regex]::Replace($l, '"([a-zA-Z_][a-zA-Z0-9_]*)"', '$1')
  # Normalize CREATE OR REPLACE to CREATE (v16 vs v17 differences)
  $l = $l -replace 'CREATE OR REPLACE FUNCTION', 'CREATE FUNCTION'
  $l = $l -replace 'CREATE OR REPLACE TRIGGER', 'CREATE TRIGGER'
  $l = $l -replace 'CREATE OR REPLACE VIEW', 'CREATE VIEW'
  # Normalize IF NOT EXISTS (local pg_dump may include, cloud may not)
  $l = $l -replace 'CREATE TABLE IF NOT EXISTS', 'CREATE TABLE'
  $l = $l -replace 'CREATE SCHEMA IF NOT EXISTS', 'CREATE SCHEMA'
  # Collapse multiple spaces to single space
  $l = [regex]::Replace($l, '\s+', ' ')
  $l = $l.Trim()
  if ($l -eq '') { return $null }
  return $l
}

# Compare as sorted line sets to handle ordering differences
$localSet = ($local -split "`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object { Normalize-SchemaLine $_ } | Where-Object { $_ -ne $null } | Sort-Object)
$cloudSet = ($cloud -split "`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object { Normalize-SchemaLine $_ } | Where-Object { $_ -ne $null } | Sort-Object)
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
