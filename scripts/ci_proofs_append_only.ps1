git fetch origin main | Out-Null
$base="origin/main"
$chg = git diff --name-status "$base...HEAD" -- docs/proofs | % { $_.Trim() } | ? { $_ }
$redaction_present = (git diff --name-only "$base...HEAD" -- docs/proofs | % { $_.Trim() } | ? { $_ -match '^docs/proofs/PROOF_REDACTION__\.md$' }).Count -gt 0
foreach($l in $chg){
  $p=$l -split "\s+"
  $st=$p[0]; $file=$p[1]
  if($file -eq "docs/proofs/manifest.json"){ continue }
  if($st -match "^[MD]"){
    if(-not $redaction_present){ Write-Error "PROOFS_APPEND_ONLY_FAIL: $st $file (missing docs/proofs/PROOF_REDACTION__.md)"; exit 1 }
  }
}
Write-Host "PROOFS_APPEND_ONLY_OK"