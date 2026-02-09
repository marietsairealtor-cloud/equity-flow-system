param([string]$ManifestPath="docs/proofs/manifest.json")
if(!(Test-Path $ManifestPath)){ Write-Error "MISSING: $ManifestPath"; exit 1 }
$mf = Get-Content $ManifestPath -Raw | ConvertFrom-Json
if($mf.algo -ne "sha256"){ Write-Error "BAD algo (expected sha256)"; exit 1 }
$listed = @{}; $mf.files.PSObject.Properties | % { $listed[$_.Name]=$_.Value }
$all = Get-ChildItem docs/proofs -Recurse -File | % { $_.FullName.Replace('\','/') }
$all = $all | ? { $_ -ne "docs/proofs/manifest.json" } | Sort-Object
foreach($f in $all){ if(-not $listed.ContainsKey($f)){ Write-Error "MISSING IN MANIFEST: $f"; exit 1 } }
foreach($k in $listed.Keys){ if(!(Test-Path $k)){ Write-Error "MANIFEST LISTS MISSING FILE: $k"; exit 1 }
  $h=(Get-FileHash -Algorithm SHA256 $k).Hash.ToLower()
  if($h -ne $listed[$k]){ Write-Error "HASH MISMATCH: $k"; exit 1 }
}
Write-Host "PROOF_MANIFEST_OK"