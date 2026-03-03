$ErrorActionPreference = "Stop"
Write-Host "=== qa-scope-coverage gate ==="
$manifestPath = "docs/proofs/manifest.json"
$scopeMapPath = "docs/truth/qa_scope_map.json"
if (-not (Test-Path $manifestPath)) { Write-Error "MISSING: $manifestPath"; exit 1 }
if (-not (Test-Path $scopeMapPath))  { Write-Error "MISSING: $scopeMapPath"; exit 1 }

# Derive completed items from canonical proof logs in manifest
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$files = $manifest.files | Get-Member -MemberType NoteProperty | ForEach-Object { $_.Name }

$completedSet = @{}
foreach ($f in $files) {
    # Strip path prefix (including _archive/)
    $name = $f -replace '^docs/proofs/(_archive/)?', ''
    # Extract Build Route item ID: greedy match of digits, dots, and trailing uppercase letter
    # Stop at first underscore followed by a lowercase letter (the description segment)
    if ($name -match '^([\d]+(?:\.[\d]+)*[A-Z]?)_(?=[a-z])') {
        $id = $Matches[1]
        $completedSet[$id] = $true
    }
}

$completed = @($completedSet.Keys | Sort-Object)
$scopeMap = (Get-Content $scopeMapPath -Raw | ConvertFrom-Json).items

Write-Host "Completed items (derived from manifest): $($completed.Count)"
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

Write-Host "Derived IDs ($($completed.Count)):"
foreach ($c in $completed) { Write-Host "  $c" }
Write-Host "All completed items have qa_scope_map.json entries."
Write-Host "STATUS: PASS"
exit 0
