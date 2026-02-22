$ErrorActionPreference = "Stop"

Write-Host "=== cloud-version-pin gate (lane-only) ==="

$toolchainPath = "docs/truth/toolchain.json"
if (-not (Test-Path $toolchainPath)) { Write-Error "MISSING: $toolchainPath"; exit 1 }

$toolchain = Get-Content $toolchainPath -Raw | ConvertFrom-Json

$url = $env:SUPABASE_URL
$key = $env:SUPABASE_ANON_KEY

if (-not $url -or -not $key) {
    Write-Host "CLOUD_VERSION_PIN_SKIP: SUPABASE_URL or SUPABASE_ANON_KEY not set — cloud lane only"
    exit 0
}

# Fetch PostgREST version from OpenAPI response
Write-Host "Fetching PostgREST version from $url/rest/v1/"
$r = Invoke-WebRequest -Uri "$url/rest/v1/" -Headers @{"apikey"=$key; "Accept"="application/json"} -Method Get
$openapi = [System.Text.Encoding]::UTF8.GetString($r.Content) | ConvertFrom-Json
$foundPostgrest = $openapi.info.version
Write-Host "PostgREST version found: $foundPostgrest"

# Fetch Auth version from /auth/v1/health
Write-Host "Fetching Auth version from $url/auth/v1/health"
$a = Invoke-WebRequest -Uri "$url/auth/v1/health" -Headers @{"apikey"=$key} -Method Get
$authJson = $a.Content | ConvertFrom-Json
$foundAuth = $authJson.version
Write-Host "Auth version found: $foundAuth"

# Assert against pinned truth
$expectedPostgrest = $toolchain.postgrest_version.expect
$expectedAuth = $toolchain.supabase_auth_version.expect

$fail = $false

if ($foundPostgrest -ne $expectedPostgrest) {
    Write-Host "FAIL: PostgREST version mismatch — expected=$expectedPostgrest found=$foundPostgrest"
    $fail = $true
} else {
    Write-Host "PASS: PostgREST version=$foundPostgrest"
}

if ($foundAuth -ne $expectedAuth) {
    Write-Host "FAIL: Auth version mismatch — expected=$expectedAuth found=$foundAuth"
    $fail = $true
} else {
    Write-Host "PASS: Auth version=$foundAuth"
}

if ($fail) { Write-Host "STATUS: FAIL"; exit 1 }

Write-Host "STATUS: PASS"
exit 0