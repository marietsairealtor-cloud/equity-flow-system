# ci_normalize_sweep.ps1 - Gate: ci-normalize-sweep (merge-blocking)
# DoD 2.17.1: Fails if git add --renormalize produces any diff on governed paths
# NOTE: Must be run against a clean working tree (CI always satisfies this; run locally after committing)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== ci_normalize_sweep: START ==="

$allowlisted = @("docs/", "generated/", "supabase/")
$present = $allowlisted | Where-Object { Test-Path $_ }
$skipped = $allowlisted | Where-Object { -not (Test-Path $_) }

if ($skipped) {
    Write-Host "SKIP (path not present): $($skipped -join ', ')"
}

if (-not $present) {
    Write-Host "No governed paths present. RESULT=PASS"
    exit 0
}

Write-Host "Checking paths: $($present -join ', ')"

# Check working tree is clean for governed paths before renormalize
$dirty = git status --porcelain -- $present 2>&1 | Where-Object { $_ -match "^\s*M" }
if ($dirty) {
    Write-Host "WARN: Working tree has uncommitted changes in governed paths - renormalize check may be unreliable locally"
    Write-Host "INFO: In CI this gate always runs against committed state"
}

git add --renormalize -- $present 2>&1 | Where-Object { $_ -notmatch "^warning:" }
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: git add --renormalize exited $LASTEXITCODE"
    exit 1
}

$diff = git diff --cached --name-only -- $present 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: git diff exited $LASTEXITCODE"
    exit 1
}

# Reset index to avoid side effects
git reset HEAD -- $present 2>&1 | Out-Null

if ($diff) {
    Write-Host "FAIL: renormalization produced diff on the following files:"
    $diff | ForEach-Object { Write-Host "  $_" }
    Write-Host "RESULT=FAIL"
    exit 1
}

Write-Host "No renormalization diff detected."
Write-Host "RESULT=PASS"
exit 0