# ci_unregistered_table_access.ps1
# Gate: unregistered-table-access (merge-blocking)
# Build Route: 6.3A — Unregistered Table Access Gate
# Fails if any table in public schema accessible to authenticated
# is absent from docs/truth/tenant_table_selector.json.
# Authority: Build Route v2.4 §6.3A, CONTRACTS.md §12
# In CI without live DB: stub exit per deferred_proofs.json (converts at 8.0).

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== unregistered-table-access gate ==="

# --- CI stub ---
if ($env:CI -eq "true") {
    Write-Host "unregistered-table-access: CI stub active (no live DB in CI). Registered in deferred_proofs.json. Converts at 8.0."
    exit 0
}

# --- Locate supabase_db container ---
$cid = (docker ps --format "{{.ID}} {{.Names}}" | Select-String -Pattern "supabase_db" | Select-Object -First 1)
if (-not $cid) { throw "unregistered-table-access: supabase_db container not found. Is Supabase running?" }
$cid = $cid.ToString().Trim().Split(" ")[0]

Write-Host "unregistered-table-access: using container $cid"

# --- Load tenant_table_selector.json ---
$selectorPath = "docs/truth/tenant_table_selector.json"
if (-not (Test-Path $selectorPath)) { throw "unregistered-table-access: $selectorPath not found" }
$selectorRaw = Get-Content $selectorPath -Raw | ConvertFrom-Json

# Extract registered table names from selector
# Support both formats: array of table names or object with tables key
$registeredTables = @()
if ($selectorRaw.PSObject.Properties.Name -contains "tables") {
    $registeredTables = @($selectorRaw.tables)
} elseif ($selectorRaw.PSObject.Properties.Name -contains "selector") {
    # Current format has no explicit table list — all tenant-scoped tables are implicit
    # We need to check if there is a separate table list property
}

if ($selectorRaw.PSObject.Properties.Name -contains "tenant_tables") {
    $registeredTables = @($selectorRaw.tenant_tables)
}

if ($registeredTables.Count -eq 0) {
    Write-Host "unregistered-table-access: WARNING — no tables registered in $selectorPath"
    Write-Host "unregistered-table-access: will flag ALL accessible tables as unregistered"
}

Write-Host "unregistered-table-access: registered tables = [$($registeredTables -join ', ')]"

# --- Query: all tables in public where authenticated has any privilege ---
$query = @"
SELECT table_name, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee = 'authenticated'
  AND privilege_type IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
ORDER BY table_name, privilege_type
"@

$rows = docker exec -i $cid psql -U postgres -d postgres -At -F "`t" -c $query

$fail = $false
$checked = @{}

foreach ($row in $rows) {
    if (-not $row -or -not $row.Trim()) { continue }
    $parts = $row -split "`t"
    if ($parts.Count -lt 2) { continue }
    $tbl  = $parts[0].Trim()
    $priv = $parts[1].Trim()

    if ($registeredTables -contains $tbl) {
        if (-not $checked.ContainsKey($tbl)) {
            Write-Host "PASS: $tbl is registered in tenant_table_selector.json (privilege: $priv)"
            $checked[$tbl] = $true
        }
        continue
    }

    Write-Host "FAIL: authenticated has $priv on public.$tbl — table absent from tenant_table_selector.json"
    $fail = $true
}

# --- Default ACL check: would new tables auto-grant to authenticated? ---
Write-Host ""
Write-Host "--- Default ACL check (future table exposure) ---"
$aclQuery = @"
SELECT r.rolname, a.defaclobjtype, a.defaclacl::text
FROM pg_default_acl a
JOIN pg_roles r ON r.oid = a.defaclrole
LEFT JOIN pg_namespace n ON n.oid = a.defaclnamespace
WHERE (n.nspname = 'public' OR a.defaclnamespace = 0)
  AND r.rolname NOT LIKE 'supabase_%'
"@

$aclRows = docker exec -i $cid psql -U postgres -d postgres -At -F "`t" -c $aclQuery

foreach ($row in $aclRows) {
    if (-not $row -or -not $row.Trim()) { continue }
    $parts = $row -split "`t"
    if ($parts.Count -lt 3) { continue }
    $rolname = $parts[0].Trim()
    $objtype = $parts[1].Trim()
    $acl     = $parts[2].Trim()

    if ($acl -match "authenticated=") {
        Write-Host "FAIL: default ACL for role=$rolname type=$objtype grants to authenticated — acl=$acl"
        Write-Host "      New tables created by $rolname would auto-grant to authenticated without revocation"
        $fail = $true
    }
}

if (-not $fail) {
    Write-Host ""
    Write-Host "PASS: default ACL clean — no auto-grant to authenticated"
}

# --- Result ---
Write-Host ""
if ($fail) {
    Write-Host "unregistered-table-access: FAIL"
    Write-Host "Fix: add missing tables to docs/truth/tenant_table_selector.json or revoke the privilege."
    exit 1
} else {
    Write-Host "unregistered-table-access: PASS"
    exit 0
}
