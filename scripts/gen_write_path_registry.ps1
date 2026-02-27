# scripts/gen_write_path_registry.ps1
# 6.6: Machine-derives docs/truth/write_path_registry.json from LIVE catalog.
# Queries pg_proc (RPCs), pg_trigger (triggers), background_context_review.json (background).
# Triple Registration Rule §3.0.4: (a) robot-owned guard, (b) truth-bootstrap, (c) handoff regen.

param(
  [string]$OutFile  = "docs/truth/write_path_registry.json",
  [string]$DbHost   = "127.0.0.1",
  [string]$DbPort   = "54322",
  [string]$DbUser   = "postgres",
  [string]$DbName   = "postgres"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$env:PGPASSWORD = "postgres"
$psql = "C:\Program Files\PostgreSQL\16\bin\psql.exe"

function Invoke-Query {
  param([string]$Sql)
  $result = & $psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -t -A -F "`t" -c $Sql 2>&1
  if ($LASTEXITCODE -ne 0) { throw "psql failed: $result" }
  return $result
}

function Invoke-QuerySingleCol {
  param([string]$Sql)
  $result = & $psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -t -A -c $Sql 2>&1
  if ($LASTEXITCODE -ne 0) { throw "psql failed: $result" }
  return $result
}

# --- Get VOLATILE SECURITY DEFINER function names from catalog ---
$nameSql = @"
SELECT p.proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.provolatile = 'v'
  AND p.prosecdef = true
ORDER BY p.proname;
"@

$fnNames = Invoke-QuerySingleCol -Sql $nameSql | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

$rpcPaths = @()

foreach ($fnName in $fnNames) {
  $fnName = $fnName.Trim()
  if ([string]::IsNullOrWhiteSpace($fnName)) { continue }

  # Get body separately per function — safe, no delimiter collision
  $bodySql = "SELECT prosrc FROM pg_proc WHERE proname = '$fnName' AND pronamespace = 'public'::regnamespace LIMIT 1;"
  $body = (Invoke-QuerySingleCol -Sql $bodySql) -join "`n"

  # Derive tables written: INSERT INTO or UPDATE public.<table>
  $tableMatches = [regex]::Matches($body, '(?i)(?:INSERT\s+INTO|UPDATE)\s+public\.(\w+)')
  $tables = @($tableMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
  if ($tables.Count -eq 0) { continue }  # No writes — skip

  # row_version_enforced: UPDATE with AND row_version = <param>
  $hasRowVersionWhere = $body -match '(?i)AND\s+row_version\s*=\s*p_\w'

  $rpcPaths += [pscustomobject]@{
    path_type              = "rpc"
    name                   = $fnName
    tables                 = $tables
    row_version_enforced   = $hasRowVersionWhere
    optimistic_concurrency = $hasRowVersionWhere
  }
}

# --- Trigger write paths: from pg_trigger + pg_class ---
$triggerSql = @"
SELECT t.tgname, c.relname
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;
"@

$triggerRows = Invoke-Query -Sql $triggerSql | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$triggerPaths = @()

foreach ($row in $triggerRows) {
  if ([string]::IsNullOrWhiteSpace($row)) { continue }
  $parts = $row -split "`t", 2
  $triggerPaths += [pscustomobject]@{
    path_type              = "trigger"
    name                   = $parts[0].Trim()
    tables                 = @($parts[1].Trim())
    row_version_enforced   = $false
    optimistic_concurrency = $false
  }
}

# --- Background write paths: from background_context_review.json ---
$bgPaths = @()
$bgFile  = "docs/truth/background_context_review.json"
if (Test-Path $bgFile) {
  $bg = Get-Content $bgFile -Raw | ConvertFrom-Json
  if ($bg.PSObject.Properties["entries"]) {
    foreach ($entry in $bg.entries) {
      $bgPaths += [pscustomobject]@{
        path_type              = "background"
        name                   = $entry.name
        tables                 = @()
        row_version_enforced   = $false
        optimistic_concurrency = $false
      }
    }
  }
}

# --- Assemble ---
$allPaths  = @()
$allPaths += $rpcPaths
$allPaths += $triggerPaths
$allPaths += $bgPaths

$registry = [ordered]@{
  version     = 1
  generated   = ([DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"))
  write_paths = $allPaths
}

$json = $registry | ConvertTo-Json -Depth 10
$json = $json -replace "`r`n", "`n"
[System.IO.File]::WriteAllText(
  (Join-Path (Resolve-Path ".").Path $OutFile),
  $json,
  (New-Object System.Text.UTF8Encoding $false)
)

Write-Host "PASS: write_path_registry.json written to $OutFile"
Write-Host "  RPC write paths:        $($rpcPaths.Count)"
Write-Host "  Trigger write paths:    $($triggerPaths.Count)"
Write-Host "  Background write paths: $($bgPaths.Count)"

