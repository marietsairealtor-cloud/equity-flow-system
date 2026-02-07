param(
  [string]$InPath = "docs/artifacts/CONTRACTS.md",
  [string]$OutPath = "generated/contracts.snapshot.json"
)

$ErrorActionPreference = "Stop"

function Write-Utf8NoBomLf([string]$path, [string]$content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $content = $content -replace "`r`n","`n"
  [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

function Get-Sha256Hex([byte[]]$bytes) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join "") }
  finally { $sha.Dispose() }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

$inAbs  = Join-Path $repoRoot $InPath
$outAbs = Join-Path $repoRoot $OutPath

if (-not (Test-Path $inAbs)) { throw "Missing $InPath" }
New-Item -ItemType Directory -Force -Path (Split-Path $outAbs) | Out-Null

$text = (Get-Content $inAbs -Raw) -replace "`r`n","`n"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($text)

$payload = [ordered]@{
  version = 1
  source  = $InPath
  sha256  = (Get-Sha256Hex $bytes)
  bytes   = $bytes.Length
}

$json = ($payload | ConvertTo-Json -Depth 10)
Write-Utf8NoBomLf $outAbs $json

Write-Host "Wrote $OutPath (deterministic)"