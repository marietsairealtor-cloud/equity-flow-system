param([string]$BaseRef="origin/main")
$diff=@(git diff --name-only "$BaseRef...HEAD" 2>$null)
$statusTracked=@(git status --porcelain | % { $l=$_.TrimEnd(); if($l -match '^\?\?'){ $null } else { ($l.Substring(3)).Trim() } } | ? { $_ })
$untracked=@(git ls-files --others --exclude-standard 2>$null)
$chg=@($diff+$statusTracked+$untracked) | ? { $_ } | Sort-Object -Unique
$cfg=Get-Content "docs/truth/governance_change_guard.json" -Raw | ConvertFrom-Json
$chgEff=@($chg | ? { $cfg.exempt -notcontains $_ })
function IsGovPath($path){ foreach($p in $cfg.paths){ $root=($p -replace '\*\*.*$','' -replace '\*.*$','').TrimEnd('/'); if($root -and $path.StartsWith($root)){ return $true } }; return $false }
$gov=$false; foreach($f in $chgEff){ if(IsGovPath $f){ $gov=$true; break } }
$hasJust=$false; foreach($f in $chgEff){ if($f -match '^docs/governance/GOVERNANCE_CHANGE_PR\d+\.md$'){ $hasJust=$true; break } }
if($gov -and -not $hasJust){ Write-Error "GOV_CHANGE_GUARD FAIL: governance touched; missing docs/governance/GOVERNANCE_CHANGE_PR<NNN>.md (must be included in PR changes)"; exit 1 }
"gov_touched=$gov"; exit 0