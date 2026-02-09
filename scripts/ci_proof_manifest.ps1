param([string]$ManifestPath="docs/proofs/manifest.json")
if(!(Test-Path $ManifestPath)){ Write-Error "MISSING: $ManifestPath"; exit 1 }
$root = (git rev-parse --show-toplevel).Trim()
if(!$root){ Write-Error "FAILED: git rev-parse --show-toplevel"; exit 1 }

function Rel([string]$p){
  $full = (Resolve-Path $p).Path
  $rel = $full.Substring($root.Length).TrimStart('\','/')
  return $rel.Replace('\','/')
}
function Sha256Hex([string]$p){
  $sha=[System.Security.Cryptography.SHA256]::Create()
  $fs=[System.IO.File]::OpenRead($p)
  try{ $hash=$sha.ComputeHash($fs) } finally { $fs.Dispose(); $sha.Dispose() }
  return ([BitConverter]::ToString($hash) -replace '-','').ToLower()
}

$mf = Get-Content $ManifestPath -Raw | ConvertFrom-Json
if($mf.algo -ne "sha256"){ Write-Error "BAD algo (expected sha256)"; exit 1 }

$listed = @{}
$mf.files.PSObject.Properties | % { $listed[($_.Name -replace '\\','/')] = $_.Value }

if($listed.ContainsKey("docs/proofs/manifest.json")){
  Write-Error "MANIFEST_INVALID: must not include itself (docs/proofs/manifest.json)"
  exit 1
}

$all = Get-ChildItem (Join-Path $root "docs/proofs") -Recurse -File | % { Rel $_.FullName }
$all = $all | ? { $_ -ne "docs/proofs/manifest.json" } | Sort-Object

foreach($f in $all){ if(-not $listed.ContainsKey($f)){ Write-Error "MISSING IN MANIFEST: $f"; exit 1 } }

foreach($k in $listed.Keys){
  $p = Join-Path $root ($k -replace '/','\')
  if(!(Test-Path $p)){ Write-Error "MANIFEST LISTS MISSING FILE: $k"; exit 1 }
  $h=Sha256Hex $p
  if($h -ne $listed[$k]){ Write-Error "HASH MISMATCH: $k"; exit 1 }
}

Write-Host "PROOF_MANIFEST_OK"