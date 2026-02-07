$ErrorActionPreference = "Stop"

function Fail([string]$msg) { Write-Error "CI POLICY FAILED: $msg"; exit 1 }

if (-not (Test-Path "generated/schema.sql")) { Fail "Missing generated/schema.sql (handoff/gen_schema must run first)." }
if (-not (Test-Path "allowlist.json")) { Fail "Missing allowlist.json" }

$allow = Get-Content "allowlist.json" -Raw | ConvertFrom-Json
if ($null -eq $allow.functions) { Fail "allowlist.json must contain { functions: [] }" }
$allowSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($f in $allow.functions) { if ($f) { [void]$allowSet.Add([string]$f) } }

$head = (Get-Content "generated/schema.sql" -Raw) -replace "`r`n","`n"

function Get-PublicFunctionNames([string]$txt) {
  $set = New-Object System.Collections.Generic.HashSet[string]
  $rx = [regex]::new("(?im)^\s*create\s+(or\s+replace\s+)?function\s+public\.([a-zA-Z0-9_]+)\s*\(", [System.Text.RegularExpressions.RegexOptions]::Multiline)
  foreach ($m in $rx.Matches($txt)) { [void]$set.Add($m.Groups[2].Value) }
  return $set
}

function Get-RpcNames([System.Collections.Generic.HashSet[string]]$allFn) {
  $rpc = New-Object System.Collections.Generic.HashSet[string]
  foreach ($n in $allFn) {
    if ($n -match "_v\d+$") { [void]$rpc.Add($n) }
  }
  return $rpc
}

function Get-GrantedExecuteFunctionNames([string]$txt) {
  $set = New-Object System.Collections.Generic.HashSet[string]
  $rx = [regex]::new("(?im)^\s*grant\s+execute\s+on\s+function\s+public\.([a-zA-Z0-9_]+)\s*\(", [System.Text.RegularExpressions.RegexOptions]::Multiline)
  foreach ($m in $rx.Matches($txt)) { [void]$set.Add($m.Groups[1].Value) }
  return $set
}

function GitRefExists([string]$ref) {
  $p = Start-Process -FilePath "git" -ArgumentList @("show-ref","--verify","--quiet",$ref) -NoNewWindow -PassThru -Wait
  return ($p.ExitCode -eq 0)
}

# Determine base ref for diffs (PR: base branch; else origin/main; else previous commit)
$baseRef = $null
if ($env:GITHUB_BASE_REF) {
  $baseRef = "origin/$($env:GITHUB_BASE_REF)"
} elseif (GitRefExists "refs/remotes/origin/main") {
  $baseRef = "origin/main"
} else {
  # best-effort local fallback
  $baseRef = "HEAD~1"
}

# Changed files rule: schema.sql change requires migration change (and contracts snapshot change requires contracts.md change)
$canDiff = $true
try { git rev-parse $baseRef | Out-Null } catch { $canDiff = $false }

if ($canDiff) {
  $changed = (git diff --name-only "$baseRef...HEAD" | Out-String).Trim().Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

  $schemaChanged = $changed -contains "generated/schema.sql"
  $migsChanged = $changed | Where-Object { $_ -like "supabase/migrations/*" -or $_ -like "supabase\migrations\*" }
  if ($schemaChanged -and ($migsChanged.Count -eq 0)) { Fail "generated/schema.sql changed without supabase/migrations change" }

  $contractsSnapChanged = $changed -contains "generated/contracts.snapshot.json"
  $contractsMdChanged = $changed -contains "docs/artifacts/CONTRACTS.md"
  if ($contractsSnapChanged -and (-not $contractsMdChanged)) { Fail "generated/contracts.snapshot.json changed without docs/artifacts/CONTRACTS.md change" }
}

# Parse functions from HEAD schema
$allHead = Get-PublicFunctionNames $head
$rpcHead = Get-RpcNames $allHead

# Enforce: allowlist entries must be versioned (_vN)
foreach ($f in $allowSet) {
  if ($f -notmatch "_v\d+$") { Fail "allowlist function must be versioned (_vN): $f" }
}

# Enforce: any GRANT EXECUTE must be allowlisted
$granted = Get-GrantedExecuteFunctionNames $head
foreach ($f in $granted) {
  if (-not $allowSet.Contains($f)) { Fail "GRANT EXECUTE found for non-allowlisted function: $f" }
}

# If we can diff vs base, enforce RPC budget + _v1 freeze + RPC naming on newly added
if ($canDiff) {
  $baseSchema = ""
  try { $baseSchema = (git show "$baseRef:generated/schema.sql" 2>$null | Out-String) } catch { $baseSchema = "" }
  $baseSchema = $baseSchema -replace "`r`n","`n"

  $allBase = Get-PublicFunctionNames $baseSchema
  $rpcBase = Get-RpcNames $allBase

  $addedRpc = @()
  foreach ($n in $rpcHead) { if (-not $rpcBase.Contains($n)) { $addedRpc += $n } }

  $removedRpc = @()
  foreach ($n in $rpcBase) { if (-not $rpcHead.Contains($n)) { $removedRpc += $n } }

  if (($addedRpc.Count -gt 2) -and ($removedRpc.Count -lt 1)) {
    Fail "RPC budget exceeded: added=$($addedRpc.Count) removed=$($removedRpc.Count) (must remove >=1 if adding >2)"
  }

  # "RPC must have _vN suffix" interpreted as: newly added functions (public) must be versioned unless explicitly allowed helper
  $allowedHelpers = @("current_tenant_id","tenant_write_allowed","can_write_current_tenant","tenant_id_mismatch")
  $addedFns = @()
  foreach ($n in $allHead) { if (-not $allBase.Contains($n)) { $addedFns += $n } }

  foreach ($n in $addedFns) {
    if (($allowedHelpers -contains $n)) { continue }
    if ($n -notmatch "_v\d+$") { Fail "New public function must be versioned (_vN) unless helper: $n" }
  }

  # _v1 freeze: if a _v1 function exists in base and exists in head, its definition must match
  function ExtractFnBlock([string]$txt, [string]$name) {
    $startRx = [regex]::new("(?is)\bcreate\s+(or\s+replace\s+)?function\s+public\.$([regex]::Escape($name))\s*\(", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $m = $startRx.Match($txt)
    if (-not $m.Success) { return $null }
    $start = $m.Index
    $tail = $txt.Substring($start)
    $endRx = [regex]::new("(?is)\$[a-zA-Z0-9_]*\$\s*;")
    $e = $endRx.Match($tail)
    if (-not $e.Success) { return $tail } # fallback
    return $tail.Substring(0, $e.Index + $e.Length)
  }

  foreach ($n in $rpcBase) {
    if ($n -notmatch "_v1$") { continue }
    if (-not $rpcHead.Contains($n)) { continue }

    $b = ExtractFnBlock $baseSchema $n
    $h = ExtractFnBlock $head $n

    if ($null -eq $b -or $null -eq $h) { continue }

    $bn = ($b -replace "\s+"," ").Trim()
    $hn = ($h -replace "\s+"," ").Trim()

    if ($bn -ne $hn) { Fail "Modified existing _v1 RPC definition: $n (add _v2 instead)" }
  }
}

Write-Host "CI POLICY OK"
exit 0