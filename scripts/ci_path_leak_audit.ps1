param(
  # Blocking scope (explicit allowlist)
  [string[]] $BlockingRoots = @("generated","docs/proofs"),

  # Alert-only scope
  [string] $DocsRoot = "docs"
)

$ErrorActionPreference = "Stop"

function Get-RepoFilesUnder([string[]]$roots) {
  $files = New-Object System.Collections.Generic.List[string]
  foreach ($r in $roots) {
    if (-not (Test-Path $r)) { continue }
    (& git ls-files -- $r) 2>$null | ForEach-Object { if($_){ $files.Add($_) } }
    (& git ls-files -o --exclude-standard -- $r) 2>$null | ForEach-Object { if($_){ $files.Add($_) } }
  }
  return $files | Sort-Object -Unique
}

function Is-UnderAnyRoot([string]$rel, [string[]]$roots) {
  $p = ($rel -replace '\\','/').TrimStart('./')
  foreach ($r in $roots) {
    $rr = ($r -replace '\\','/').TrimEnd('/')
    if ($p -eq $rr -or $p -like "$rr/*") { return $true }
  }
  return $false
}

# Binary extensions to skip
$skipExt = @(
  ".png",".jpg",".jpeg",".gif",".webp",".ico",".pdf",".zip",".7z",".gz",".tar",
  ".woff",".woff2",".ttf",".eot",".mp4",".mov",".mp3",".wav",".bin",".exe",".dll"
)

# Forbidden absolute roots (DoD exact list)
$mac = "/Users/"
$runner = "/home/runner/"

function Scan-File([string]$path) {
  $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
  if ($skipExt -contains $ext) { return @() }
  if (-not (Test-Path $path)) { return @() }

  $bytes = [IO.File]::ReadAllBytes($path)
  # Best-effort UTF-8 decode (encoding audit covers strictness elsewhere)
  $text = [Text.Encoding]::UTF8.GetString($bytes)

  $hits = New-Object System.Collections.Generic.List[string]

  if ($text -match "(?i)C:\\") { $hits.Add("C:\") }
  if ($text -match "(?i)C:/")  { $hits.Add("C:/") }
  if ($text.Contains($mac))    { $hits.Add($mac) }
  if ($text.Contains($runner)) { $hits.Add($runner) }

  return $hits | Sort-Object -Unique
}

$blockingFiles = Get-RepoFilesUnder $BlockingRoots

# docs/** outside docs/proofs/** is alert-only
$docsAll = @()
if (Test-Path $DocsRoot) {
  $docsAll = (& git ls-files -- $DocsRoot) 2>$null
  $docsAll += (& git ls-files -o --exclude-standard -- $DocsRoot) 2>$null
  $docsAll = $docsAll | Where-Object { $_ -and $_.Trim() -ne "" } | Sort-Object -Unique
}
$docsAlert = $docsAll | Where-Object { -not (Is-UnderAnyRoot $_ @("docs/proofs")) }

$fail = New-Object System.Collections.Generic.List[string]
$warn = New-Object System.Collections.Generic.List[string]

foreach ($f in $blockingFiles) {
  $hits = Scan-File $f
  foreach ($h in $hits) { $fail.Add("$f :: $h") }
}

foreach ($f in $docsAlert) {
  $hits = Scan-File $f
  foreach ($h in $hits) { $warn.Add("$f :: $h") }
}

if ($warn.Count -gt 0) {
  Write-Host "PATH LEAK WARN (alert-only docs/** outside docs/proofs/**):" -ForegroundColor Yellow
  $warn | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
  Write-Host ""
}

if ($fail.Count -gt 0) {
  Write-Host "PATH LEAK AUDIT FAILED (blocking scope):" -ForegroundColor Red
  $fail | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  Write-Host ""
  Write-Host "Fix: remove/replace absolute machine roots in generated/** or docs/proofs/**." -ForegroundColor Yellow
  exit 1
}

Write-Host "ci_path_leak_audit OK."