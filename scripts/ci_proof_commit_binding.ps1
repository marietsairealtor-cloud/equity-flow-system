Continue='Stop'
git fetch origin main | Out-Null
='origin/main'
aa6a3fa9468a561727f5df59c03fb394cd92e07d=(git rev-parse HEAD).Trim()

function FileSha([string]){
  C:/Users/marie/projects/equity-flow-system=(git rev-parse --show-toplevel).Trim()
  (Get-FileHash -Algorithm SHA256 (Join-Path C:/Users/marie/projects/equity-flow-system )).Hash.ToLower()
}
function ScriptsHash(){
   = (FileSha 'scripts\ci_proofs_append_only.ps1') + (FileSha 'scripts\ci_proof_manifest.ps1') + (FileSha 'scripts\ci_proof_commit_binding.ps1')
  System.Security.Cryptography.SHA256+Implementation=[System.Security.Cryptography.SHA256]::Create()
  try{ ([BitConverter]::ToString(System.Security.Cryptography.SHA256+Implementation.ComputeHash([Text.Encoding]::UTF8.GetBytes())) -replace '-','').ToLower() } finally{ System.Security.Cryptography.SHA256+Implementation.Dispose() }
}
4ab2fd5ab86b2419092c5286bc86d618cb4b6d23f82eede07966c3b842378fac=ScriptsHash

 = git diff --name-status "...HEAD" -- docs/proofs | %{.Trim()} | ?{}
=@(); foreach( in ){= -split "\s+"; =[0]; =[1]; if( -eq 'docs/proofs/manifest.json'){continue}; if( -match '^[AMD]'){  +=  } }
if(.Count -eq 0){ Write-Error 'PROOF_COMMIT_BINDING_FAIL: no proof files changed in PR'; exit 1 }

foreach( in ){
  $ErrorActionPreference='Stop'
git fetch origin main | Out-Null
$base='origin/main'
$head=(git rev-parse HEAD~1).Trim()  # bind proofs to pre-commit head
$root=(git rev-parse --show-toplevel).Trim()
function FileSha([string]$rel){(Get-FileHash -Algorithm SHA256 (Join-Path $root $rel)).Hash.ToLower()}
function ScriptsHash(){ $h=FileSha('scripts\ci_proofs_append_only.ps1')+FileSha('scripts\ci_proof_manifest.ps1')+FileSha('scripts\ci_proof_commit_binding.ps1'); $sha=[System.Security.Cryptography.SHA256]::Create(); try{([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($h))) -replace '-','').ToLower()} finally{$sha.Dispose()} }
$scriptsHash=ScriptsHash
$chg = git diff --name-status "$base...HEAD" -- docs/proofs | %{$_.Trim()} | ?{$_}
$need=@(); foreach($l in $chg){$p=$l -split "\s+"; $st=$p[0]; $f=$p[1]; if($f -eq 'docs/proofs/manifest.json'){continue}; if($st -match '^[AMD]'){ $need += $f } }
if($need.Count -eq 0){ Write-Error 'PROOF_COMMIT_BINDING_FAIL: no proof files changed in PR'; exit 1 }
foreach($f in $need){ $t=Get-Content $f -Raw; if($t -notmatch '(?m)^PROOF_HEAD=([0-9a-f]{40})?$'){ Write-Error "MISSING PROOF_HEAD: $f"; exit 1 }; if($Matches[1] -ne $head){ Write-Error "HEAD MISMATCH: $f (got $($Matches[1]) expected $head)"; exit 1 }; if($t -notmatch '(?m)^PROOF_SCRIPTS_HASH=([0-9a-f]{64})?$'){ Write-Error "MISSING PROOF_SCRIPTS_HASH: $f"; exit 1 }; if($Matches[1] -ne $scriptsHash){ Write-Error "SCRIPTS_HASH MISMATCH: $f"; exit 1 } }
$req=(Get-ChildItem docs/proofs -File | ?{$_.Name -match '^2\.16\.2_proof_commit_binding_\d{8}_\d{6}Z\.log$'}).Count -gt 0; if(-not $req){ Write-Error 'MISSING REQUIRED PROOF ARTIFACT: docs/proofs/2.16.2_proof_commit_binding_<UTC>.log'; exit 1 }
Write-Host 'PROOF_COMMIT_BINDING_OK'


=Get-Content  -Raw
  if($ErrorActionPreference='Stop'
git fetch origin main | Out-Null
$base='origin/main'
$head=(git rev-parse HEAD~1).Trim()  # bind proofs to pre-commit head
$root=(git rev-parse --show-toplevel).Trim()
function FileSha([string]$rel){(Get-FileHash -Algorithm SHA256 (Join-Path $root $rel)).Hash.ToLower()}
function ScriptsHash(){ $h=FileSha('scripts\ci_proofs_append_only.ps1')+FileSha('scripts\ci_proof_manifest.ps1')+FileSha('scripts\ci_proof_commit_binding.ps1'); $sha=[System.Security.Cryptography.SHA256]::Create(); try{([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($h))) -replace '-','').ToLower()} finally{$sha.Dispose()} }
$scriptsHash=ScriptsHash
$chg = git diff --name-status "$base...HEAD" -- docs/proofs | %{$_.Trim()} | ?{$_}
$need=@(); foreach($l in $chg){$p=$l -split "\s+"; $st=$p[0]; $f=$p[1]; if($f -eq 'docs/proofs/manifest.json'){continue}; if($st -match '^[AMD]'){ $need += $f } }
if($need.Count -eq 0){ Write-Error 'PROOF_COMMIT_BINDING_FAIL: no proof files changed in PR'; exit 1 }
foreach($f in $need){ $t=Get-Content $f -Raw; if($t -notmatch '(?m)^PROOF_HEAD=([0-9a-f]{40})?$'){ Write-Error "MISSING PROOF_HEAD: $f"; exit 1 }; if($Matches[1] -ne $head){ Write-Error "HEAD MISMATCH: $f (got $($Matches[1]) expected $head)"; exit 1 }; if($t -notmatch '(?m)^PROOF_SCRIPTS_HASH=([0-9a-f]{64})?$'){ Write-Error "MISSING PROOF_SCRIPTS_HASH: $f"; exit 1 }; if($Matches[1] -ne $scriptsHash){ Write-Error "SCRIPTS_HASH MISMATCH: $f"; exit 1 } }
$req=(Get-ChildItem docs/proofs -File | ?{$_.Name -match '^2\.16\.2_proof_commit_binding_\d{8}_\d{6}Z\.log$'}).Count -gt 0; if(-not $req){ Write-Error 'MISSING REQUIRED PROOF ARTIFACT: docs/proofs/2.16.2_proof_commit_binding_<UTC>.log'; exit 1 }
Write-Host 'PROOF_COMMIT_BINDING_OK'


 -notmatch '(?m)^PROOF_HEAD=([0-9a-f]{40})\r?$'){ Write-Error "MISSING PROOF_HEAD: "; exit 1 }
  =[1]
  if($ErrorActionPreference='Stop'
git fetch origin main | Out-Null
$base='origin/main'
$head=(git rev-parse HEAD~1).Trim()  # bind proofs to pre-commit head
$root=(git rev-parse --show-toplevel).Trim()
function FileSha([string]$rel){(Get-FileHash -Algorithm SHA256 (Join-Path $root $rel)).Hash.ToLower()}
function ScriptsHash(){ $h=FileSha('scripts\ci_proofs_append_only.ps1')+FileSha('scripts\ci_proof_manifest.ps1')+FileSha('scripts\ci_proof_commit_binding.ps1'); $sha=[System.Security.Cryptography.SHA256]::Create(); try{([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($h))) -replace '-','').ToLower()} finally{$sha.Dispose()} }
$scriptsHash=ScriptsHash
$chg = git diff --name-status "$base...HEAD" -- docs/proofs | %{$_.Trim()} | ?{$_}
$need=@(); foreach($l in $chg){$p=$l -split "\s+"; $st=$p[0]; $f=$p[1]; if($f -eq 'docs/proofs/manifest.json'){continue}; if($st -match '^[AMD]'){ $need += $f } }
if($need.Count -eq 0){ Write-Error 'PROOF_COMMIT_BINDING_FAIL: no proof files changed in PR'; exit 1 }
foreach($f in $need){ $t=Get-Content $f -Raw; if($t -notmatch '(?m)^PROOF_HEAD=([0-9a-f]{40})?$'){ Write-Error "MISSING PROOF_HEAD: $f"; exit 1 }; if($Matches[1] -ne $head){ Write-Error "HEAD MISMATCH: $f (got $($Matches[1]) expected $head)"; exit 1 }; if($t -notmatch '(?m)^PROOF_SCRIPTS_HASH=([0-9a-f]{64})?$'){ Write-Error "MISSING PROOF_SCRIPTS_HASH: $f"; exit 1 }; if($Matches[1] -ne $scriptsHash){ Write-Error "SCRIPTS_HASH MISMATCH: $f"; exit 1 } }
$req=(Get-ChildItem docs/proofs -File | ?{$_.Name -match '^2\.16\.2_proof_commit_binding_\d{8}_\d{6}Z\.log$'}).Count -gt 0; if(-not $req){ Write-Error 'MISSING REQUIRED PROOF ARTIFACT: docs/proofs/2.16.2_proof_commit_binding_<UTC>.log'; exit 1 }
Write-Host 'PROOF_COMMIT_BINDING_OK'


 -notmatch '(?m)^PROOF_SCRIPTS_HASH=([0-9a-f]{64})\r?$'){ Write-Error "MISSING PROOF_SCRIPTS_HASH: "; exit 1 }
  if([1] -ne 4ab2fd5ab86b2419092c5286bc86d618cb4b6d23f82eede07966c3b842378fac){ Write-Error "SCRIPTS_HASH MISMATCH: "; exit 1 }

  git merge-base --is-ancestor  aa6a3fa9468a561727f5df59c03fb394cd92e07d
  if(1 -ne 0){ Write-Error "PROOF_HEAD_NOT_ANCESTOR:  (PROOF_HEAD= HEAD=aa6a3fa9468a561727f5df59c03fb394cd92e07d)"; exit 1 }

   = git diff --name-only "..aa6a3fa9468a561727f5df59c03fb394cd92e07d" | %{.Trim()} | ?{}
  foreach( in ){
    if( -notmatch '^docs/proofs/'){ Write-Error "POST_PROOF_NON_PROOF_CHANGE:  (since )"; exit 1 }
  }
}

=(Get-ChildItem docs/proofs -File | ?{.Name -match '^2\.16\.2_proof_commit_binding_\d{8}_\d{6}Z\.log$'}).Count -gt 0
if(-not ){ Write-Error 'MISSING REQUIRED PROOF ARTIFACT: docs/proofs/2.16.2_proof_commit_binding_<UTC>.log'; exit 1 }

Write-Host 'PROOF_COMMIT_BINDING_OK'
