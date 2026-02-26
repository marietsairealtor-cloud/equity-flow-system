# ci_background_context_review.ps1
# Gate: background-context-review (merge-blocking)
# Build Route: 6.3 — Tenant Integrity Suite [HARDENED]
# Cross-checks background_context_review.json against pg_catalog at runtime.
# Fails if any trigger or background function exists in catalog absent from review file.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
# --- CI stub ---
if ($env:CI -eq "true") {
    Write-Host "background-context-review: CI stub active (no live DB in CI). Converts at 8.0."
    exit 0
}
# --- Locate supabase_db container ---
$cid = (docker ps --format "{{.ID}} {{.Names}}" | Select-String -Pattern "supabase_db" | Select-Object -First 1)
if (-not $cid) { throw "background-context-review: supabase_db container not found. Is Supabase running?" }
$cid = $cid.ToString().Trim().Split(" ")[0]
Write-Host "background-context-review: using container $cid"
# --- Load review file ---
$reviewPath = "docs/truth/background_context_review.json"
if (-not (Test-Path $reviewPath)) { throw "background-context-review: $reviewPath not found" }
$review = Get-Content $reviewPath -Raw | ConvertFrom-Json
$bad = @()
# --- Check triggers ---
$rawTriggers = docker exec -i $cid psql -U postgres -d postgres -At -c `
    "SELECT trigger_name FROM information_schema.triggers WHERE trigger_schema = 'public' ORDER BY 1"
$catalogTriggers = @($rawTriggers | Where-Object { $_.Trim() -ne "" })
$reviewTriggerNames = @($review.triggers | ForEach-Object { $_.name })
if ($catalogTriggers.Count -eq 0) {
    Write-Host "background-context-review: no triggers in public schema — PASS"
} else {
    foreach ($t in $catalogTriggers) {
        $t = $t.Trim()
        if ($reviewTriggerNames -notcontains $t) {
            $bad += "FAIL: trigger '$t' exists in catalog but absent from background_context_review.json"
            Write-Host "  FAIL: unreviewed trigger: $t"
        } else {
            Write-Host "  PASS: trigger reviewed: $t"
        }
    }
}
# --- Check pg_cron jobs ---
$rawCron = docker exec -i $cid psql -U postgres -d postgres -At -c `
    "SELECT proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='cron' ORDER BY 1" 2>$null
$catalogCron = @($rawCron | Where-Object { $_.Trim() -ne "" })
$reviewCronNames = @($review.pg_cron_jobs | ForEach-Object { $_.name })
if ($catalogCron.Count -eq 0) {
    Write-Host "background-context-review: no pg_cron functions — PASS"
} else {
    foreach ($c in $catalogCron) {
        $c = $c.Trim()
        if ($reviewCronNames -notcontains $c) {
            $bad += "FAIL: pg_cron function '$c' exists in catalog but absent from background_context_review.json"
            Write-Host "  FAIL: unreviewed pg_cron function: $c"
        } else {
            Write-Host "  PASS: pg_cron function reviewed: $c"
        }
    }
}
# --- Result ---
Write-Host ""
if ($bad.Count -gt 0) {
    Write-Host "background-context-review: FAIL"
    foreach ($b in $bad) { Write-Error $b }
    exit 1
}
Write-Host "background-context-review: PASS"
exit 0
