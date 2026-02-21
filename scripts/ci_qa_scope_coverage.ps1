$ErrorActionPreference = "Stop"

Write-Host "=== qa-scope-coverage gate ==="

$completedPath = "docs/truth/completed_items.json"
$scopeMapPath  = "docs/truth/qa_scope_map.json"

if (-not (Test-Path $completedPath)) { Write-Error "MISSING: $completedPath"; exit 1 }
if (-not (Test-Path $scopeMapPath))  { Write-Error "MISSING: $scopeMapPath"; exit 1 }

$completed = (Get-Content $completedPath -Raw | ConvertFrom-Json).completed
$scopeMap  = (Get-Content $scopeMapPath -Raw | ConvertFrom-Json).items

Write-Host "Completed items: $($completed.Count)"
Write-Host "Scope map entries: $(($scopeMap | Get-Member -MemberType NoteProperty).Count)"

# Check every completed item has a scope map entry
$fail = $false
$unmapped = @()
foreach ($item in $completed) {
    if (-not $scopeMap.$item) {
        $unmapped += $item
    }
}

if ($unmapped.Count -gt 0) {
    Write-Host "FAIL: completed items missing from qa_scope_map.json:"
    foreach ($m in $unmapped) { Write-Host "  - $m" }
    $fail = $true
}

if ($fail) {
    Write-Host "STATUS: FAIL — $($unmapped.Count) completed item(s) have no scope map entry"
    exit 1
}

Write-Host "All completed items have qa_scope_map.json entries."
Write-Host "STATUS: PASS"
exit 0