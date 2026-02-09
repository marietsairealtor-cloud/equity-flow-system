git fetch origin main | Out-Null
$base="origin/main"
$chg = git diff --name-status "$base...HEAD" -- docs/proofs | % { $_.Trim() } | ? { $_ }
foreach($l in $chg){
  $p=$l -split "\s+"
  $st=$p[0]; $file=$p[1]
  if($file -eq "docs/proofs/manifest.json"){ continue }
  if($st -match "^[MD]"){ Write-Error "PROOFS_APPEND_ONLY_FAIL: $st $file (use 2.11 redaction protocol)"; exit 1 }
}
Write-Host "PROOFS_APPEND_ONLY_OK"