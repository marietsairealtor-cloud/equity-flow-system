$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

Write-Host "=== handoff-preconditions: DB-state validation ==="

# Find local supabase DB container
$dbContainer = $null
try {
  $dbContainer = ((docker ps --format "{{.Names}}" | Out-String) -split "`n" | Where-Object { $_ -like "supabase_db_*" } | Select-Object -First 1).Trim()
} catch {}

if (-not $dbContainer) {
  Write-Host "ERROR: No local supabase DB container found. Is the local stack running?"
  exit 1
}
Write-Host "DB container: $dbContainer"

$failures = [System.Collections.Generic.List[string]]::new()

function Invoke-PsqlQuery([string]$query) {
  $result = (docker exec $dbContainer psql -U postgres -d postgres -t -A -c $query 2>&1 | Out-String).Trim()
  return $result
}

# --- TABLE EXISTENCE ---
$requiredTables = @("tenants","tenant_memberships","user_profiles","deals")
foreach ($tbl in $requiredTables) {
  $exists = Invoke-PsqlQuery "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='$tbl';"
  if ($exists -ne "1") {
    $failures.Add("MISSING TABLE: public.$tbl (expected: exists, found: absent)")
  } else {
    Write-Host "PASS: public.$tbl exists"
  }
}

# --- DEALS COLUMN REQUIREMENTS ---
$colChecks = @(
  @{ col="tenant_id";    type="uuid";    notnull="YES" },
  @{ col="row_version";  type="bigint";  notnull=$null },
  @{ col="calc_version"; type="integer"; notnull=$null }
)
foreach ($chk in $colChecks) {
  $row = Invoke-PsqlQuery "SELECT data_type, is_nullable FROM information_schema.columns WHERE table_schema='public' AND table_name='deals' AND column_name='$($chk.col)';"
  if (-not $row) {
    $failures.Add("MISSING COLUMN: public.deals.$($chk.col) (expected: $($chk.type), found: absent)")
    continue
  }
  $parts = $row -split "\|"
  $foundType = $parts[0].Trim()
  $foundNullable = $parts[1].Trim()

  if ($foundType -ne $chk.type) {
    $failures.Add("WRONG TYPE: public.deals.$($chk.col) (expected: $($chk.type), found: $foundType)")
  } else {
    Write-Host "PASS: public.deals.$($chk.col) type=$foundType"
  }

  if ($chk.notnull -eq "YES" -and $foundNullable -ne "NO") {
    $failures.Add("NOT NULL VIOLATION: public.deals.$($chk.col) (expected: NOT NULL, found: nullable)")
  } elseif ($chk.notnull -eq "YES") {
    Write-Host "PASS: public.deals.$($chk.col) NOT NULL"
  }
}

# --- RLS ENABLED ---
$rlsTables = @("tenants","deals")
foreach ($tbl in $rlsTables) {
  $rls = Invoke-PsqlQuery "SELECT relrowsecurity FROM pg_class WHERE relname='$tbl' AND relnamespace=(SELECT oid FROM pg_namespace WHERE nspname='public');"
  if ($rls -ne "t") {
    $failures.Add("RLS NOT ENABLED: public.$tbl (expected: RLS ON, found: $rls)")
  } else {
    Write-Host "PASS: RLS enabled on public.$tbl"
  }
}

# --- RESULT ---
if ($failures.Count -gt 0) {
  Write-Host ""
  Write-Host "PRECONDITIONS FAILED:"
  foreach ($f in $failures) { Write-Host "  - $f" }
  Write-Host "STATUS: FAIL"
  exit 1
}

Write-Host ""
Write-Host "STATUS: PASS"
exit 0
