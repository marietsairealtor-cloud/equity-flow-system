param([string]$BaseRef="origin/main")

function Get-GovernanceTouchResult {
  param([string]$BaseRef="origin/main")

  $diff=@(git diff --name-only "$BaseRef...HEAD" 2>$null)
  $statusTracked=@(git status --porcelain | % { $l=$_.TrimEnd(); if($l -match '^\?\?'){ $null } else { ($l.Substring(3)).Trim() } } | ? { $_ })
  $untracked=@(git ls-files --others --exclude-standard 2>$null)
  $chg=@($diff+$statusTracked+$untracked) | ? { $_ } | Sort-Object -Unique

  $cfg=Get-Content "docs/truth/governance_change_guard.json" -Raw | ConvertFrom-Json
  $chgEff=@($chg | ? { $cfg.exempt -notcontains $_ })

  function IsGovPath($path){
    foreach($p in $cfg.paths){
      $root=($p -replace '\*\*.*$','' -replace '\*.*$','').TrimEnd('/')
      if($root -and $path.StartsWith($root)){ return $true }
    }
    return $false
  }

  $gov=$false
  foreach($f in $chgEff){ if(IsGovPath $f){ $gov=$true; break } }

  return [pscustomobject]@{
    GovTouched = [bool]$gov
    ChangedEffective = @($chgEff)
    Config = $cfg
  }
}
