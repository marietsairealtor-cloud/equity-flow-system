param([string]$BaseRef="origin/main")

. "$PSScriptRoot/governance_touch_matcher.ps1"
$r = Get-GovernanceTouchResult -BaseRef $BaseRef

if(-not $r.GovTouched){
  "gov_touched=false"
  exit 0
}

$files = @($r.ChangedEffective)

$justPath = $null
foreach($f in $files){
  if($f -match '^docs/governance/GOVERNANCE_CHANGE_PR\d+\.md$'){
    $justPath = $f
    break
  }
}

if(-not $justPath){
  Write-Error "GOV_TEMPLATE_CONTRACT FAIL: governance touched; missing docs/governance/GOVERNANCE_CHANGE_PR<NNN>.md"
  exit 1
}

$raw = Get-Content -Path $justPath -Raw

$required = @("What changed","Why safe","Risk","Rollback")
$missing = @()
foreach($h in $required){
  if($raw -notmatch ("(?m)^\s*#+\s*" + [Regex]::Escape($h) + "\s*$")){
    $missing += $h
  }
}
if($missing.Count -gt 0){
  Write-Error ("GOV_TEMPLATE_CONTRACT FAIL: missing required headings (string-exact): " + ($missing -join ", "))
  exit 1
}

function SectionNonWsCount([string]$text){
  return (($text -replace '\s','').Length)
}

function GetSectionBody([string]$text,[string]$heading){
  $rx = "(?ms)^\s*#+\s*" + [Regex]::Escape($heading) + "\s*$\s*(.*?)(?=^\s*#+\s*|\z)"
  $m = [Regex]::Match($text,$rx)
  if(-not $m.Success){ return "" }
  return $m.Groups[1].Value
}

$min = 40
$tooShort = @()
foreach($h in $required){
  $body = GetSectionBody $raw $h
  $n = SectionNonWsCount $body
  if($n -lt $min){
    $tooShort += ("$h=$n")
  }
}

if($tooShort.Count -gt 0){
  Write-Error ("GOV_TEMPLATE_CONTRACT FAIL: section(s) below $min non-whitespace chars: " + ($tooShort -join ", "))
  exit 1
}

"gov_touched=true"
"justification_file=$justPath"
exit 0
