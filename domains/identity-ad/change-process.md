# HR -> AD Change Process

Methodology for bulk AD changes driven by HR data. The point: every write is rehearsed,
ordered, logged, and reversible in audit terms.

## Workflow Order

When pushing multiple attributes from HR data:
1. **Job Title** (`Set-ADUser -Title`) - from `'Job Title Description'` column
2. **Description** (`Set-ADUser -Description`) - same source column as Title
3. **Manager** (`Set-ADUser -Manager`) - from `'Reports to Email'` column
4. **Department** (`Set-ADUser -Department`) - from `'Department'` column
5. **Office** (`Set-ADUser -Office`) - from the HR office-location column
6. **OU Move** (`Move-ADObject`) - LAST, after Office is set, uses the mapping table

## Test-First Protocol

1. Create a `*_TEST_*.csv` with 10 users covering diverse scenarios (different locations,
   confirmed movers, edge cases)
2. Create a `*-TEST.ps1` pointing to the test CSV
3. Run the test, review the logs
4. Only then run `*-FULL.ps1` against the complete list

## Logging Requirements

Every script must log:
- Old value and new value for the target attribute
- Status: `Updated | Skipped - No Change | Not Found | Error`
- For sensitive operations (Department, Office): integrity-check columns for the OTHER
  attributes, to prove nothing else changed

## Consolidation

After all scripts run, consolidate logs into a single `All_Changes_Consolidated_*.csv` with:
- One row per unique user (SamAccountName)
- Old/New/Status columns for each attribute
- Net status for users appearing multiple times (first_old vs last_new)

## Security Considerations

- Always include a confirmation prompt (`Read-Host`) before bulk changes
- `Move-ADObject` is high-impact - always test first, always run last
- Never update attributes not explicitly requested
- Never move disabled users (skip `Enabled -eq $false`, log `Skipped - Disabled`)
- Log everything for the audit trail
