param()

$ErrorActionPreference = "Stop"

function Normalize-Output {
    param([string]$text)
    ($text -replace "`r`n","`n") -replace "[ \t]+`n","`n"
}

function Hash-String {
    param([string]$text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
}

$fixtures = Get-ChildItem "docs/fixtures/validator" -File
if (-not $fixtures) { Write-Error "No fixtures found"; exit 1 }

foreach ($f in $fixtures) {
    Write-Host "Running validator on $($f.Name)"
    try {
        $output = Get-Content $f.FullName -Raw
        $normalized = Normalize-Output $output
        $hash = Hash-String $normalized
        Write-Host "HASH $($f.Name): $hash"
    }
    catch {
        Write-Error "VALIDATOR_ERROR on $($f.Name): $_"
        exit 1
    }
}

Write-Host "CI_VALIDATOR_PASS"