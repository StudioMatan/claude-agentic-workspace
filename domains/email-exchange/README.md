# email-exchange

Exchange Online operations and email security: a mailbox-triage agent skill plus a gateway-bypass detection methodology built from a real spoofing investigation.

## What's here

| File / folder | Purpose |
|---|---|
| [`email-security-methodology.md`](email-security-methodology.md) | Flagship doc - finding and closing a gateway bypass: layered model, FromIP + PTR analysis, attacker-infrastructure red flags, inbound connector lockdown, post-fix verification |
| [`mailbox-triage/SKILL.md`](mailbox-triage/SKILL.md) | The triage skill: client vs server vs gateway fork, read-only-first cmdlet order, EXO admin auth pattern |
| [`mailbox-triage/references/diagnostic-cmdlets.md`](mailbox-triage/references/diagnostic-cmdlets.md) | Extended read-only diagnostic cmdlet reference |

A related runnable utility lives at [`../../scripts/email-exchange/Fix-ConferenceRoomFreeBusy.ps1`](../../scripts/email-exchange/Fix-ConferenceRoomFreeBusy.ps1).

## Highlights

- **MX is advice, not enforcement.** Pointing MX at the gateway does not force mail through it - any sender can deliver directly to the tenant's `*.mail.protection.outlook.com` endpoint. Without an inbound connector restricting source IPs, the gateway is a guard at the front door with the back door unlocked. A real campaign exploited exactly this.
- **FromIP + PTR is the detection technique.** The From: header is forgeable; the delivering server's IP is not. Message trace -> PTR lookup per unique IP -> anything not resolving to the gateway bypassed it. Grouping by IP surfaces shared attacker infrastructure (one IP spoofing several brand domains).
- **Triage forks before any cmdlet runs.** "Sent items missing" is three different problems depending on where the message IS visible (gateway portal / OWA / desktop) - the fork table decides client-side vs server-side vs journaling gap before anything is touched.
- **Operational discipline as policy.** EXO admin only (never the affected user's account), read-only cmdlets first, writes only after explicit approval, before/after capture on every change.

The layered model here is the same defense-in-depth thinking applied to endpoints in [`../security-falcon/`](../security-falcon/).

## Tools operated

Exchange Online (EXO PowerShell, message trace, transport rules, connectors), Mimecast gateway administration, Abnormal-to-Mimecast migration, Microsoft Purview content search / eDiscovery, long-running EXO jobs offloaded to a persistent Linux host (pwsh + screen + device-code auth).
