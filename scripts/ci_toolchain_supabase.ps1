$ErrorActionPreference = "Stop"

$cfgPath = "docs/truth/toolchain.json"
if (!(Test-Path $cfgPath)) { Write-Error "MISSING: $cfgPath"; exit 1 }
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json

function Check-Version {
  param([string]$label, [string]$actual, [string]$expect, [string]$match)
  if ($match -eq "prefix") {
    if ($actual.StartsWith($expect)) {
      Write-Host ("PASS: " + $label + " = " + $actual)
      return $true
    }
    Write-Host ("FAIL: " + $label + " expected prefix '" + $expect + "' but got '" + $actual + "'")
    return $false
  }
  Write-Host ("FAIL: " + $label + " unknown match type: " + $match)
  return $false
}

$pass = $true

$rawSupa = ""
try {
  $rawSupa = (npx supabase --version 2>&1 | Out-String).Trim()
  $supaVer = ($rawSupa -split "`n")[0].Trim()
  $ok = Check-Version -label "supabase_cli" -actual $supaVer -expect $cfg.supabase_cli.expect -match $cfg.supabase_cli.match
  if (-not $ok) { $pass = $false }
} catch {
  Write-Host ("FAIL: supabase_cli -- could not run: " + $_)
  $pass = $false
}

$psqlFound = $false
$rawPsql = ""
try {
  $rawPsql = (psql --version 2>&1 | Out-String).Trim()
  if ($rawPsql -match "PostgreSQL\s+([\d\.]+)") {
    $psqlVer = $Matches[1]
    $psqlFound = $true
    $ok = Check-Version -label "psql" -actual $psqlVer -expect $cfg.psql.expect -match $cfg.psql.match
    if (-not $ok) { $pass = $false }
  } else {
    throw "version string not parsed"
  }
} catch {
  if ($cfg.psql.ci_only -eq $true) {
    Write-Host "WARN: psql not available locally -- CI-only enforcement. Skipping."
  } else {
    Write-Host ("FAIL: psql -- could not run: " + $_)
    $pass = $false
  }
}

if ($pass) {
  Write-Host "TOOLCHAIN_CONTRACT_SUPABASE_OK"
  exit 0
} else {
  Write-Host "TOOLCHAIN_CONTRACT_SUPABASE_FAIL"
  exit 1
}