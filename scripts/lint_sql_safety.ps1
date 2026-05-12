$paths=@("supabase/migrations","supabase/tests"); $bad=@() 
Get-ChildItem $paths -Recurse -File -Filter *.sql -ErrorAction SilentlyContinue | %{
  $b=[IO.File]::ReadAllBytes($_.FullName)
  if($b.Length-ge 3 -and $b[0]-eq 0xEF -and $b[1]-eq 0xBB -and $b[2]-eq 0xBF){$bad+=("$($_.FullName) : BOM")}
  if($b.Length-ge 2 -and (($b[0]-eq 0xFF -and $b[1]-eq 0xFE) -or ($b[0]-eq 0xFE -and $b[1]-eq 0xFF))){$bad+=("$($_.FullName) : UTF-16")}
  $t=[Text.Encoding]::UTF8.GetString($b)
  if($t -match '\$\$(?![a-zA-Z_])'){ $bad+=("$($_.FullName) : contains DOLLAR_DOLLAR") }

  # Strip SQL comments and single-quoted string literals before dynamic-SQL detection
  $stripped = $t -replace '(?m)--[^\r\n]*', ''
  $stripped = $stripped -replace '(?s)/\*.*?\*/', ''
  $stripped = $stripped -replace "'(?:''|[^'])*'", ''

  # Comments only (keep string literals) — used to tell safe printf-style format() from dynamic-SQL templates
  $tSqlComments = $t -replace '(?m)--[^\r\n]*', ''
  $tSqlComments = $tSqlComments -replace '(?s)/\*.*?\*/', ''

  $definer = $stripped -match '(?is)security\s+definer'
  $badExecute = (($stripped -match '(?is)\bexecute\b') -and
    ($stripped -notmatch '(?is)\b(grant|revoke)\s+execute\s+on\s+(function|procedure)\b') -and
    ($stripped -notmatch '(?is)\bcreate\s+trigger\b.*\bexecute\s+function\b'))
  # Under SECURITY DEFINER, only flag format( when the first argument is not a literal template (e.g. not format('...', args))
  $dangerousFormat = $false
  if ($definer -and ($tSqlComments -match '(?is)\bformat\s*\(')) {
    # Safe: format( optional_ws 'template' , ...). Flag when first arg is not a literal string template.
    if ($tSqlComments -match "(?is)\bformat\s*\((?!\s*')") { $dangerousFormat = $true }
  }

  if ($definer -and ($badExecute -or $dangerousFormat)) {
    $bad+=("$($_.FullName) : SECURITY DEFINER dynamic SQL (EXECUTE/format)")
  }
}
if($bad.Count){ $bad | %{"LINT_SQL_SAFETY FAIL: $_"}; exit 1 } else { "LINT_SQL_SAFETY OK" }