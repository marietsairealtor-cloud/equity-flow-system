$ErrorActionPreference = "Stop"

Write-Host "=== migration-schema-coupling gate ==="

# Get list of changed files in this PR
$changedFiles = git diff --name-only origin/main...HEAD 2>&1
if ($LASTEXITCODE -ne 0) {
    # Fallback: compare against HEAD~1
    $changedFiles = git diff --name-only HEAD~1 HEAD 2>&1
}

Write-Host "Changed files:"
$changedFiles | ForEach-Object { Write-Host "  $_" }

$migrationChanged = $changedFiles | Where-Object { $_ -match "^supabase/migrations/" }
$schemaChanged = $changedFiles | Where-Object { $_ -match "^generated/schema\.sql$" }

if (-not $migrationChanged) {
    Write-Host "SKIP: no migration changes detected"
    Write-Host "STATUS: PASS"
    exit 0
}

Write-Host "Migration changes detected:"
$migrationChanged | ForEach-Object { Write-Host "  $_" }

if (-not $schemaChanged) {
    Write-Host "FAIL: migrations changed but generated/schema.sql not updated — run 'npm run handoff' then 'npm run handoff:commit' on the PR branch"
    Write-Host "STATUS: FAIL"
    exit 1
}

Write-Host "PASS: migrations changed and generated/schema.sql is present in diff"
Write-Host "STATUS: PASS"
exit 0