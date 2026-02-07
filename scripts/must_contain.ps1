param(
  [string]$SchemaPath = "generated/schema.sql"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $SchemaPath)) { throw "Missing $SchemaPath. Run scripts/gen_schema.ps1 first." }

$txt = Get-Content $SchemaPath -Raw
$txt = $txt -replace "`r`n","`n"

function Require([string]$name, [string]$pattern) {
  if ($txt -notmatch $pattern) {
    Write-Error "MUST-CONTAIN FAILED: $name"
    exit 1
  }
}

function Get-CreateTableBlock([string]$tableName) {
  $pattern = "(?is)\bcreate\s+table\b[^\n]*\b$tableName\b.*?\)\s*;"
  $m = [regex]::Match($txt, $pattern)
  if (-not $m.Success) { return $null }
  return $m.Value
}

function RequireIn([string]$name, [string]$block, [string]$pattern) {
  if ([string]::IsNullOrWhiteSpace($block)) {
    Write-Error "MUST-CONTAIN FAILED: $name (missing block)"
    exit 1
  }
  if ($block -notmatch $pattern) {
    Write-Error "MUST-CONTAIN FAILED: $name"
    exit 1
  }
}

# Base tables (match CREATE TABLE line containing the table name)
Require "public.tenants table"            "(?im)^\s*create\s+table\b[^\n]*\btenants\b"
Require "public.tenant_memberships table" "(?im)^\s*create\s+table\b[^\n]*\btenant_memberships\b"
Require "public.user_profiles table"      "(?im)^\s*create\s+table\b[^\n]*\buser_profiles\b"
Require "public.deals table"              "(?im)^\s*create\s+table\b[^\n]*\bdeals\b"

# Invariants: validate inside the CREATE TABLE deals block only
$deals = Get-CreateTableBlock "deals"
RequireIn "deals.tenant_id NOT NULL" $deals "(?is)\btenant_id\b[^\n]*\buuid\b[^\n]*\bnot\s+null\b"
RequireIn "deals.row_version"        $deals "(?is)\brow_version\b[^\n]*\bbigint\b"
RequireIn "deals.calc_version"       $deals "(?is)\bcalc_version\b[^\n]*\binteger\b"

# RLS enabled (pg_dump often includes ONLY)
Require "RLS enabled on tenants"     "(?im)^\s*alter\s+table\s+(only\s+)?[^\n]*\btenants\b[^\n]*\benable\s+row\s+level\s+security\b"
Require "RLS enabled on deals"       "(?im)^\s*alter\s+table\s+(only\s+)?[^\n]*\bdeals\b[^\n]*\benable\s+row\s+level\s+security\b"

Write-Host "MUST-CONTAIN OK"