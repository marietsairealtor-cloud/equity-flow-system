Continue='Stop'
git fetch origin main | Out-Null
='origin/main'
aa6a3fa9468a561727f5df59c03fb394cd92e07d=(git rev-parse HEAD).Trim()
C:/Users/marie/projects/equity-flow-system=(git rev-parse --show-toplevel).Trim()
function FileSha([string]$rel){ (Get-FileHash -Algorithm SHA256 (Join-Path $root $rel)).Hash.ToLower() }
function ScriptsHash(){ $h=(FileSha 'scripts\ci_proof_commit_binding.ps1'); $sha=[System.Security.Cryptography.SHA256]::Create(); try{ ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($h))) -replace '-','').ToLower() } finally{ $sha.Dispose() } }
4ab2fd5ab86b2419092c5286bc86d618cb4b6d23f82eede07966c3b842378fac=ScriptsHash
 = git diff --name-status "...HEAD" -- docs/proofs | % { $_.Trim() } | ? { $_ }
=@(); foreach($l in $chg){ $p=$l -split "\s+"; $st=$p[0]; $f=$p[1]; if($f -eq 'docs/proofs/manifest.json'){continue}; if($st -match '^[AMD]'){ $need += $f } }
if($need.Count -eq 0){ Write-Error 'PROOF_COMMIT_BINDING_FAIL: no proof files changed in PR'; exit 1 }
foreach($f in $need){ $t=Get-Content $f -Raw; if($t -notmatch '(?m)^PROOF_HEAD=([0-9a-f]{40})\r?$'){ Write-Error "MISSING PROOF_HEAD: $f"; exit 1 }; $proofHead=$Matches[1]; if($t -notmatch '(?m)^PROOF_SCRIPTS_HASH=([0-9a-f]{64})\r?$'){ Write-Error "MISSING PROOF_SCRIPTS_HASH: $f"; exit 1 }; if($Matches[1] -ne $scriptsHash){ Write-Error "SCRIPTS_HASH MISMATCH: $f"; exit 1 }; git merge-base --is-ancestor $proofHead $head; if($LASTEXITCODE -ne 0){ Write-Error "PROOF_HEAD_NOT_ANCESTOR: $f"; exit 1 }; $post = git diff --name-only "$proofHead..$head" | % { $_.Trim() } | ? { $_ }; foreach($x in $post){ if($x -notmatch '^docs/proofs/'){ Write-Error "POST_PROOF_NON_PROOF_CHANGE: $x"; exit 1 } } }
$req=(Get-ChildItem docs/proofs -File | ?{ $_.Name -match '^2\.16\.2_proof_commit_binding_\d{8}_\d{6}Z\.log$' }).Count -gt 0; if(-not $req){ Write-Error 'MISSING REQUIRED PROOF ARTIFACT: docs/proofs/2.16.2_proof_commit_binding_<UTC>.log'; exit 1 }
Write-Host 'PROOF_COMMIT_BINDING_OK'
