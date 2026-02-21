$ErrorActionPreference = "Stop"

Write-Host "=== governance-path-coverage gate ==="

$defPath   = "docs/truth/governance_surface_definition.json"
$guardPath = "docs/truth/governance_change_guard.json"

if (-not (Test-Path $defPath))   { Write-Error "MISSING: $defPath"; exit 1 }
if (-not (Test-Path $guardPath)) { Write-Error "MISSING: $guardPath"; exit 1 }

$def   = Get-Content $defPath -Raw | ConvertFrom-Json
$guard = Get-Content $guardPath -Raw | ConvertFrom-Json

$guardPatterns = @($guard.paths | ForEach-Object { "$_" })
$exclusions    = @($def.exclusions | ForEach-Object { $_.path })
$surfacePaths  = @($def.paths | ForEach-Object { $_.pattern })

function GlobToRegex([string]$glob) {
    $g = ($glob.Trim() -replace "\\", "/")
    $g = [Regex]::Escape($g)
    $g = $g -replace "\\\*\\\*", ".*"
    $g = $g -replace "\\\*", "[^/]*"
    return "^" + $g + "$"
}

function MatchesAnyPattern([string]$path, [string[]]$patterns) {
    $p = ($path.Trim() -replace "\\", "/")
    foreach ($pat in $patterns) {
        $rx = GlobToRegex $pat
        if ($p -match $rx) { return $true }
        $root = ($pat -replace "/\*\*.*$", "") -replace "\*.*$", ""
        if ($root -and $p.StartsWith($root.TrimEnd("/") + "/")) { return $true }
        if ($root -and $p -eq $root.TrimEnd("/")) { return $true }
    }
    return $false
}

# Enumerate all files in repo (exclude .git)
$allFiles = @(git ls-files | ForEach-Object { $_.Trim() -replace "\\", "/" })

Write-Host "Total repo files: $($allFiles.Count)"
Write-Host "Governance surface patterns: $($surfacePaths.Count)"
Write-Host "Guard patterns: $($guardPatterns.Count)"
Write-Host "Exclusions: $($exclusions.Count)"

# Find files matching governance surface definition
$surfaceFiles = @()
foreach ($f in $allFiles) {
    if (MatchesAnyPattern $f $exclusions) { continue }
    if (MatchesAnyPattern $f $surfacePaths) { $surfaceFiles += $f }
}

Write-Host "Files on governance surface: $($surfaceFiles.Count)"

# Check every surface file is covered by guard patterns
$uncovered = @()
foreach ($f in $surfaceFiles) {
    if (-not (MatchesAnyPattern $f $guardPatterns)) {
        $uncovered += $f
    }
}

if ($uncovered.Count -gt 0) {
    Write-Host "UNCOVERED governance-surface files:"
    foreach ($f in $uncovered) { Write-Host "  - $f" }
    Write-Host "STATUS: FAIL — $($uncovered.Count) governance-surface file(s) not covered by guard"
    exit 1
}

Write-Host "All governance-surface files are covered by guard patterns."
Write-Host "STATUS: PASS"
exit 0