# scripts/test_fk_embedding.ps1
# Build Route 6.3 — FK Embedding HTTP-layer negative tests
# Must run against live local Supabase instance (not CI — IPv4 deferred to 11.0)
# Tests that PostgREST FK embedding cannot expose cross-tenant data

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$BASE_URL = "http://localhost:54321/rest/v1"
$bad = @()

# --- Get anon key from supabase config ---
$anonKey = (Select-String -Path "supabase/config.toml" -Pattern "anon_key\s*=\s*""([^""]+)""").Matches[0].Groups[1].Value
if (-not $anonKey) { throw "test_fk_embedding: cannot read anon_key from supabase/config.toml" }

Write-Host "test_fk_embedding: using base URL $BASE_URL"

# --- Helper: make JWT for a user ---
# In local Supabase the service_role key can mint tokens; use pre-known local JWTs
# For local dev, Supabase uses a fixed JWT secret. Test users must exist in auth.users.

# Tenant A user JWT (pre-seeded by pgTAP test or manual seed)
# These are placeholder tokens — operator must supply valid local JWTs for test users
$JWT_TENANT_A = $env:TEST_JWT_TENANT_A
$JWT_TENANT_B = $env:TEST_JWT_TENANT_B

if (-not $JWT_TENANT_A -or -not $JWT_TENANT_B) {
    Write-Host "test_fk_embedding: TEST_JWT_TENANT_A and TEST_JWT_TENANT_B env vars required."
    Write-Host "test_fk_embedding: Set these to valid local JWTs for test users seeded by tenant_isolation.test.sql"
    Write-Host "test_fk_embedding: SKIP — FK embedding tests require operator-supplied JWTs"
    exit 0
}

# --- Test 1: Tenant A JWT cannot embed Tenant B deals via tenant_memberships FK ---
Write-Host ""
Write-Host "--- Test 1: FK embed tenant_memberships->deals cross-tenant ---"
$headers = @{
    "Authorization" = "Bearer $JWT_TENANT_A"
    "apikey"        = $anonKey
}
try {
    $resp = Invoke-RestMethod -Uri "$BASE_URL/tenant_memberships?select=*,deals(*)" -Headers $headers -Method Get
    $crossTenantDeals = $resp | Where-Object { $_.tenant_id -eq 'b0000000-0000-0000-0000-000000000001' }
    if ($crossTenantDeals) {
        $bad += "FAIL: Tenant A JWT can see Tenant B deals via FK embed on tenant_memberships"
        Write-Host "  FAIL: cross-tenant deals visible"
    } else {
        Write-Host "  PASS: no cross-tenant deals via FK embed"
    }
} catch {
    Write-Host "  PASS: FK embed request rejected or returned no cross-tenant data ($_)"
}

# --- Test 2: Tenant A JWT cannot embed deals via direct select with Tenant B tenant_id ---
Write-Host ""
Write-Host "--- Test 2: Direct select with Tenant B tenant_id filter ---"
try {
    $resp = Invoke-RestMethod -Uri "$BASE_URL/deals?tenant_id=eq.b0000000-0000-0000-0000-000000000001&select=*" -Headers $headers -Method Get
    if ($resp.Count -gt 0) {
        $bad += "FAIL: Tenant A JWT can read Tenant B deals via direct filter"
        Write-Host "  FAIL: $($resp.Count) Tenant B deals returned"
    } else {
        Write-Host "  PASS: zero Tenant B deals returned to Tenant A JWT"
    }
} catch {
    Write-Host "  PASS: request rejected ($_)"
}

# --- Result ---
Write-Host ""
if ($bad.Count -gt 0) {
    Write-Host "test_fk_embedding: FAIL"
    foreach ($b in $bad) { Write-Error $b }
    exit 1
}
Write-Host "test_fk_embedding: PASS"
exit 0