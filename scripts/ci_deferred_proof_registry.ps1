$ErrorActionPreference = "Stop"

Write-Host "=== deferred-proof-registry gate ==="

# Load schema and registry
$schemaPath   = "docs/truth/deferred_proofs.schema.json"
$registryPath = "docs/truth/deferred_proofs.json"

if (-not (Test-Path $schemaPath))   { Write-Error "MISSING: $schemaPath"; exit 1 }
if (-not (Test-Path $registryPath)) { Write-Error "MISSING: $registryPath"; exit 1 }

$registry = Get-Content $registryPath -Raw | ConvertFrom-Json
Write-Host "Registry entries: $($registry.Count)"

# Validate required fields
$fail = $false
foreach ($entry in $registry) {
    foreach ($field in @("gate","stub_reason","deferred_invariant","conversion_trigger")) {
        if (-not $entry.$field) {
            Write-Host "FAIL: entry missing field '$field': $($entry | ConvertTo-Json -Compress)"
            $fail = $true
        }
    }
}
if ($fail) { Write-Host "STATUS: FAIL — registry has invalid entries"; exit 1 }

# Find all db-heavy stub gates in ci.yml (echo-pattern only, per DoD)
$ciYml = Get-Content ".github/workflows/ci.yml" -Raw
$lines = $ciYml -split "`n"

# Collect job IDs that use echo-only pattern (db-heavy marker)
$stubJobs = @()
$currentJob = $null
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^  ([a-z][a-z0-9_-]+):$") {
        $currentJob = $Matches[1]
    }
    if ($currentJob -and $lines[$i] -match "echo.*PASS|echo.*skip|echo.*stub") {
        if ($stubJobs -notcontains $currentJob) {
            $stubJobs += $currentJob
        }
    }
}

Write-Host "DB-heavy stub jobs found in CI YAML:"
foreach ($j in $stubJobs) { Write-Host "  - $j" }

# Check every stub job has a registry entry
$registryGates = @($registry | ForEach-Object { $_.gate })
$missing = @()
foreach ($j in $stubJobs) {
    if ($registryGates -notcontains $j) {
        $missing += $j
    }
}

# Check no registry entry exists for a non-stub gate (converted gates)
$orphaned = @()
foreach ($g in $registryGates) {
    # Skip the AUTOMATION.md gap entry — it is not a CI job
    if ($g -eq "database-tests.yml") { continue }
    if ($stubJobs -notcontains $g) {
        $orphaned += $g
    }
}

if ($missing.Count -gt 0) {
    Write-Host "FAIL: stub gates missing from registry:"
    foreach ($m in $missing) { Write-Host "  - $m" }
    $fail = $true
}

if ($orphaned.Count -gt 0) {
    Write-Host "FAIL: registry entries for converted (non-stub) gates — remove them:"
    foreach ($o in $orphaned) { Write-Host "  - $o" }
    $fail = $true
}

if ($fail) { Write-Host "STATUS: FAIL"; exit 1 }

Write-Host "Registry entries validated:"
foreach ($entry in $registry) {
    Write-Host "  - $($entry.gate) [conversion: $($entry.conversion_trigger)]"
}
Write-Host "STATUS: PASS"
exit 0