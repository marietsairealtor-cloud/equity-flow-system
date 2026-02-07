$paths=@("supabase/migrations","supabase/tests"); $bad=@()
Get-ChildItem $paths -Recurse -File -Filter *.sql -ErrorAction SilentlyContinue | %{
  $b=[IO.File]::ReadAllBytes($_.FullName)
  if($b.Length-ge 3 -and $b[0]-eq 0xEF -and $b[1]-eq 0xBB -and $b[2]-eq 0xBF){$bad+=("$($_.FullName) : BOM")}
  if($b.Length-ge 2 -and (($b[0]-eq 0xFF -and $b[1]-eq 0xFE) -or ($b[0]-eq 0xFE -and $b[1]-eq 0xFF))){$bad+=("$($_.FullName) : UTF-16")}
  $t=[Text.Encoding]::UTF8.GetString($b)
  if($t -match '\$\$'){ $bad+=("$($_.FullName) : contains DOLLAR_DOLLAR") }
  if(($t -match '(?is)security\s+definer') -and (
       ($t -match '(?is)\bexecute\b(?!\s+function\b)\s+(''|[a-zA-Z_])') -or
       ($t -match '(?is)\bformat\s*\(')
     )){ $bad+=("$($_.FullName) : SECURITY DEFINER dynamic SQL (EXECUTE/format)") }
}
if($bad.Count){ $bad | %{"LINT_SQL_SAFETY FAIL: $_"}; exit 1 } else { "LINT_SQL_SAFETY OK" }
