$ErrorActionPreference = "Stop"

$path = "docs/artifacts/CONTRACTS.md"
if (-not (Test-Path $path)) { throw "Missing $path" }

$txt = Get-Content $path -Raw
$txt = $txt -replace "`r`n","`n"

function Fail([string]$msg) { Write-Error "CONTRACTS LINT FAILED: $msg"; exit 1 }
function Require([string]$name, [string]$pattern) { if ($txt -notmatch $pattern) { Fail $name } }

# Envelope keys
Require "Envelope: ok"    '(?s)"ok"\s*:'
Require "Envelope: code"  '(?s)"code"\s*:'
Require "Envelope: data"  '(?s)"data"\s*:'
Require "Envelope: error" '(?s)"error"\s*:'

# Pagination contract (must include ordering + cursor + limits + next_cursor)
Require "Pagination: rpc.list_deals_v1" '(?im)^\s*rpc\.list_deals_v1\('
Require "Pagination: ordering created_at desc, id desc" '(?is)ordering:\s*created_at\s+desc,\s*id\s+desc'
Require "Pagination: limit default 25, max 100" '(?is)limit:\s*default\s*25,\s*max\s*100'
Require "Pagination: cursor opaque" '(?is)cursor:\s*opaque'
Require "Pagination: next_cursor" '(?is)next_cursor'

# UI globals list (<= 4, exact allowlist)
$allowed = @("gs_selectedTenantId","gs_selectedDealId","gs_maoDraft","gs_pendingIdempotencyKey")

$sec = [regex]::Match($txt, "(?s)##\s*2\)\s*UI State Contract.*?Allowed WeWeb globals:\s*(.*?)\n\s*Forbidden:", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
if (-not $sec.Success) { Fail "UI globals section not found or malformed" }

$lines = $sec.Groups[1].Value -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^- ' }
$globals = $lines | ForEach-Object { ($_ -replace '^- ','') } | ForEach-Object { ($_ -split '\s')[0].Trim() } | Where-Object { $_ -ne "" }

if ($globals.Count -gt 4) { Fail "UI globals > 4 (found $($globals.Count))" }

$missing = $allowed | Where-Object { $globals -notcontains $_ }
$extra   = $globals  | Where-Object { $allowed -notcontains $_ }

if ($missing.Count -gt 0) { Fail "Missing allowed globals: $($missing -join ', ')" }
if ($extra.Count -gt 0)   { Fail "Unexpected globals: $($extra -join ', ')" }

Write-Host "CONTRACTS LINT OK"