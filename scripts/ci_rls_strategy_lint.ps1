$ErrorActionPreference = "Stop"

Write-Host "=== rls-strategy-consistent gate ==="

$migrationsPath = "supabase/migrations"
if (-not (Test-Path $migrationsPath)) { Write-Error "MISSING: $migrationsPath"; exit 1 }

$files = Get-ChildItem $migrationsPath -Filter "*.sql" | Sort-Object Name
Write-Host "Scanning $($files.Count) migration file(s)..."

$fail = $false

foreach ($file in $files) {
    $lines = Get-Content $file.FullName
    $inPolicy = $false
    $policyName = ""

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNum = $i + 1

        # Detect policy start
        if ($line -match "CREATE\s+POLICY\s+[`"']?(\w+)[`"']?") {
            $inPolicy = $true
            $policyName = $Matches[1]
        }

        # Only check inside policy bodies
        if ($inPolicy) {
            # Pattern 1: raw auth.uid() used directly for tenant resolution
            if ($line -match "\bauth\.uid\(\)") {
                Write-Host "FAIL: forbidden pattern 'raw auth.uid()' — file=$($file.Name) policy=$policyName line=$lineNum — CONTRACTS.md §3"
                $fail = $true
            }

            # Pattern 2: raw auth.jwt() used directly for tenant resolution
            if ($line -match "\bauth\.jwt\(\)") {
                Write-Host "FAIL: forbidden pattern 'raw auth.jwt()' — file=$($file.Name) policy=$policyName line=$lineNum — CONTRACTS.md §3"
                $fail = $true
            }

            # Pattern 3: inline JWT claim parsing for tenant ID
            if ($line -match "auth\.jwt\(\)\s*->>\s*['""]?[a-zA-Z_]*tenant[a-zA-Z_]*['""]?" -or
                $line -match "auth\.jwt\(\)\s*->\s*['""]?[a-zA-Z_]*tenant[a-zA-Z_]*['""]?") {
                Write-Host "FAIL: forbidden pattern 'inline JWT claim parsing for tenant ID' — file=$($file.Name) policy=$policyName line=$lineNum — CONTRACTS.md §3"
                $fail = $true
            }

            # Detect policy end (semicolon on its own or after WITH CHECK)
            if ($line -match ";\s*$") {
                $inPolicy = $false
                $policyName = ""
            }
        }
    }
}

if ($fail) { Write-Host "STATUS: FAIL"; exit 1 }
Write-Host "No forbidden tenant resolution patterns found."
Write-Host "STATUS: PASS"
exit 0