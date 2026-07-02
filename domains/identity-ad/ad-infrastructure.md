# AD Infrastructure Reference

Sanitized reference for the OU design pattern used by the HR->AD sync and the AD scripts in
`scripts/identity-ad/`. Domain names, IPs, and accounts are placeholders - the *structure* is
the real design.

## Domain
- FQDN: `ad.example.com`
- DC path: `DC=ad,DC=example,DC=com`
- Admin account: `AdminUser`
- Script execution server path: `C:\Users\AdminUser\Documents\HR List\ADP UPDATE\`

## OU Design Pattern

Two top-level OUs for users - split by *how* people work, not just where:

- `OU=Offices,DC=ad,DC=example,DC=com` - physical office locations, nested by region
- `OU=Remote Users,DC=ad,DC=example,DC=com` - remote workers, grouped by region (not per state/country)

### Office OUs (under Offices)
| Region | OUs |
|--------|-----|
| USA | Baltimore, Bellevue, Burlington, Chicago, Los Angeles, New York, Redwood City, San Diego, Texas |
| Canada | Toronto, Waterloo |
| Europe | UK, Germany |
| Middle East | Tel Aviv |
| APAC | Melbourne, Philippines, Singapore, Sydney, Tokyo |

### Remote OUs (under Remote Users)
- `US-Remote` - all US remote workers regardless of state
- `APAC-Remote` - APAC remote (includes Malaysia, Australia)

The design keeps the tree shallow: dozens of "Remote - <state>" HR values collapse into one
OU, so group policy and delegation stay manageable.

## Key Mappings (HR location name -> AD OU name)

HR location labels rarely match AD OU names exactly - an explicit mapping table is mandatory
(never fuzzy-match against OU DNs):

- "Israel" -> `OU=Tel Aviv,OU=Middle East,OU=Offices`
- "Dallas" -> `OU=Texas,OU=USA,OU=Offices`
- "Kitchener" -> `OU=Waterloo,OU=Canada,OU=Offices`
- "United Kingdom" -> `OU=UK,OU=Europe,OU=Offices`
- "Malaysia" / "Remote - Australia" -> `OU=APAC-Remote,OU=Remote Users`
- All "Remote - [US State]" -> `OU=US-Remote,OU=Remote Users`

Full table: `hr-ad-sync/references/ou-mapping.md`.

## AD Attributes Used by the Sync
- `Title` - job title (`Set-ADUser -Title`)
- `Description` - job description (`Set-ADUser -Description`)
- `Department` - department name (`Set-ADUser -Department`)
- `Manager` - DN of the manager (resolved from email via the `Mail` attribute)
- `physicalDeliveryOfficeName` - office location (`Set-ADUser -Office`)
- `DistinguishedName` - used to determine current OU and for `Move-ADObject`

## Exact Attribute Names Matter
Always use the actual attribute name as stored in AD, not the PowerShell friendly name, when
querying raw:

| Friendly name | Actual attribute |
|---|---|
| AccountExpirationDate | accountExpires |
| LastLogonDate | lastLogonTimestamp |
| PasswordLastSet | pwdLastSet |

## Date Format Standard
- ALL scripts and exports MUST use US date format `MM/dd/yyyy` or ISO 8601 `yyyy-MM-dd`
- The AD server may run a non-US locale (e.g. dd/MM/yyyy) - it MUST be overridden explicitly
- In PowerShell: `.ToString("MM/dd/yyyy")` or `Get-Date -Format "yyyy-MM-dd HH:mm:ss"` - never
  rely on system culture
- For `Export-Csv`, format DateTime properties BEFORE exporting
- Applies to: expiration dates, creation dates, last logon dates, any DateTime field
