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
$schemaChanged    = $changedFiles | Where-Object { $_ -match "^generated/schema\.sql$" }

if (-not $migrationChanged) {
    Write-Host "SKIP: no migration changes detected"
    Write-Host "STATUS: PASS"
    exit 0
}

Write-Host "Migration changes detected:"
$migrationChanged | ForEach-Object { Write-Host "  $_" }

# If schema.sql is already in diff, pass (original behavior)
if ($schemaChanged) {
    Write-Host "PASS: migrations changed and generated/schema.sql is present in diff"
    Write-Host "STATUS: PASS"
    exit 0
}

# Schema-no-op exception:
# A migration text change may be DB-semantic-no-op and produce byte-identical schema dump.
# We prove schema is current by running canonical regen and asserting schema.sql remains unchanged.
Write-Host "WARN: migrations changed but generated/schema.sql not in diff"
$beforeHash = (Get-FileHash -Path "generated/schema.sql" -Algorithm SHA256).Hash
Write-Host "  schema.sql SHA256 (before regen): $beforeHash"
Write-Host "  Verifying schema is current by running canonical regen (npm run handoff)..."

npm run handoff 2>&1 | ForEach-Object { Write-Host $_ }

git diff --exit-code -- "generated/schema.sql" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: generated/schema.sql changed after regen."
    Write-Host "Fix: run 'npm run handoff' then 'npm run handoff:commit' and commit regenerated outputs."
    Write-Host "STATUS: FAIL"
    exit 1
}

$afterHash = (Get-FileHash -Path "generated/schema.sql" -Algorithm SHA256).Hash
Write-Host "  schema.sql SHA256 (after regen):  $afterHash"
Write-Host "PASS: schema-no-op migration accepted (schema.sql unchanged after regen)"
Write-Host "STATUS: PASS"
exit 0