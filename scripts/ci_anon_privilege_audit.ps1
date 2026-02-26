$ErrorActionPreference = "Stop"

Write-Host "=== anon-privilege-audit gate ==="

$dbUrl = $env:DATABASE_URL
if (-not $dbUrl) {
    Write-Host "ANON_PRIVILEGE_AUDIT_SKIP: DATABASE_URL not set — DB/runtime lane only"
    exit 0
}

$psql = "psql"
if ($IsWindows) { $psql = "C:\Program Files\PostgreSQL\16\bin\psql.exe" }

function Invoke-Psql([string]$sql) {
    $result = & $psql -v ON_ERROR_STOP=1 -At -F "`t" -c $sql $dbUrl 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Error "psql failed: $result"; exit 1 }
    return $result
}

$fail = $false

# --- A: Direct grant check ---
Write-Host "A: Direct grant check..."
$grantSql = "SELECT grantee, table_name, privilege_type FROM information_schema.role_table_grants WHERE table_schema = 'public' AND grantee IN ('anon', 'authenticated') ORDER BY grantee, table_name, privilege_type;"
$grantRows = Invoke-Psql $grantSql

$authUserProfilePrivs = @()
foreach ($row in $grantRows) {
    if (-not $row.Trim()) { continue }
    $parts = $row -split "`t"
    if ($parts.Count -lt 3) { continue }
    $role = $parts[0].Trim()
    $tbl  = $parts[1].Trim()
    $priv = $parts[2].Trim()

    if ($role -eq "authenticated" -and $tbl -eq "user_profiles" -and $priv -in @("SELECT","UPDATE")) {
        $authUserProfilePrivs += $priv
        continue
    }
    Write-Host "FAIL: $role has $priv on public.$tbl — source=direct grant — CONTRACTS.md §12"
    $fail = $true
}

# Assert authenticated has EXACTLY SELECT+UPDATE on user_profiles
$expected = @("SELECT","UPDATE") | Sort-Object
$found = $authUserProfilePrivs | Sort-Object
if (($found -join ",") -ne ($expected -join ",")) {
    Write-Host "FAIL: authenticated does not have exactly SELECT+UPDATE on user_profiles — found: $($found -join ',') — CONTRACTS.md §12"
    $fail = $true
} else {
    Write-Host "PASS: authenticated has exactly SELECT+UPDATE on user_profiles"
}

# --- B: Operator-owned default ACL check ---
Write-Host "B: Operator-owned default ACL check..."
$aclSql = "SELECT r.rolname, a.defaclobjtype, a.defaclacl::text FROM pg_default_acl a JOIN pg_roles r ON r.oid = a.defaclrole LEFT JOIN pg_namespace n ON n.oid = a.defaclnamespace WHERE (n.nspname = 'public' OR a.defaclnamespace = 0) AND r.rolname NOT LIKE 'supabase_%';"
$aclRows = Invoke-Psql $aclSql

$aclClean = $true
foreach ($row in $aclRows) {
    if (-not $row.Trim()) { continue }
    $parts = $row -split "`t"
    if ($parts.Count -lt 3) { continue }
    $rolname = $parts[0].Trim()
    $objtype = $parts[1].Trim()
    $acl     = $parts[2].Trim()
    if ($acl -match "anon=" -or $acl -match "authenticated=") {
        Write-Host "FAIL: operator default ACL contains anon/authenticated — role=$rolname type=$objtype acl=$acl — CONTRACTS.md §13"
        $fail = $true
        $aclClean = $false
    }
}
if ($aclClean) { Write-Host "PASS: operator-owned default ACL clean" }

# --- B2: Sequences check ---
Write-Host "B2: Sequence usage grants check..."
$seqSql = "SELECT grantee, object_name, privilege_type FROM information_schema.role_usage_grants WHERE object_schema = 'public' AND grantee IN ('anon', 'authenticated');"
$seqRows = Invoke-Psql $seqSql
foreach ($row in $seqRows) {
    if (-not $row.Trim()) { continue }
    $parts = $row -split "`t"
    if ($parts.Count -lt 3) { continue }
    Write-Host "FAIL: $($parts[0]) has $($parts[2]) on sequence $($parts[1]) — CONTRACTS.md §12"
    $fail = $true
}
if (-not $fail) { Write-Host "PASS: anon/authenticated have zero sequence grants" }

# --- B3: Functions check (allowlist-aware) ---
Write-Host "B3: Routine grants check..."
$allowlistPath = "docs/truth/execute_allowlist.json"
$allowedRoutines = @()
if (Test-Path $allowlistPath) {
    $al = Get-Content $allowlistPath -Raw | ConvertFrom-Json
    $allowedRoutines = @($al.allow)
}
$fnSql = "SELECT grantee, routine_name, privilege_type FROM information_schema.role_routine_grants WHERE routine_schema = 'public' AND grantee IN ('anon', 'authenticated');"
$fnRows = Invoke-Psql $fnSql
foreach ($row in $fnRows) {
    if (-not $row.Trim()) { continue }
    $parts = $row -split "`t"
    if ($parts.Count -lt 3) { continue }
    $rName = $parts[1].Trim()
    if ($allowedRoutines -contains $rName) {
        Write-Host "PASS: $($parts[0]) has $($parts[2]) on routine $rName — allowlisted"
    } else {
        Write-Host "FAIL: $($parts[0]) has $($parts[2]) on routine $rName — CONTRACTS.md §12"
        $fail = $true
    }
}
if (-not $fail) { Write-Host "PASS: anon/authenticated routine grants clean (allowlist-checked)" }


# --- C: Platform ACL visibility (logged, not enforced) ---
Write-Host "C: Platform default ACL (supabase_% — logged only)..."
$platSql = "SELECT r.rolname, a.defaclobjtype, a.defaclacl::text FROM pg_default_acl a JOIN pg_roles r ON r.oid = a.defaclrole LEFT JOIN pg_namespace n ON n.oid = a.defaclnamespace WHERE (n.nspname = 'public' OR a.defaclnamespace = 0) AND r.rolname LIKE 'supabase_%';"
$platRows = Invoke-Psql $platSql
foreach ($row in $platRows) {
    if ($row.Trim()) { Write-Host "PLATFORM_ACL (not enforced): $row" }
}

if ($fail) { Write-Host "STATUS: FAIL"; exit 1 }
Write-Host "STATUS: PASS"
exit 0
