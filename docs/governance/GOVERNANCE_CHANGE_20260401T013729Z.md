What changed
Extended lint_sql_safety.ps1 to strip single-quoted string literals
before EXECUTE pattern detection. Fixes false-positive on
has_function_privilege(...,'EXECUTE') calls in pgTAP test files.

Why safe
Detection logic is additive only. Stripping string literals before
checking for dynamic SQL makes the gate more precise -- it was
catching legitimate privilege-check strings, not actual dynamic SQL.
No security surface weakened.

Risk
None. Gate becomes more accurate, not less strict.

Rollback
Revert the single -replace line added to lint_sql_safety.ps1.