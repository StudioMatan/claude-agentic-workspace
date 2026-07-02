# Extended Exchange Diagnostic Cmdlets

Companion reference for the mailbox-triage skill. All read-only unless marked.

## Distribution List Management

```powershell
# Get DL members
Get-DistributionGroupMember -Identity "DLName"

# Export all DL membership
Get-DistributionGroup | ForEach-Object {
    Get-DistributionGroupMember -Identity $_.Name |
    Select-Object @{N='Group';E={$_.Name}}, DisplayName, PrimarySmtpAddress
} | Export-Csv "DL-Membership.csv" -NoTypeInformation

# Add members from CSV (WRITE - needs approval)
Import-Csv "users.csv" | ForEach-Object {
    Add-DistributionGroupMember -Identity "DLName" -Member $_.Email
}
```

### DL activity check (is a DL still in use?)

Query each DL individually with `Get-MessageTraceV2` and `ResultSize 1` - check
both sender and recipient sides. One hit in the window = active. Far cheaper than
pulling full traces per DL. Add a small throttle delay (~300ms) between queries
to stay under EXO rate limits.

## User-Centric Permission Query (the efficient direction)

Instead of scanning every mailbox to find who has access (O(n) API calls), query
what access a specific user HAS:

```powershell
$user = "user@example.com"

# 1. Full Access - server-side filtered
Get-Mailbox -ResultSize Unlimited | Get-MailboxPermission -User $user |
    Where-Object { $_.AccessRights -contains "FullAccess" }

# 2. SendAs
Get-RecipientPermission -Trustee $user

# 3. SendOnBehalf
Get-Mailbox -ResultSize Unlimited | Where-Object { $_.GrantSendOnBehalfTo -match $user.Split("@")[0] }
```

## Offloading Long-Running Queries

Local PowerShell sessions time out, laptops sleep, and Windows WAM auth expires
mid-run. Any of these indicators means the query should run on a persistent Linux
host (pwsh + `screen`) instead of locally:

- `-ResultSize Unlimited` on any command
- Piping `Get-Mailbox` into `Get-MailboxPermission`
- Any loop over 100+ mailboxes / DLs
- `Get-MessageTrace` over extended date ranges
- Anything expected to run longer than ~5 minutes

Pattern: upload script, run in a detached `screen` session with output teed to a
log, authenticate via device code flow (`Connect-ExchangeOnline -Device`), detach,
collect the CSV when done. The session survives disconnects and runs unattended
for hours.

## Room Mailbox Free/Busy

Symptom: a room shows "always busy" or blank availability for some users.
Root cause is almost always Free/Busy publishing disabled on the calendar folder.

```powershell
# Diagnose
Get-MailboxCalendarFolder -Identity "room-a@example.com:\Calendar" |
    Select-Object Identity, PublishEnabled, DetailLevel

# Fix (WRITE - needs approval). AvailabilityOnly preserves privacy:
# users see Busy/Free but never titles or organizers.
Set-MailboxCalendarFolder -Identity "room-a@example.com:\Calendar" `
    -PublishEnabled $true -DetailLevel AvailabilityOnly
```

Secondary signals worth logging while there:
- Inbox item count > 100 = AutoAccept backlog; usually clears after the fix.
- Calendar item count > 1000 = recurring-meeting bloat; performance only.

See `scripts/email-exchange/Fix-ConferenceRoomFreeBusy.ps1` for the automated
single-room / scan-all version.

## Purview Content Search (email recovery / eDiscovery)

Requires eDiscovery Manager role; add `Add-eDiscoveryCaseAdmin` to see all cases.
Role changes take 5-10 minutes to propagate.

```powershell
Connect-IPPSSession -EnableSearchOnlySession

$SearchName = "Recovery_Description_Date"
$Query = '(from:sender@example.com) AND (subject:"Subject Line") AND (received:2024-02-27)'

New-ComplianceSearch -Name $SearchName -ExchangeLocation All -ContentMatchQuery $Query
Start-ComplianceSearch -Identity $SearchName
Get-ComplianceSearch -Identity $SearchName | Select-Object Name, Status, Items, Size
New-ComplianceSearchAction -SearchName $SearchName -Export
```

KQL quick reference:

```kql
from:sender@example.com
subject:"exact phrase"
received:2024-01-01..2024-12-31
attachment:"filename.docx"
to:recipient@example.com OR cc:recipient@example.com
```

Reading the exported PST on macOS: open in Outlook, or `brew install libpst` and
`readpst -o extracted -r file.pst`, then grep the mbox output. Base64 attachments
decode with `tail -n +4 part.txt | tr -d '\n\r ' | base64 -D > file.docx`.

## Attribute Gotcha

Always use the exact AD attribute name, not the friendly PowerShell property:
`accountExpires`, not `AccountExpirationDate` (the friendly property can return
blank on some domains while the raw attribute converts fine via `FromFileTime`).
