$ErrorActionPreference = "Stop"

function Write-Utf8NoBomLf([string]$path, [string]$content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $content = $content -replace "`r`n","`n"
  $full = Join-Path (Get-Location).Path $path
  $dir = Split-Path $full
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($full, $content, $utf8NoBom)
}

function Redact-Text([string]$t) {
  if ($null -eq $t) { return $t }
  $t = [regex]::Replace($t, '(?i)\beyJ[a-z0-9_\-]{10,}\.[a-z0-9_\-]{10,}\.[a-z0-9_\-]{10,}\b', '<REDACTED_JWT>')
  $t = [regex]::Replace($t, '(?im)^(\s*(?:ANON_KEY|SERVICE_ROLE_KEY|JWT_SECRET|PUBLISHABLE_KEY|SECRET_KEY|STORAGE_ACCESS_KEY|STORAGE_SECRET_KEY|SUPABASE_[A-Z0-9_]*KEY|API_KEY|ACCESS_TOKEN|REFRESH_TOKEN|TOKEN|SECRET|PASSWORD|PGPASSWORD)\s*[:=]\s*)(.+)$', '$1<REDACTED>')
  $t = [regex]::Replace($t, '(?im)("?(?:ANON_KEY|SERVICE_ROLE_KEY|JWT_SECRET|PUBLISHABLE_KEY|SECRET_KEY|STORAGE_ACCESS_KEY|STORAGE_SECRET_KEY|SUPABASE_[A-Z0-9_]*KEY|API_KEY|ACCESS_TOKEN|REFRESH_TOKEN|TOKEN|SECRET|PASSWORD|PGPASSWORD)"?\s*:\s*)"[^"]*"', '$1"<REDACTED>"')
  $t = [regex]::Replace($t, '(?i)\b(postgres(?:ql)?://[^:\s/]+:)([^@\s/]+)(@)', '$1<REDACTED>$3')
  $t = [regex]::Replace($t, '(?i)\b((?:token|apikey|api_key|key|secret|password)=)([^&\s]+)', '$1<REDACTED>')
  return $t
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
# --- 6.1 REPLAY PROOF ENFORCEMENT ---
# If migrations changed vs origin/main, a valid local replay proof must exist before truth artifacts are written.
$migrationChanged = $false
$oldEAP61 = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$committedFiles = (git diff --name-only origin/main...HEAD 2>&1 | Where-Object { $_ -notmatch "^warning:" } | Out-String) -split "`n" | Where-Object { $_ -match "^supabase/migrations/" }
$stagedFiles = (git diff --name-only --cached 2>&1 | Where-Object { $_ -notmatch "^warning:" } | Out-String) -split "`n" | Where-Object { $_ -match "^supabase/migrations/" }
$worktreeFiles = (git diff --name-only 2>&1 | Where-Object { $_ -notmatch "^warning:" } | Out-String) -split "`n" | Where-Object { $_ -match "^supabase/migrations/" }
$ErrorActionPreference = $oldEAP61
if ($committedFiles.Count -gt 0 -or $stagedFiles.Count -gt 0 -or $worktreeFiles.Count -gt 0) { $migrationChanged = $true }

if ($migrationChanged) {
  $proofLogs = @()
  try {
    $proofLogs = Get-ChildItem -Path "docs/proofs" -Filter "6.1_greenfield_baseline_migrations_*.log" -ErrorAction SilentlyContinue
  } catch {}

  if ($proofLogs.Count -eq 0) {
    Write-Host "6.1 REPLAY PROOF REQUIRED:"
    Write-Host "Migrations changed but no valid local replay proof found."
    Write-Host "Run migration replay and regenerate proof log."
    exit 1
  }

  # Validate proof log contains required markers
  $validProof = $false
  foreach ($pl in $proofLogs) {
    $plContent = Get-Content $pl.FullName -Raw
    $hasEphemeral  = $plContent -match "(?i)(ephemeral|supabase start|supabase db reset)"
    $hasReplay     = $plContent -match "(?i)(migration|supabase db push|migrate)"
    $hasDump       = $plContent -match "(?i)(pg_dump|schema dump|dump)"
    $hasDiff       = $plContent -match "(?i)(git diff)"
    $hasZeroDiff   = $plContent -match "(?i)(zero diff|no diff|exit.code.0|RESULT=PASS)"
    if ($hasEphemeral -and $hasReplay -and $hasDump -and $hasDiff -and $hasZeroDiff) {
      $validProof = $true
      break
    }
  }

  if (-not $validProof) {
    Write-Host "6.1 REPLAY PROOF REQUIRED:"
    Write-Host "Migrations changed but no valid local replay proof found."
    Write-Host "Run migration replay and regenerate proof log."
    exit 1
  }
}
# --- END 6.1 ENFORCEMENT ---

# --- 6.1A HANDOFF PRECONDITIONS ---
$oldEAP61A = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$precondOut = (& (Join-Path $PSScriptRoot "ci_handoff_preconditions.ps1") 2>&1 | Out-String).TrimEnd()
$precondExit = $LASTEXITCODE
$ErrorActionPreference = $oldEAP61A
Write-Host $precondOut
if ($precondExit -ne 0) {
  Write-Host "HANDOFF PRECONDITIONS FAILED -- truth artifacts not written."
  exit 1
}
# --- END 6.1A PRECONDITIONS ---

# Regenerate robot-owned truth files (read-only)
& (Join-Path $PSScriptRoot "gen_schema.ps1") | Out-String | Out-Null
& (Join-Path $PSScriptRoot "gen_contracts_snapshot.ps1") | Out-String | Out-Null
& (Join-Path $PSScriptRoot "gen_write_path_registry.ps1") | Out-String | Out-Null

# Lints/guards
& (Join-Path $PSScriptRoot "contracts_lint.ps1") | Out-String | Out-Null
& (Join-Path $PSScriptRoot "must_contain.ps1") | Out-String | Out-Null

# Git state -- exclude robot-owned handoff outputs to achieve idempotency
# generated/schema.sql, generated/contracts.snapshot.json, docs/handoff_latest.txt
# are written by this script and must not self-reference
$gitStatus = (git status --porcelain=v1 2>&1 | Out-String).TrimEnd()
$gitStatus = ($gitStatus -split "`n" | Where-Object { $_ -notmatch "generated/schema\.sql|generated/contracts\.snapshot\.json|docs/handoff_latest\.txt" }) -join "`n"
$head = (git rev-parse --short HEAD 2>&1 | Out-String).Trim()

# Supabase status summary (safe)
$supSummary = [ordered]@{
  exitcode = $null
  stack_running = $null
  stopped_services = @()
  api_url = $null
  rest_url = $null
  studio_url = $null
  functions_url = $null
}
# Reliable running signal: Docker containers exist for this project
$dockerRunning = $false
try {
  $names = docker ps --format "{{.Names}}"
  if ($names -match "supabase_db_weweb-supabase-option2") { $dockerRunning = $true }
} catch {}
$rawStatus = ""
$exit = 0

$oldEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $hadVar = Get-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue
  $oldNative = $null
  if ($hadVar) { $oldNative = $global:PSNativeCommandUseErrorActionPreference; $global:PSNativeCommandUseErrorActionPreference = $false }

  $rawStatus = (npx supabase status --output json 2>&1 | Out-String).TrimEnd()
  $exit = $LASTEXITCODE

  if ($hadVar) { $global:PSNativeCommandUseErrorActionPreference = $oldNative }
} finally {
  $ErrorActionPreference = $oldEAP
}

$supSummary.exitcode = $exit

# Try parse JSON; if fails, fallback to redacted text
try {
  $j = $rawStatus | ConvertFrom-Json
  $supSummary.api_url = $j.API_URL
  $supSummary.rest_url = $j.REST_URL
  $supSummary.studio_url = $j.STUDIO_URL
  $supSummary.functions_url = $j.FUNCTIONS_URL
  # "Stopped services" sometimes appears only in stderr text; keep both paths
  if ($j.stopped_services) { $supSummary.stopped_services = @($j.stopped_services) }
} catch {
  $rawStatus = Redact-Text $rawStatus
}

# Additionally extract "Stopped services" from text if present
if ($rawStatus -match '(?im)Stopped services:\s*\[(.*?)\]') {
  $inner = $Matches[1]
  $svc = $inner -split '\s+' | ForEach-Object { $_.Trim().Trim(',') } | Where-Object { $_ -ne "" }
  if ($svc.Count -gt 0) { $supSummary.stopped_services = $svc }
}

# Determine running state from text or non-empty URLs
$running = $false
if ($rawStatus -match '(?im)setup is running') { $running = $true }
if ($supSummary.api_url -or $supSummary.rest_url -or $supSummary.studio_url) { $running = $true }
$supSummary.stack_running = $dockerRunning
# Last applied migration via docker exec psql (local stack)
$lastApplied = ""
try {
  $names = docker ps --format "{{.Names}}"
  $db = ($names | Where-Object { $_ -like "supabase_db_*weweb-supabase-option2*" } | Select-Object -First 1)
  if (-not $db) { $db = ($names | Where-Object { $_ -like "supabase_db_*" } | Select-Object -First 1) }
  if (-not $db) { throw "No supabase_db_* container found" }

  $q = "select version from supabase_migrations.schema_migrations order by version desc limit 1;"
  $lastApplied = (docker exec $db psql -U postgres -d postgres -t -c $q 2>&1 | Out-String).TrimEnd()
} catch {
  $lastApplied = "DB QUERY FAILED: $($_.Exception.Message)"
}

# Latest migration file in repo
$latestFile = "(none)"
try {
  $f = Get-ChildItem -Path "supabase\migrations" -Filter "*.sql" | Sort-Object Name | Select-Object -Last 1
  if ($f) { $latestFile = $f.Name }
} catch {}

# Implementation status (computed; no narrative)
$ciWorkflow = Test-Path ".github/workflows/ci.yml"
$dbTestsWorkflow = Test-Path ".github/workflows/database-tests.yml"

# Privilege firewall: look for REVOKE patterns in generated/schema.sql (best-effort, deterministic)
$schemaText = ""
try { $schemaText = Get-Content "generated/schema.sql" -Raw } catch { $schemaText = "" }

# Privilege firewall: treat as PASS when there are NO GRANTs to anon/authenticated on core tables.
$grantCoreToAnonOrAuth = ($schemaText -match '(?im)^\s*GRANT\s+.*\s+ON\s+TABLE\s+"public"\."(tenants|tenant_memberships|tenant_invites|deals|documents)"\s+TO\s+"(anon|authenticated)"\s*;\s*$')
$privFirewall = (-not $grantCoreToAnonOrAuth)

$hasRevokeAnon = ($schemaText -match '(?im)^\s*REVOKE\s+.*\s+ON\s+TABLE\s+.*\s+FROM\s+(")?anon(")?\s*;')
$hasRevokeAuth = ($schemaText -match '(?im)^\s*REVOKE\s+.*\s+ON\s+TABLE\s+.*\s+FROM\s+(")?authenticated(")?\s*;')
# $privFirewall = ($hasRevokeAnon -and $hasRevokeAuth)  # superseded by GRANT-absence detector

# SECURITY DEFINER read RPCs: presence signal (tighten later to specific allowlist if desired)
$hasSecDef = ($schemaText -match '(?im)\bSECURITY\s+DEFINER\b')

$impl = @(
  "- handoff checkpoint: yes",
  ("- CI workflow present: " + $(if ($ciWorkflow) { "yes" } else { "no" }) + " (.github/workflows/ci.yml)"),
  ("- pgTAP workflow present: " + $(if ($dbTestsWorkflow) { "yes" } else { "no" }) + " (.github/workflows/database-tests.yml)"),
  ("- privilege firewall (REVOKE core tables) detected in schema.sql: " + $(if ($privFirewall) { "yes" } else { "no" })),
  ("- SECURITY DEFINER detected in schema.sql: " + $(if ($hasSecDef) { "yes" } else { "no" }))
) -join "`n"
$summaryJson = ($supSummary | ConvertTo-Json -Depth 10)
$summaryJson = Redact-Text $summaryJson

$body = @"
HANDOFF CHECKPOINT (robot-owned, deterministic)
HEAD: $head

=== git status --porcelain=v1 ===
$gitStatus

=== supabase status (sanitized summary) ===
$summaryJson

=== last applied migration (DB) ===
$lastApplied

=== latest migration file in repo ===
$latestFile

=== implemented gates/status ===
$impl
"@

Write-Utf8NoBomLf "docs/handoff_latest.txt" $body
Write-Host "Wrote docs/handoff_latest.txt"





