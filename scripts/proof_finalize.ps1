# scripts/proof_finalize.ps1
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$File,

  [Parameter(Mandatory=$false)]
  [string]$ProofHead
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){ Write-Error $m; exit 1 }

$repo = (git rev-parse --show-toplevel).Trim()
if(-not $repo){ Die "Not a git repo." }

$rel = $File.Trim() -replace "\\","/"
if($rel -match "^\.\." -or $rel -match "^[A-Za-z]:"){ Die "File must be repo-relative." }

$abs = Join-Path $repo ($rel -replace "/","\")
if(-not (Test-Path $abs)){ Die "Missing file: $rel" }

if(-not $ProofHead){ $ProofHead = (git rev-parse HEAD).Trim() }
if(-not ($ProofHead -match "^[0-9a-f]{7,40}$")){ Die "Bad ProofHead." }

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Normalize-Utf8NoBomLf([string]$path){
  $t = Get-Content $path -Raw
  $t = $t -replace "`r`n","`n" -replace "`r","`n"
  [IO.File]::WriteAllText((Resolve-Path $path), $t, $utf8NoBom)
}

function GetScriptsHashAuthority([string]$repoRoot){
  $u = New-Object System.Text.UTF8Encoding($false)
  $ap = Join-Path $repoRoot 'docs\artifacts\AUTOMATION.md'
  if(-not (Test-Path $ap)){ Die "MISSING AUTHORITY DOC: $ap" }

  $t = [IO.File]::ReadAllText($ap,$u) -replace "`r`n","`n" -replace "`r","`n"
  $L = $t -split "`n"
  $hdr = ("### proof-commit-binding " + [char]0x2014 + " scripts hash authority")
  $end = "END scripts hash authority"

  $i = [Array]::IndexOf($L,$hdr)
  if($i -lt 0){ Die "MISSING AUTHORITY HEADER" }

  $files=@()
  for($x=$i+1;$x -lt $L.Count;$x++){
    $s=$L[$x]
    if($s -eq $end){ break }

    # matches: - `scripts/whatever.ps1`
    if($s -match '^- `(.+)`$'){
      $files += $Matches[1]
    }
  }
  if($files.Count -lt 1){ Die "EMPTY SCRIPT FILE LIST" }
  return ,$files


}

function ComputeScriptsHashAndLines([string]$repoRoot){
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $files = GetScriptsHashAuthority $repoRoot

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("PROOF_SCRIPTS_FILES=" + ($files -join ","))

  foreach($rel2 in $files){
    $p2 = Join-Path $repoRoot $rel2
    if(-not (Test-Path $p2)){ Die "MISSING SCRIPT FILE: $rel2" }
    $txt = [IO.File]::ReadAllText($p2,$utf8) -replace "`r`n","`n" -replace "`r","`n"
    $sha=[Security.Cryptography.SHA256]::Create()
    try{
      $h=([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($txt))) -replace '-','').ToLower()
    } finally { $sha.Dispose() }
    $lines.Add("PROOF_SCRIPTS_FILE_SHA256=${rel2}:${h}")
  }

  $buf=''
  foreach($rel2 in $files){
    $p2 = Join-Path $repoRoot $rel2
    $txt = [IO.File]::ReadAllText($p2,$utf8) -replace "`r`n","`n" -replace "`r","`n"
    $buf += "FILE:$rel2`n$txt`n"
  }

  $sha=[System.Security.Cryptography.SHA256]::Create()
  try{
    $scriptsHash = ([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($buf))) -replace '-','').ToLower()
  } finally { $sha.Dispose() }

  $lines.Add("PROOF_SCRIPTS_HASH=$scriptsHash")
  return @{ Hash=$scriptsHash; Lines=$lines }
}

function Sha256HexOfFileBytes([string]$path){
  (Get-FileHash -Algorithm SHA256 $path).Hash.ToLower()
}

# --- normalize proof file ---
Normalize-Utf8NoBomLf $abs
$body = Get-Content $abs -Raw
$body = $body -replace "`r`n","`n" -replace "`r","`n"

# --- compute authority lines (exactly like commit-binding) ---
$auth = ComputeScriptsHashAndLines $repo
$authLines = $auth.Lines

# remove old headers
$body2 = $body `
  -replace "(?m)^PROOF_HEAD=.*\n?","" `
  -replace "(?m)^PROOF_SCRIPTS_FILES=.*\n?","" `
  -replace "(?m)^PROOF_SCRIPTS_HASH=.*\n?","" `
  -replace "(?m)^PROOF_SCRIPTS_FILE_SHA256=.*\n?",""

# write headers + body
$hdr = "PROOF_HEAD=${ProofHead}`n" + (($authLines -join "`n") + "`n")
[IO.File]::WriteAllText((Resolve-Path $abs), ($hdr + $body2), $utf8NoBom)

# --- update manifest ---
$manifestAbs = Join-Path $repo "docs\proofs\manifest.json"
if(-not (Test-Path $manifestAbs)){ Die "Missing docs/proofs/manifest.json" }

$mf = (Get-Content $manifestAbs -Raw) | ConvertFrom-Json
if($mf.algo -ne "sha256"){ Die "BAD algo (expected sha256)" }
if(-not $mf.files){ Die "manifest missing .files" }

$hash = Sha256HexOfFileBytes $abs
$mf.files | Add-Member -NotePropertyName $rel -NotePropertyValue $hash -Force

$mfJson = ($mf | ConvertTo-Json -Depth 50) -replace "`r`n","`n"
[IO.File]::WriteAllText((Resolve-Path $manifestAbs), $mfJson, $utf8NoBom)

# --- validators (must pass) ---
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts\ci_proof_manifest.ps1")
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts\ci_proof_commit_binding.ps1")

Write-Host "PROOF_FINALIZE_OK: $rel"

