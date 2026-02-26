# ci_definer_safety_audit.ps1
# Gate: definer-safety-audit (merge-blocking)
# Build Route: 6.2 — SECURITY DEFINER Safety [HARDENED]
# Scope: public and rpc schemas only. System schemas excluded.
# In CI without live DB: stub exit per deferred_proofs.json (converts at 8.0.4).

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- CI stub ---
if ($env:CI -eq "true") {
    Write-Host "definer-safety-audit: CI stub active (no live DB in CI). Registered in deferred_proofs.json. Converts at 8.0.4."
    exit 0
}

# --- Locate supabase_db container ---
$cid = (docker ps --format "{{.ID}} {{.Names}}" | Select-String -Pattern "supabase_db" | Select-Object -First 1)
if (-not $cid) { throw "definer-safety-audit: supabase_db container not found. Is Supabase running?" }
$cid = $cid.ToString().Trim().Split(" ")[0]

Write-Host "definer-safety-audit: using container $cid"

# --- Load allowlist ---
$allowlistPath = "docs/truth/definer_allowlist.json"
if (-not (Test-Path $allowlistPath)) { throw "definer-safety-audit: $allowlistPath not found" }
$allowlist = (Get-Content $allowlistPath -Raw | ConvertFrom-Json).allow
Write-Host "definer-safety-audit: allowlist has $($allowlist.Count) entries"

# --- Query all SD functions in public + rpc schemas ---
$query = @"
SELECT
    n.nspname || '.' || p.proname AS fname,
    coalesce(array_to_string(p.proconfig, ','), '') AS cfg,
    pg_get_functiondef(p.oid) AS src
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.prosecdef = true
  AND n.nspname IN ('public', 'rpc')
ORDER BY 1
"@

$rows = docker exec -i $cid psql -U postgres -d postgres -At -F "`t" -c $query
$bad = @()

if ($rows -and $rows.Trim() -ne "") {
    foreach ($row in $rows) {
        $parts = $row -split "`t", 3
        if ($parts.Count -lt 3) { continue }
        $fname = $parts[0].Trim()
        $cfg   = $parts[1].Trim()
        $src   = $parts[2].Trim()

        Write-Host ""
        Write-Host "--- Checking: $fname ---"

        # DoD 1: Must be on allowlist
        if ($allowlist -notcontains $fname) {
            $bad += "FAIL [$fname]: not on definer_allowlist.json — unallowlisted SD function"
            Write-Host "  FAIL: not on allowlist"
            continue
        }
        Write-Host "  allowlist: PASS"

        # DoD 4 (Hardened): proconfig must contain search_path entry
        if ($cfg -notmatch 'search_path=') {
            $bad += "FAIL [$fname]: pg_proc.proconfig missing search_path entry (found: '$cfg')"
            Write-Host "  proconfig search_path: FAIL (found: '$cfg')"
        } else {
            Write-Host "  proconfig search_path: PASS ($cfg)"
        }

        # DoD 2: No dynamic SQL in prosrc
        if ($src -match '\bEXECUTE\b' -or $src -match 'EXECUTE\s+format\s*\(') {
            $bad += "FAIL [$fname]: dynamic SQL detected in prosrc (EXECUTE or EXECUTE format)"
            Write-Host "  dynamic SQL: FAIL"
        } else {
            Write-Host "  dynamic SQL: PASS"
        }

        # DoD 2: Tenant membership check in prosrc
        if ($src -notmatch 'current_tenant_id\(\)') {
            $bad += "FAIL [$fname]: no current_tenant_id() call found in prosrc — tenant membership not enforced"
            Write-Host "  tenant membership: FAIL"
        } else {
            Write-Host "  tenant membership: PASS"
        }
    }
} else {
    Write-Host "definer-safety-audit: no SD functions found in public or rpc schemas."
}

# --- Allowlist entries with no matching DB function (drift detection) ---
if ($rows -and $rows.Trim() -ne "") {
    $found = $rows | ForEach-Object { ($_ -split "`t", 3)[0].Trim() }
    foreach ($entry in $allowlist) {
        if ($found -notcontains $entry) {
            $bad += "WARN [$entry]: on allowlist but not found in DB — stale allowlist entry"
            Write-Host "WARN: $entry on allowlist but absent from DB"
        }
    }
} elseif ($allowlist.Count -gt 0) {
    foreach ($entry in $allowlist) {
        $bad += "WARN [$entry]: on allowlist but no SD functions found in DB — stale allowlist entry"
        Write-Host "WARN: $entry on allowlist but no SD functions in DB"
    }
}

# --- Result ---
Write-Host ""
if ($bad.Count -gt 0) {
    Write-Host "definer-safety-audit: FAIL"
    foreach ($b in $bad) { Write-Error $b }
    exit 1
}

Write-Host "definer-safety-audit: PASS"
exit 0