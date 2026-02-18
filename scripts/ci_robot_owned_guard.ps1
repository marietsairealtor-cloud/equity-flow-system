$ErrorActionPreference = "Stop"

git fetch origin main | Out-Null
$base = "origin/main"

function Norm([string]$p){
  return ($p.Trim() -replace "\\","/").TrimStart("./")
}

function GlobToRegex([string]$glob){
  $g = Norm $glob
  $g = [Regex]::Escape($g)
  # ** => .*
  $g = $g -replace "\\\*\\\*",".*"
  # * => [^/]* (single segment)
  $g = $g -replace "\\\*","[^/]*"
  return "^" + $g + "$"
}

function IsRobotOwned([string]$p, $patterns){
  $pp = Norm $p
  foreach($pat in $patterns){
    $rx = GlobToRegex $pat
    if($pp -match $rx){ return $true }
    # also allow prefix-match for "root/**" style paths
    $root = (Norm $pat) -replace "/\*\*.*$",""
    if($root -and $pp.StartsWith($root + "/")){ return $true }
    if($root -and $pp -eq $root){ return $true }
  }
  return $false
}

function ExceptionMatch([string]$p){
  $pp = Norm $p
  if($pp -eq "docs/proofs/manifest.json"){ return "ALLOW:manifest.json" }
  if($pp -match "^docs/proofs/2\.16\.10_robot_owned_guard_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.16.10 proof log" }
  if($pp -match "^docs/proofs/2\.16\.11_governance_change_template_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.16.11 proof log" }
  if($pp -match "^docs/proofs/2\.17\.1_normalize_sweep_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.17.1 proof log" }
  return $null
}

$cfgPath = "docs/truth/robot_owned_paths.json"
if(!(Test-Path $cfgPath)){ Write-Error "MISSING: $cfgPath"; exit 1 }

$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
$patterns = @($cfg.paths | ForEach-Object { "$_" }) | Where-Object { $_ }

$raw = @(git diff --name-status "$base...HEAD" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ })
$changed = @()
foreach($ln in $raw){
  $parts = $ln -split "`t"
  if($parts.Count -lt 2){ continue }
  $st = $parts[0]
  if($st -match "^R"){ $changed += (Norm $parts[2]); continue }
  $changed += (Norm $parts[1])
}
$changed = $changed | Sort-Object -Unique

$robot = @()
foreach($f in $changed){
  if(IsRobotOwned $f $patterns){ $robot += $f }
}

Write-Host "=== robot-owned-guard ==="
Write-Host ("BASE=" + $base)
Write-Host ("CHANGED_FILES=" + $changed.Count)
foreach($f in $changed){ Write-Host (" - " + $f) }

Write-Host "ROBOT_OWNED_CHANGED:"
if($robot.Count -eq 0){
  Write-Host " (none)"
  Write-Host "STATUS: PASS"
  exit 0
}
foreach($f in $robot){
  $ex = ExceptionMatch $f
  if($ex){
    Write-Host (" - " + $f + " :: " + $ex)
  } else {
    Write-Host (" - " + $f + " :: NO_EXCEPTION")
  }
}

$off = @()
foreach($f in $robot){
  if(-not (ExceptionMatch $f)){ $off += $f }
}

if($off.Count -gt 0){
  Write-Host "OFFENDING_PATHS:"
  foreach($f in $off){ Write-Host (" - " + $f + " :: robot-owned (no allowed exception)") }
  Write-Host "STATUS: FAIL"
  exit 1
}

Write-Host "STATUS: PASS"
exit 0
