# Contractor Expiration Date Scripts - Comparison

Two reporting methods for AD account expiration, plus a diagnostic to pick between them.
Written after a production environment returned blank `AccountExpirationDate` values even
though the raw attribute was populated.

## Scripts

### 1. `Get-ADUserExpirationDates.ps1` (standard method)
**Method:** `AccountExpirationDate` property (PowerShell-computed)
**Advantages:** simpler code, automatic conversion, enhanced error handling, transcript
logging, summary statistics, expiring-soon vs expired breakdown.

### 2. `Get-ADUserExpirationDates-RawAttribute.ps1` (fallback method)
**Method:** raw `accountExpires` attribute with manual FileTime conversion
**Advantages:** direct attribute access, includes the raw value for troubleshooting, handles
the never-expires edge cases (0 and max Int64), full control over conversion.
**This was the ONLY method that returned correct dates in the environment this was built for -
`AccountExpirationDate` came back blank.** Keep both; diagnose first.

### 3. `Diagnose-AccountExpiration.ps1`
Samples the target OU and reports which attribute actually carries data, then recommends the
right script. Also checks extensionAttribute1-15 in case end dates are tracked in a custom
attribute.

### 4. `Set-ContractorExpirationDates.ps1` (WRITE)
Bulk-sets expiration dates from a CSV via the .NET AccountManagement API (bypasses AD-module
permission issues). Flexible identity resolution and day-first date fallbacks.

### 5. `Fix-Csv.ps1`
Pre-cleaner: rewrites unambiguous DD/MM/YYYY dates to ISO 8601 before the setter runs.

## Configuration

Defaults (all parameterized):
- **OU Path:** `OU=Contractors,DC=ad,DC=example,DC=com`
- **Export Path:** `C:\Reports`
- **Output naming:** `ContractorsActiveusers-YYYYMMDD HHmm.csv` (RawAttribute variant adds a suffix)

## CSV Output Format

Core columns:
```
Name, Email, UserPrincipalName, ChildOU, Description, Manager, EndDate, CreationDate
```
Analysis columns:
```
ExpirationStatus, DaysUntilExpiration, Department, Title, Enabled, LastLogonDate, ...
```

## Key Differences: AccountExpirationDate vs accountExpires

| | AccountExpirationDate | accountExpires |
|---|---|---|
| Type | DateTime (computed property) | Integer8 (raw AD attribute, FileTime) |
| Never-expires value | `$null` | `0` or `9223372036854775807` |
| Conversion | Automatic | Manual `[DateTime]::FromFileTime()` |
| When to use | Default choice, simpler | When the computed property returns blank/unexpected values |

## Workflow

1. Run `Diagnose-AccountExpiration.ps1` against the target OU
2. Use the script it recommends
3. If EndDate shows proper dates instead of "No End Date", the method is right for your environment

## Security Notes

- Reporting and diagnostic scripts are read-only; only `Set-ContractorExpirationDates.ps1` writes
- All scripts require the AD PowerShell module and appropriate permissions
- All actions logged (transcript or timestamped log file) for audit purposes
- Run in a domain-joined environment only
