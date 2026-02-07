param(
  [string]$OutPath = "generated/schema.sql",
  [string]$Schemas = "public"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

New-Item -ItemType Directory -Force -Path (Split-Path $OutPath) | Out-Null

# Dump schema from local DB (Supabase CLI)
npx supabase db dump --local --schema $Schemas -f $OutPath

# Normalize + make deterministic (strip env-specific noise):
# - ALTER SCHEMA ... OWNER TO ...
# - COMMENT ON SCHEMA ...
$raw = Get-Content $OutPath -Raw
$raw = $raw -replace "`r`n","`n"

$lines = $raw -split "`n"
$filtered = foreach ($line in $lines) {
  if ($line -match '^\s*ALTER\s+SCHEMA\s+".+"\s+OWNER\s+TO\s+".+";\s*$') { continue }
  if ($line -match '^\s*COMMENT\s+ON\s+SCHEMA\s+".+"\s+IS\s+.+;\s*$') { continue }
  if ($line -match '^\s*GRANT\s+.*\s+TO\s+"postgres";\s*$') { continue }
  if ($line -match '^\s*GRANT\s+.*\s+TO\s+"service_role";\s*$') { continue }
  if ($line -match '^\s*ALTER\s+DEFAULT\s+PRIVILEGES\s+') { continue }
  # Privilege canonicalization (allowlist-only; deterministic across envs)
  $s = $line.Trim()
  if ($s -match '^\s*ALTER\s+DEFAULT\s+PRIVILEGES\s+') { continue }  # temporarily excluded until Feb 18 lockdown
  if ($s -match '^\s*(GRANT|REVOKE)\s+USAGE\s+ON\s+SCHEMA\s+"public"\s+') { continue }
  if ($s -match '^\s*(GRANT|REVOKE)\s+.*\s+TO\s+"(postgres|service_role)"\s*;\s*$') { continue }
  if ($s -match '^\s*(GRANT|REVOKE)\s+.*\s+ON\s+SEQUENCE\s+') { continue }
  if ($s -match '^\s*(GRANT|REVOKE)\s+.*\s+ON\s+TABLE\s+"public"\."(deals|tenants|tenant_memberships|user_profiles)"\s+.*\s+"(anon|authenticated)"\s*;\s*$') { $line; continue }
  if ($s -match '^\s*REVOKE\s+ALL\s+ON\s+FUNCTION\s+"public"\."(list_deals_v1|get_user_entitlements_v1|current_tenant_id|audit_row_v1|idempotency_replay_or_store_v1|rpc_ok|rpc_err)"') { $line; continue }
  if ($s -match '^\s*GRANT\s+ALL\s+ON\s+FUNCTION\s+"public"\."(list_deals_v1|get_user_entitlements_v1|current_tenant_id|audit_row_v1|idempotency_replay_or_store_v1|rpc_ok|rpc_err)"\s*\(.*\)\s+TO\s+"authenticated"\s*;\s*$') { $line; continue }
  if ($s -match '^\s*(GRANT|REVOKE)\s+.*\s+ON\s+TABLE\s+"public"\."(deals|tenants|tenant_memberships|tenant_invites|documents|user_profiles)"\s+.*\s+"(anon|authenticated)"\s*;\s*$') { $line; continue }
  if ($s -match '^\s*(GRANT|REVOKE)\s+') { continue }
  $line
}

$raw2 = ($filtered -join "`n").TrimEnd() + "`n"


# Whitespace canonicalization (deterministic across platforms)
# - trim trailing spaces
# - collapse 3+ blank lines -> 2
# - ensure exactly one trailing newline
$raw2 = ($raw2 -replace "[ \t]+`n","`n")
$raw2 = [regex]::Replace($raw2, "`n{3,}", "`n`n")
$raw2 = $raw2.TrimEnd() + "`n"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $repoRoot $OutPath), $raw2, $utf8NoBom)

Write-Host "Wrote $OutPath (schemas: $Schemas)"



