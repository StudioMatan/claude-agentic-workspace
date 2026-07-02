# AD PowerShell Patterns & Gotchas

Battle-tested patterns for bulk AD attribute pushes, plus the failure modes that produced them.

## Script Structure

Every AD push script follows this pattern:
1. Timestamp + input/log file paths (server paths under the push folder)
2. Input validation (`Test-Path`)
3. Log directory creation
4. CSV header written with `Out-File`
5. Counters: `$updatedCount`, `$skipCount`, `$notFoundCount`, `$failCount`
6. `foreach` loop over `Import-Csv` rows
7. Summary output + log path

## Comparison Logic (Critical)

Always compare BEFORE writing - otherwise the log claims "Updated" for identical values and the
audit trail is worthless. Use the null-safe trim pattern:

```powershell
if (("" + $adUser.Attribute).Trim() -eq ("" + $newValue).Trim()) {
    # Skip - no change
} else {
    Set-ADUser -Identity $sam -AttributeName $newValue
}
```

Why each part exists:
- **Null safety**: AD attributes can be `$null`; calling `.Trim()` on null throws. Prefixing
  with an empty string (`"" + $val`) makes it safe.
- **Case-insensitivity**: PowerShell `-eq` is case-insensitive by default -
  `"Client Success" -eq "CLIENT SUCCESS"` is `$true`. That is usually what you want for
  attribute comparison. Use `-ceq` only if case-sensitive comparison is explicitly needed.
  When consolidating logs in Python, use `.lower()` to match PowerShell behavior.

## False "Updated" Status

Symptom: script logs "Updated" when old and new values are identical.
Cause: missing comparison check - the script blindly calls `Set-ADUser`.
Fix: the null-safe compare pattern above.

## Mail-Fallback User Lookup

HR feeds identify users by email; AD SamAccountName does not always match the email local part.
Try SAM first, then fall back to the Mail attribute - and apply the update using the resolved
user OBJECT, never the SAM string:

```powershell
$adUser = Get-ADUser -Filter "SamAccountName -eq '$sam'" -Properties Title
if (-not $adUser) {
    $adUser = Get-ADUser -Filter "Mail -eq '$email'" -Properties Title
}
if ($adUser) { Set-ADUser -Identity $adUser -Title $newTitle }
```

## HR CSV Data Quirks

- **Header names are messy and real** - e.g. `'Work Contact: Work Email'`,
  `'Job Title Description'`, `'ADP Location2'`. Read by exact header name; validate headers on
  every new report before running anything.
- **Duplicate users**: a user can appear multiple times (e.g. listed under two offices). The
  last entry wins the push. For audit consolidation, compare first_old vs last_new to compute
  the net effect.
- **Column bleed / concatenated cells**: watch for values like
  `VP, Investor Relationsuser1@example.com` - the source Excel had column bleed. Flag these in
  logs; they corrupt AD data if pushed.
- **User not found**: verify with
  `Get-ADUser -Filter "SamAccountName -eq 'user1'" -Properties Enabled` - the account may be
  disabled, deleted, or the CSV may carry the wrong SAM.

## OU Name Mismatches

HR location names rarely match AD OU names exactly. Always use an explicit hardcoded mapping
table - never fuzzy/substring matching against OU distinguished names. Log `[NO MAPPING]` and
skip on unknown values instead of erroring out.

## Date & Locale Gotchas

- The AD server may run a non-US locale (dd/MM/yyyy). ALWAYS format dates explicitly:
  `.ToString("MM/dd/yyyy")` / `Get-Date -Format "yyyy-MM-dd HH:mm:ss"`.
- For `Export-Csv`, format DateTime properties before exporting - never rely on system culture.
- When parsing dates from mixed-format CSVs, try formats in order with
  `[DateTime]::ParseExact(..., [CultureInfo]::InvariantCulture)` fallbacks.
- `AccountExpirationDate` can return blank on some environments even when the raw
  `accountExpires` attribute is populated - the raw attribute + `[DateTime]::FromFileTime()`
  is the reliable path (see `scripts/identity-ad/contractor-check/`).

## Integrity Checks

When updating a single attribute, capture the OTHER attributes before AND after the change and
log a warning if anything else changed unexpectedly. Include columns like
`Title_Before,Title_After,IntegrityCheck` in sensitive pushes (Department, Office).

## Logging Format

Use `Add-Content` with escaped quotes for CSV-safe output:

```powershell
Add-Content -Path $logFile -Value "`"$sam`",`"$displayName`",`"$oldVal`",`"$newVal`",Status"
```

## Test-First Approach

Always create a TEST version (10 users) before FULL. TEST scripts are identical except:
- Input file points to `*_TEST_*.csv`
- Log file prefix includes `_TEST_`
- Banner says "TEST" in yellow

## Running Scripts with Spaces in Path

```powershell
& "C:\Users\AdminUser\Documents\HR List\ADP UPDATE\02_Push-JobTitle-FULL.ps1"
```
Must use the `&` call operator with a quoted path.

## General Hygiene

- Never hardcode credentials - use `Get-Credential`, secure string files, or (from a
  controller machine) 1Password `op run` env injection
- `[CmdletBinding()]` and `param()` blocks on everything
- Audit logging with timestamps for all administrative actions
- Test in non-production first
