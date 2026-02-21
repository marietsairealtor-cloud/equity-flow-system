$ErrorActionPreference = "Stop"

Write-Host "=== handoff-idempotency gate ==="

if ($env:CI -eq "true") {
    Write-Host "CI environment detected — gate is local-only (requires live DB). Skipping."
    Write-Host "STATUS: PASS (stub)"
    exit 0
}

# Capture run 1 outputs
Write-Host "--- Run 1: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/handoff.ps1 ---"
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/handoff.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "STATUS: FAIL — handoff run 1 failed (exit $LASTEXITCODE)"
    exit 1
}
$h1 = Get-Content docs/handoff_latest.txt -Raw
$s1 = Get-Content generated/schema.sql -Raw
$c1 = Get-Content generated/contracts.snapshot.json -Raw

# Run handoff a second time immediately — no commits between
Write-Host "--- Run 2: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/handoff.ps1 ---"
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/handoff.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "STATUS: FAIL — handoff run 2 failed (exit $LASTEXITCODE)"
    exit 1
}
$h2 = Get-Content docs/handoff_latest.txt -Raw
$s2 = Get-Content generated/schema.sql -Raw
$c2 = Get-Content generated/contracts.snapshot.json -Raw

# Compare run 1 vs run 2 directly
$fail = $false
if ($h1 -ne $h2) { Write-Host "DIFF: docs/handoff_latest.txt changed between run 1 and run 2"; $fail = $true }
if ($s1 -ne $s2) { Write-Host "DIFF: generated/schema.sql changed between run 1 and run 2"; $fail = $true }
if ($c1 -ne $c2) { Write-Host "DIFF: generated/contracts.snapshot.json changed between run 1 and run 2"; $fail = $true }

if ($fail) {
    Write-Host "STATUS: FAIL — handoff is not idempotent"
    exit 1
}

Write-Host "STATUS: PASS — handoff is idempotent (second run produced zero diffs)"

# Restore truth artifacts — gate proved idempotency, clean up working tree
git checkout -- generated/ docs/handoff_latest.txt

exit 0