# scripts

Runnable, parameterized PowerShell utilities referenced by the domain docs. All paths, OUs, and domains are parameters - nothing hardcoded.

| Script | Purpose |
|---|---|
| [`email-exchange/Fix-ConferenceRoomFreeBusy.ps1`](email-exchange/Fix-ConferenceRoomFreeBusy.ps1) | Diagnose and fix conference rooms not publishing Free/Busy - single room or scan-all, with a diagnose-only mode |
| [`identity-ad/Get-ADUserExpirationDates.ps1`](identity-ad/Get-ADUserExpirationDates.ps1) | Report AD account expiration dates via the computed `AccountExpirationDate` property (standard method) |
| [`identity-ad/contractor-check/Diagnose-AccountExpiration.ps1`](identity-ad/contractor-check/Diagnose-AccountExpiration.ps1) | Show what expiration data actually exists per account, to pick the right reporting method |
| [`identity-ad/contractor-check/Get-ADUserExpirationDates-RawAttribute.ps1`](identity-ad/contractor-check/Get-ADUserExpirationDates-RawAttribute.ps1) | Report expiration via raw `accountExpires` FileTime - for environments where the computed property returns blank |
| [`identity-ad/contractor-check/Fix-Csv.ps1`](identity-ad/contractor-check/Fix-Csv.ps1) | Rewrite day-first dates in an expiration CSV to ISO 8601 so downstream scripts parse consistently |
| [`identity-ad/contractor-check/Set-ContractorExpirationDates.ps1`](identity-ad/contractor-check/Set-ContractorExpirationDates.ps1) | Bulk-set expiration dates from CSV via the .NET AccountManagement API - flexible identity resolution, multi-format date parsing |
| [`identity-ad/contractor-check/SCRIPT-COMPARISON.md`](identity-ad/contractor-check/SCRIPT-COMPARISON.md) | Why two reporting methods exist and when to use which |

Context for the contractor-check toolkit lives in [`../domains/identity-ad/`](../domains/identity-ad/).
