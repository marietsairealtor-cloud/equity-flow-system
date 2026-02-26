# ci_blocked_identifiers.ps1
# Gate: blocked-identifiers (merge-blocking)
# Build Route: 6.5 — Blocked identifiers lint
# Fails if any blocked identifier from docs/truth/blocked_identifiers.json
# appears in supabase/migrations/** or SQL function definitions.
# Authority: Build Route v2.4 S6.5

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== blocked-identifiers gate ==="

# --- Load blocked identifiers ---
$truthPath = "docs/truth/blocked_identifiers.json"
if (-not (Test-Path $truthPath)) { throw "blocked-identifiers: $truthPath not found" }
$truth = Get-Content $truthPath -Raw | ConvertFrom-Json
$blocked = @($truth.blocked)

if ($blocked.Count -eq 0) {
    Write-Host "blocked-identifiers: no blocked identifiers defined. PASS"
    exit 0
}

Write-Host "blocked-identifiers: checking for [$($blocked -join ', ')]"

# --- Scan migrations ---
$fail = $false
$migrationDir = "supabase/migrations"

if (-not (Test-Path $migrationDir)) {
    Write-Host "blocked-identifiers: no migrations directory. PASS"
    exit 0
}

$sqlFiles = Get-ChildItem $migrationDir -Filter "*.sql" -Recurse

foreach ($file in $sqlFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    foreach ($id in $blocked) {
        $pattern = "(?i)\b$([Regex]::Escape($id))\b"
        $matches = [Regex]::Matches($content, $pattern)
        if ($matches.Count -gt 0) {
            foreach ($m in $matches) {
                $lineNum = ($content.Substring(0, $m.Index) -split "`n").Count
                Write-Host "FAIL: blocked identifier '$id' found in $($file.Name) at line $lineNum"
                $fail = $true
            }
        }
    }
}

# --- Result ---
Write-Host ""
if ($fail) {
    Write-Host "blocked-identifiers: FAIL"
    Write-Host "Fix: remove or replace blocked identifiers. See docs/truth/blocked_identifiers.json."
    exit 1
} else {
    Write-Host "blocked-identifiers: PASS"
    exit 0
}
