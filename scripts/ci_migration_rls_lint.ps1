$ErrorActionPreference = "Stop"

Write-Host "=== migration-rls-colocation gate ==="

$migrationsPath = "supabase/migrations"
if (-not (Test-Path $migrationsPath)) { Write-Error "MISSING: $migrationsPath"; exit 1 }

# Baseline remediation boundary — migrations before this version are exempt
# Corrective migration 20260219000006 merged before gate activation per Build Route 5.1 pre-check
$CUTOFF = "20260219000006"

$files = Get-ChildItem $migrationsPath -Filter "*.sql" | Sort-Object Name
Write-Host "Scanning $($files.Count) migration file(s) (cutoff: $CUTOFF)..."

$fail = $false

foreach ($file in $files) {
    $version = $file.Name -replace "_.*$", ""

    if ($version -lt $CUTOFF) {
        Write-Host "SKIP (pre-cutoff): $($file.Name)"
        continue
    }

    $fileContent = Get-Content $file.FullName -Raw
    $lines = Get-Content $file.FullName

    # Find all CREATE TABLE statements
    $tableNames = @()
    foreach ($line in $lines) {
        if ($line -match '(?i)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:public\.)?["`]?(\w+)["`]?') {
            $tableNames += $Matches[1]
        }
    }

    if ($tableNames.Count -eq 0) {
        Write-Host "SKIP (no CREATE TABLE): $($file.Name)"
        continue
    }

    foreach ($table in $tableNames) {
        $hasRLS = $fileContent -match "(?i)ALTER\s+TABLE\s+(?:public\.)?[`"']?$table[`"']?\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY"
        $hasRevokeAnon = $fileContent -match "(?i)REVOKE\s+ALL.*ON\s+(?:TABLE\s+)?(?:public\.)?[`"']?$table[`"']?\s+FROM\s+(?:anon|authenticated,\s*anon|anon,\s*authenticated)"
        $hasRevokeAuth = $fileContent -match "(?i)REVOKE\s+ALL.*ON\s+(?:TABLE\s+)?(?:public\.)?[`"']?$table[`"']?\s+FROM\s+(?:authenticated|anon,\s*authenticated|authenticated,\s*anon)"
        $hasBlanketRevoke = $fileContent -match "(?i)REVOKE\s+ALL.*ON\s+ALL\s+TABLES\s+IN\s+SCHEMA\s+public\s+FROM\s+anon,\s*authenticated"

        if ($hasBlanketRevoke) {
            $hasRevokeAnon = $true
            $hasRevokeAuth = $true
        }

        if (-not $hasRLS) {
            Write-Host "FAIL: missing ENABLE ROW LEVEL SECURITY — file=$($file.Name) table=$table"
            $fail = $true
        }
        if (-not $hasRevokeAnon) {
            Write-Host "FAIL: missing REVOKE ALL FROM anon — file=$($file.Name) table=$table"
            $fail = $true
        }
        if (-not $hasRevokeAuth) {
            Write-Host "FAIL: missing REVOKE ALL FROM authenticated — file=$($file.Name) table=$table"
            $fail = $true
        }

        if ($hasRLS -and $hasRevokeAnon -and $hasRevokeAuth) {
            Write-Host "PASS: $($file.Name) table=$table — RLS + REVOKE anon + REVOKE authenticated"
        }
    }
}

if ($fail) { Write-Host "STATUS: FAIL"; exit 1 }
Write-Host "STATUS: PASS"
exit 0