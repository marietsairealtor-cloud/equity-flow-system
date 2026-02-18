param(
  # Match governed LF scope from .gitattributes + Build Route references
  [string[]] $GuardedRoots = @("docs","generated","supabase"),

  # Scan scope: repo text files (tracked + untracked), excluding build artifacts
  [string[]] $Paths = @("docs","generated","scripts","supabase",".github","src","app","pages","lib","components"),
  [string[]] $ExcludeGlobs = @("node_modules/**",".next/**","dist/**","build/**",".turbo/**",".git/**","logs/**","coverage/**"),

  # Fail rules (blocking)
  [switch] $FailOnBOM = $true,
  [switch] $FailOnZeroWidth = $true,
  [switch] $FailOnControlChars = $true,
  [switch] $FailOnNotUtf8 = $true,
  [switch] $FailOnCRLFInGuarded = $true
)

$ErrorActionPreference = "Stop"

function Is-Excluded([string]$rel) {
  foreach ($g in $ExcludeGlobs) {
    $pattern = '^' + [Regex]::Escape($g).Replace('\*\*','.*').Replace('\*','[^/]*') + '$'
    if (($rel -replace '\\','/') -match $pattern) { return $true }
  }
  return $false
}

function Is-UnderAnyRoot([string]$rel, [string[]]$roots) {
  foreach ($r in $roots) {
    $rr = ($r -replace '\\','/').TrimEnd('/')
    if ($rr -eq "." -or $rel -like "$rr/*" -or $rel -eq $rr) { return $true }
  }
  return $false
}

# Gather repo files (tracked + untracked)
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
  if (-not (Is-UnderAnyRoot $rel $roots)) { continue }
  if (Test-Path $f) { $targets += $f }
}

# Binary extensions to skip
$skipExt = @(".png",".jpg",".jpeg",".gif",".webp",".ico",".pdf",".zip",".7z",".gz",".tar",".woff",".woff2",".ttf",".eot",".mp4",".mov",".mp3",".wav",".bin",".exe",".dll")

# UTF-8 strict decode (throws on invalid)
$utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)

# Findings
$bad = New-Object System.Collections.Generic.List[string]
$warn = New-Object System.Collections.Generic.List[string]

# Forbidden sets (Build Route 2.17.2)
$zeroWidth = @(
  0x200B, # ZERO WIDTH SPACE
  0x200C, # ZERO WIDTH NON-JOINER
  0x200D, # ZERO WIDTH JOINER
  0x2060, # WORD JOINER
  0xFEFF  # ZERO WIDTH NO-BREAK SPACE (also appears as BOM in text)
)

foreach ($path in $targets) {
  $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
  if ($skipExt -contains $ext) { continue }

  $rel = ($path -replace '\\','/')
  $bytes = [IO.File]::ReadAllBytes($path)

  # BOM (UTF-8)
  if ($FailOnBOM -and $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $bad.Add("BOM: $rel")
    continue
  }

  # Guarded LF-only (CRLF forbidden)
  if ($FailOnCRLFInGuarded -and (Is-UnderAnyRoot $rel $GuardedRoots)) {
    for ($i = 0; $i -lt ($bytes.Length - 1); $i++) {
      if ($bytes[$i] -eq 0x0D -and $bytes[$i+1] -eq 0x0A) {
        $bad.Add("CRLF_GUARDED: $rel")
        break
      }
    }
    if ($bad.Count -gt 0 -and $bad[$bad.Count-1] -like "CRLF_GUARDED: $rel") { continue }
  }

  # UTF-8 strict decode
  $text = $null
  try {
    $text = $utf8Strict.GetString($bytes)
  } catch {
    if ($FailOnNotUtf8) {
      $bad.Add("NOT_UTF8: $rel")
      continue
    } else {
      $warn.Add("NOT_UTF8: $rel")
      continue
    }
  }

  # Zero-width chars
  if ($FailOnZeroWidth) {
    foreach ($cp in $zeroWidth) {
      if ($text.IndexOf([char]$cp) -ge 0) {
        $bad.Add(("ZERO_WIDTH_U+{0:X4}: {1}" -f $cp, $rel))
        break
      }
    }
    if ($bad.Count -gt 0 -and $bad[$bad.Count-1] -like "ZERO_WIDTH_*: $rel") { continue }
  }

  # Control chars (forbidden except TAB/LF/CR)
  if ($FailOnControlChars) {
    $chars = $text.ToCharArray()
    $found = $false
    foreach ($c in $chars) {
      $n = [int][char]$c
      $isControl = ($n -lt 0x20) -or ($n -eq 0x7F)
      if ($isControl -and $n -ne 0x09 -and $n -ne 0x0A -and $n -ne 0x0D) {
        $bad.Add(("CONTROL_U+{0:X4}: {1}" -f $n, $rel))
        $found = $true
        break
      }
    }
    if ($found) { continue }
  }
}

if ($warn.Count -gt 0) {
  Write-Host "ENCODING AUDIT WARN (non-blocking):" -ForegroundColor Yellow
  $warn | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
  Write-Host ""
}

if ($bad.Count -gt 0) {
  Write-Host "ENCODING AUDIT FAILED (blocking):" -ForegroundColor Red
  $bad | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  Write-Host ""
  Write-Host "Repair: npm run fix:encoding" -ForegroundColor Yellow
  exit 1
}

Write-Host "ci_encoding_audit OK."
