param(
  [string[]] $AllowlistedRoots = @("docs","generated","scripts","supabase",".github"),
  [switch] $AlsoRenormalize = $true
)

$ErrorActionPreference = "Stop"

function ExistingRoots([string[]]$roots) {
  $out = @()
  foreach ($r in $roots) { if (Test-Path $r) { $out += $r } }
  return $out
}

function Convert-ToUtf8NoBom([string]$path) {
  $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
  if ($ext -in @(".png",".jpg",".jpeg",".gif",".webp",".ico",".pdf",".zip",".7z",".gz",".tar",".woff",".woff2",".ttf",".eot",".mp4",".mov",".mp3",".wav",".bin",".exe",".dll")) { return }

  $bytes = [IO.File]::ReadAllBytes($path)

  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $bytes = $bytes[3..($bytes.Length-1)]
  }

  $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
  try {
    $text = $utf8Strict.GetString($bytes)
  } catch {
    throw "NOT_UTF8 (manual fix required): $path"
  }

  if ($text.IndexOf([char]0xFFFD) -ge 0) {
    throw "U+FFFD present (manual fix required): $path"
  }

  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($path, $text, $enc)
}

$roots = ExistingRoots $AllowlistedRoots
if ($roots.Count -eq 0) { Write-Host "No allowlisted roots exist. Nothing to fix."; exit 0 }

$tracked = (& git ls-files) 2>$null
$others  = (& git ls-files -o --exclude-standard) 2>$null
$all = @($tracked + $others) | Where-Object { $_ -and $_.Trim() -ne "" } | Sort-Object -Unique

$files = @()
foreach ($f in $all) {
  foreach ($r in $roots) {
    $rr = ($r -replace '\\','/').TrimEnd('/')
    $ff = ($f -replace '\\','/')
    if ($ff -eq $rr -or $ff -like "$rr/*") { if (Test-Path $f) { $files += $f }; break }
  }
}
$files = $files | Sort-Object -Unique

foreach ($f in $files) { Convert-ToUtf8NoBom $f }

if ($AlsoRenormalize) {
  & git add --renormalize -- $roots | Out-Null
}

Write-Host "fix:encoding complete."