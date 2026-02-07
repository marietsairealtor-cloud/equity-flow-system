param(
  [string[]] $Paths = @("docs","generated","scripts","supabase",".github","src","app","pages","lib","components"),
  [string[]] $ExcludeGlobs = @("node_modules/**",".next/**","dist/**","build/**",".turbo/**",".git/**","logs/**","coverage/**"),
  [switch] $FailOnBOM = $true,
  [switch] $FailOnFFFD = $true
)

$ErrorActionPreference = "Stop"

function Is-Excluded([string]$rel) {
  foreach ($g in $ExcludeGlobs) {
    $pattern = '^' + [Regex]::Escape($g).Replace('\*\*','.*').Replace('\*','[^/]*') + '$'
    if (($rel -replace '\\','/') -match $pattern) { return $true }
  }
  return $false
}

$tracked = (& git ls-files) 2>$null
$others  = (& git ls-files -o --exclude-standard) 2>$null
$all = @($tracked + $others) | Where-Object { $_ -and $_.Trim() -ne "" } | Sort-Object -Unique

$roots = @()
foreach ($p in $Paths) { if (Test-Path $p) { $roots += ($p.TrimEnd('/','\')) } }
if ($roots.Count -eq 0) { $roots = @(".") }

$targets = @()
foreach ($f in $all) {
  $rel = ($f -replace '\\','/')
  if (Is-Excluded $rel) { continue }

  $inScope = $false
  foreach ($r in $roots) {
    $rr = ($r -replace '\\','/').TrimEnd('/')
    if ($rr -eq "." -or $rel -like "$rr/*" -or $rel -eq $rr) { $inScope = $true; break }
  }
  if ($inScope -and (Test-Path $f)) { $targets += $f }
}

$utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
$bad = New-Object System.Collections.Generic.List[string]

foreach ($path in $targets) {
  $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
  if ($ext -in @(".png",".jpg",".jpeg",".gif",".webp",".ico",".pdf",".zip",".7z",".gz",".tar",".woff",".woff2",".ttf",".eot",".mp4",".mov",".mp3",".wav",".bin",".exe",".dll")) { continue }

  $bytes = [IO.File]::ReadAllBytes($path)

  if ($FailOnBOM -and $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $bad.Add("BOM: $path")
    continue
  }

  try {
    $text = $utf8Strict.GetString($bytes)
  } catch {
    $bad.Add("NOT_UTF8: $path")
    continue
  }

  if ($FailOnFFFD -and $text.IndexOf([char]0xFFFD) -ge 0) {
    $bad.Add("U+FFFD: $path")
    continue
  }
}

if ($bad.Count -gt 0) {
  Write-Host "ENCODING PREFLIGHT FAILED:" -ForegroundColor Red
  $bad | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  Write-Host ""
  Write-Host "Run: npm run fix:encoding" -ForegroundColor Yellow
  exit 1
}

Write-Host "Encoding preflight OK."