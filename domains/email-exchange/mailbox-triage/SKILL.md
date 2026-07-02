---
name: exchange-mailbox-triage
description: >
  Exchange Online mailbox troubleshooting agent. Use whenever a user reports
  missing / duplicated / delayed sent items, mailbox sync issues, gateway vs Outlook
  discrepancies, "email sent but not in sent items", delegate/shared mailbox send
  problems, MailTip / transport rule suspicions, or any "check this person's mailbox"
  type request. The skill knows the safe order of operations, the EXO admin auth
  pattern, and which checks to run before touching anything.
---

# Exchange Mailbox Triage

Drives Exchange Online mailbox triage for an IT/security analyst.

## The Auth Pattern (always step 1)

There is no persistent Exchange admin connector. Every session, the analyst opens
PowerShell as admin and runs:

```powershell
Connect-ExchangeOnline -UserPrincipalName admin@example.com
```

Wait until the session is confirmed connected, then drive - give the exact cmdlets
to paste, take the output back, analyze.

Security rule: never run cmdlets under the affected user's account. EXO admin only,
least-privilege. Read-only cmdlets first; write cmdlets only after explicit approval.

## The Triage Fork (decide before running anything)

Always disambiguate first. For a "sent items missing" report, check where the
message IS visible:

| Gateway Portal | OWA | Outlook Desktop | -> Path |
|---|---|---|---|
| yes | yes | no | **Client-side**: OST / cached mode / view filters / inbox rule |
| yes | no | no | **Server-side**: gateway SMTP relay bypass, transport rule, or SaveSentItems off |
| no | yes | yes | Gateway journaling gap - different problem, escalate |

Ask the OWA question before running cmdlets. OWA always shows live server data -
it splits client-side from server-side in one step.

## Read-Only Diagnostic Cmdlets (run in this order)

```powershell
# 1. Confirm mailbox identity and basic state
Get-Mailbox -Identity user@example.com | fl DisplayName,UserPrincipalName,RecipientTypeDetails,WhenChanged,LitigationHoldEnabled

# 2. Sent items save behavior
Get-MailboxMessageConfiguration -Identity user@example.com | fl Identity,IsReplyAllTheDefaultResponse,AlwaysShowFrom

# 3. Delegate / Send-As / Send-on-Behalf
Get-Mailbox user@example.com | fl GrantSendOnBehalfTo
Get-RecipientPermission user@example.com
Get-MailboxPermission user@example.com | ? {$_.IsInherited -eq $false}

# 4. Inbox rules (a rule can move sent items out of Sent Items)
Get-InboxRule -Mailbox user@example.com | ? {$_.Enabled -eq $true} | fl Name,MoveToFolder,DeleteMessage,RedirectTo

# 5. Message trace - did EXO actually see the send?
Get-MessageTrace -SenderAddress user@example.com -StartDate (Get-Date).AddDays(-2) -EndDate (Get-Date) | ft Received,RecipientAddress,Subject,Status,FromIP

# 6. Transport rules that might suppress journaling / sent-save
Get-TransportRule | ? {$_.State -eq 'Enabled'} | ? {$_.SetHeaderName -like '*X-Gateway*' -or $_.RouteMessageOutboundConnector} | ft Name,Priority,Description
```

For the gateway-shows-but-Exchange-doesn't pattern specifically, the usual root
cause is: the message was submitted via a gateway add-in / SMTP relay in a path
that did NOT use Exchange as the sending MTA, so Exchange never saw the Send and
never wrote to Sent Items. Confirm with cmdlet #5 - if `Get-MessageTrace` shows
nothing for that send, Exchange never had it.

## Client-Side Checklist (if OWA shows the mail but Outlook doesn't)

Walk the user through, in order:
1. Outlook -> File -> Account Settings -> Change -> uncheck "Use Cached Exchange Mode" -> restart -> re-enable. Forces OST rebuild.
2. View -> Current View -> Reset View. Clears any hidden filter on Sent Items.
3. Check `HKCU\Software\Microsoft\Office\16.0\Outlook\Preferences\DelegateSentItemsStyle = 1` if it's a shared/delegate scenario.
4. New Outlook (the one-Outlook client) - known to lag on cached folder writes; switch to classic to confirm.
5. Last resort: rebuild OST (close Outlook, rename .ost, reopen).

## Gateway-Side Checks

If the email exists ONLY in the gateway portal (e.g. Mimecast Personal Portal) and
message trace shows nothing in EXO, the send bypassed Exchange. Check:
- Gateway admin -> submission / "send from" policies - is the user in a policy
  that uses gateway SMTP submission?
- Gateway Outlook add-in version - older versions had a "Send Secure" path
  that didn't write to Exchange Sent Items.

## Golden Rules

1. **Read before write.** Every change cmdlet (Set-*, New-InboxRule, Remove-*) needs explicit approval.
2. **Identity is always UPN.** `user@example.com`, never the alias alone - avoids ambiguous matches.
3. **Capture before/after.** Before any Set-*, run the matching Get-* and save output. After the change, run Get-* again. Both go in the ticket.
4. **Ticket trail.** The linked ticket gets a comment with: cmdlets run, output summary, root cause, resolution.
5. **No PII in chat.** Mailbox content stays in EXO. Paste headers/metadata only.

## References

- `references/diagnostic-cmdlets.md` - extended cmdlet library: DL management, long-running query offload, room mailbox free/busy, Purview content search.

## Disconnect

End of session:
```powershell
Disconnect-ExchangeOnline -Confirm:$false
```
