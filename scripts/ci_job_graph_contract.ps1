$ErrorActionPreference = "Stop"

Write-Host "=== job-graph-ordering gate ==="

# Parse ci.yml using proper YAML structure — read needs: declarations
$ciYml = Get-Content ".github/workflows/ci.yml" -Raw
$lines = $ciYml -split "`n"

# Build job dependency graph from needs: declarations
$jobGraph = @{}
$currentJob = $null
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^  ([a-z][a-z0-9_-]+):$") {
        $currentJob = $Matches[1]
        $jobGraph[$currentJob] = @()
    }
    if ($currentJob -and $lines[$i] -match "^\s+needs:\s*\[(.+)\]") {
        $needs = $Matches[1] -split "," | ForEach-Object { $_.Trim() }
        $jobGraph[$currentJob] = $needs
    }
    if ($currentJob -and $lines[$i] -match "^\s+needs:\s*$") {
        # multi-line needs — not present in this repo but handle gracefully
    }
}

Write-Host "Jobs parsed: $($jobGraph.Count)"

# Assert: db-heavy (docs-only-skip implementation) has lane-enforcement in needs:
$dbHeavyNeeds = $jobGraph["db-heavy"]
Write-Host "db-heavy needs: $($dbHeavyNeeds -join ', ')"

if (-not $dbHeavyNeeds) {
    Write-Host "FAIL: db-heavy job not found in ci.yml"
    exit 1
}

if ($dbHeavyNeeds -notcontains "lane-enforcement") {
    Write-Host "FAIL: db-heavy does not have lane-enforcement in needs: — ordering is unsafe"
    Write-Host "  Found: $($dbHeavyNeeds -join ', ')"
    exit 1
}

# Confirm lane-enforcement itself exists as a job
if (-not $jobGraph.ContainsKey("lane-enforcement")) {
    Write-Host "FAIL: lane-enforcement job does not exist in ci.yml"
    exit 1
}

Write-Host "Ordering option chosen: Option A (direct needs: dependency)"
Write-Host "  db-heavy needs: lane-enforcement — direct dependency confirmed"
Write-Host "  lane-enforcement job exists: YES"
Write-Host "  Ordering guarantee: STRUCTURAL (GitHub Actions scheduling model)"
Write-Host "STATUS: PASS"
exit 0