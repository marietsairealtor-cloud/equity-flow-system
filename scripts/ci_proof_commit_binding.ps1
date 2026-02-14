$ErrorActionPreference='Stop'
git fetch origin main | Out-Null
$base='origin/main'
$head=(git rev-parse HEAD).Trim()
$root=(git rev-parse --show-toplevel).Trim()
function FileSha([string]$rel){ (Get-FileHash -Algorithm SHA256 (Join-Path $root $rel)).Hash.ToLower() }
function GetScriptsHashAuthority(){
  $u=New-Object System.Text.UTF8Encoding($false); $r=(git rev-parse --show-toplevel).Trim()
  $ap=Join-Path $r 'docs\artifacts\AUTOMATION.md'; if(-not (Test-Path $ap)){ throw ('MISSING AUTHORITY DOC: '+$ap) }
  $t=[IO.File]::ReadAllText($ap,$u) -replace "`r`n","`n" -replace "`r","`n"; $L=$t -split "`n"
  $hdr=("### proof-commit-binding " + [char]0x2014 + " scripts hash authority"); $end="END scripts hash authority"
  $i=[Array]::IndexOf($L,$hdr); if($i -lt 0){ throw "MISSING AUTHORITY HEADER" }
  $files=@(); for($x=$i+1;$x -lt $L.Count;$x++){ $s=$L[$x]; if($s -eq $end){ break }
    if($s.Length -ge 5 -and $s.Substring(0,3) -eq '- `' -and $s.EndsWith('`')){ $files += $s.Substring(3,$s.Length-4) }
  }
  if($files.Count -lt 1){ throw "EMPTY SCRIPT FILE LIST" }; return ,$files
}

function ScriptsHash(){
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $files = GetScriptsHashAuthority
  $buf = ''
  Write-Host ("PROOF_SCRIPTS_FILES=" + ($files -join ","))
  foreach($rel in $files){
    $p2=Join-Path $root $rel; $txt=[IO.File]::ReadAllText($p2,$utf8) -replace "`r`n","`n" -replace "`r","`n"
    $sha=[Security.Cryptography.SHA256]::Create(); try{ $h=([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($txt))) -replace '-','').ToLower() } finally{ $sha.Dispose() }
    Write-Host ("PROOF_SCRIPTS_FILE_SHA256="+$rel+":"+$h)
  }
  foreach($rel in $files){
    $p2 = Join-Path $root $rel
    $txt = [IO.File]::ReadAllText($p2,$utf8) -replace "`r`n","`n" -replace "`r","`n"
    $buf += "FILE:$rel`n$txt`n"
  }
  $sha=[System.Security.Cryptography.SHA256]::Create()
  try{ ([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($buf))) -replace '-','').ToLower() } finally{ $sha.Dispose() }
}
$scriptsHash=ScriptsHash
Write-Host ("PROOF_SCRIPTS_HASH=" + $scriptsHash)
$chg = git diff --name-status "$base...HEAD" -- docs/proofs | % { $_.Trim() } | ? { $_ }
$need=@(); foreach($l in $chg){ $p=$l -split "\s+"; $st=$p[0]; $f=$p[1]; if($f -eq 'docs/proofs/manifest.json'){continue}; if($st -match '^[AM]'){ $need += $f } }
if($need.Count -eq 0){ Write-Host 'PROOF_COMMIT_BINDING_SKIP: no proof files changed in PR'; exit 0 }
foreach($f in $need){
  $t=Get-Content $f -Raw
  if($t -notmatch '(?m)^PROOF_HEAD=([0-9a-f]{40})\r?$'){ Write-Error "MISSING PROOF_HEAD: $f"; exit 1 }
  $proofHead=$Matches[1]
  if($t -notmatch '(?m)^PROOF_SCRIPTS_HASH=([0-9a-f]{64})\r?$'){ Write-Error "MISSING PROOF_SCRIPTS_HASH: $f"; exit 1 }
  if($Matches[1] -ne $scriptsHash){ Write-Error "SCRIPTS_HASH MISMATCH: $f"; exit 1 }
  git merge-base --is-ancestor $proofHead $head; if($LASTEXITCODE -ne 0){ Write-Error "PROOF_HEAD_NOT_ANCESTOR: $f"; exit 1 }
  $post = git diff --name-only "$proofHead..$head" | % { $_.Trim() } | ? { $_ }
  foreach($x in $post){ if($x -notmatch '^docs/proofs/'){ Write-Error "POST_PROOF_NON_PROOF_CHANGE: $x"; exit 1 } }
}
$req=(Get-ChildItem docs/proofs -File | ?{ $_.Name -match '^2\.16\.2_proof_commit_binding_\d{8}_\d{6}Z\.log$' }).Count -gt 0
if(-not $req){ Write-Error 'MISSING REQUIRED PROOF ARTIFACT: docs/proofs/2.16.2_proof_commit_binding_<UTC>.log'; exit 1 }
Write-Host 'PROOF_COMMIT_BINDING_OK'
