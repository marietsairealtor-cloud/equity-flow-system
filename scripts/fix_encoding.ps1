param(
  [string[]] $AllowlistedRoots = @("docs","generated","scripts","supabase",".github"),
  [switch] $AlsoRenormalize = $true
)

$ErrorActionPreference = "Stop"



function Strip-ForbiddenChars([string]$text) {
  # Remove zero-width chars (Build Route 2.17.2)
  $zw = @([char]0x200B,[char]0x200C,[char]0x200D,[char]0x2060,[char]0xFEFF)
  foreach ($c in $zw) { $text = $text.Replace([string]$c, "") }

  # Remove control chars except TAB(0x09), LF(0x0A), CR(0x0D)
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $text.ToCharArray()) {
    $n = [int][char]$ch
    $isControl = ($n -lt 0x20) -or ($n -eq 0x7F)
    if ($isControl -and $n -ne 0x09 -and $n -ne 0x0A -and $n -ne 0x0D) { continue }
    [void]$sb.Append($ch)
  }
  return $sb.ToString()
}
function ExistingRoots([string[]]$roots) {
  $out = @()
  foreach ($r in $roots) { if (Test-Path $r) { $out += $r } }
  return $out
}

function Is-GuardedPath([string]$path) {
  $p = ($path -replace "\\","/").ToLowerInvariant()
  return ($p -like "docs/*" -or $p -eq "docs") -or ($p -like "generated/*" -or $p -eq "generated") -or ($p -like "supabase/*" -or $p -eq "supabase")
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
  $out = (Strip-ForbiddenChars $text)
  if (Is-GuardedPath $path) {
    $out = $out -replace "`r`n","`n"
    $out = $out -replace "`r","`n"
  }
  [IO.File]::WriteAllText($path, $out, $enc)
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




