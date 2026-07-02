# Email Security Methodology: Detecting and Closing a Gateway Bypass

A working methodology for finding the gap in a layered email security stack -
built from a real investigation where a spoofing campaign delivered straight to
Exchange Online, skipping the gateway entirely.

## The Layered Model

Email security is defense in depth. Each layer catches what the previous one
misses; a gap in any layer lets attackers bypass everything stacked above it.

```
Layer 1 - DNS (MX record)       -> tells senders where to deliver
Layer 2 - Gateway (Mimecast)    -> scans and filters all inbound
Layer 3 - Transport (Connector) -> Exchange only accepts from gateway IPs
Layer 4 - Auth (SPF/DKIM/DMARC) -> proves sender legitimacy
Layer 5 - Detection             -> content / behavior analysis
```

The trap: pointing MX at the gateway (Layer 1) feels like "all mail goes through
the gateway." It doesn't. MX is advice, not enforcement. Any sender can ignore MX
and deliver directly to the tenant's `*.mail.protection.outlook.com` endpoint.
Without Layer 3 - an inbound connector restricting accepted source IPs - Exchange
accepts mail from anyone. A security guard at the front door with the back door
unlocked.

## Detection: FromIP + PTR Analysis

Every email carries two identities:

- **Display address** (From: header) - what the attacker shows you. Forgeable.
- **FromIP** - the actual delivering server. Not forgeable.

The workflow:

1. Pull message trace for the window under investigation:
   ```powershell
   Get-MessageTraceV2 -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) |
       Select-Object Received, SenderAddress, RecipientAddress, Subject, FromIP
   ```
2. Extract unique FromIP values and run a PTR (reverse DNS) lookup on each -
   the PTR resolves the IP to the sending server's real hostname.
3. Classify: PTR contains the gateway's name (e.g. `*.mimecast.com`) = legitimate
   path. Anything else on external mail = it bypassed the gateway.
4. Group bypassing mail by FromIP + sender domain. One IP spoofing multiple of
   your own domains = shared attacker infrastructure, not coincidence.

## Red Flags Worth Pattern-Matching

Signals from the campaign that made the verdict, in the order they surfaced:

| Signal | What it looked like | Why it mattered |
|---|---|---|
| PTR mismatch | Sender claimed to be a company domain; PTR of the FromIP resolved to an unrelated commodity-hosting domain | A legitimate company sender never delivers from random infrastructure |
| Burst timing | ~270 emails in 3 minutes | Humans don't send at machine speed |
| One IP, many domains | Same FromIP spoofing three of the org's own brand domains | Shared attacker infrastructure |
| Subject template | Identical "Executed NDA Agreement" DocuSign-style subject across all messages | Automated campaign, not real workflow |
| Conversation stuffing | A random legitimate email thread appended below the lure | Injected real content to fool ML content filters |

## The Fix: Inbound Connector Lockdown

Close Layer 3: create an Exchange Online inbound partner connector that restricts
external SMTP to the gateway's published IP ranges. Mail from any other source is
rejected at transport - before content filtering even runs.

Two things to verify before enabling:

- **Internal M365 traffic is unaffected.** Tenant-to-tenant and service
  notifications route through Exchange's internal fabric, not external SMTP -
  they never touch the connector restriction.
- **Enumerate legitimate direct senders first.** Anything doing direct SMTP to
  the tenant (printers, apps, third-party relays) must be moved behind the
  gateway or explicitly handled before lockdown, or it breaks silently.

## The Authentication Layer (SPF / DKIM / DMARC)

Connector lockdown stops direct-to-tenant delivery. Authentication stops your
domains being spoofed at everyone else:

- **SPF** - DNS record listing IPs authorized to send as your domain. Publish for
  every domain you own, including parked/brand domains that never send.
- **DKIM** - cryptographic signature proving the message wasn't tampered with in
  transit. Sign at the gateway so the signature survives the full path.
- **DMARC** - the policy tying them together: what receivers should do when
  SPF/DKIM fail (`none` -> `quarantine` -> `reject`), plus aggregate reporting.
  Start at `p=none` to collect reports, identify legitimate senders you missed,
  then ratchet to `reject`. Brand domains that send nothing should sit at
  `reject` from day one.

DMARC reports are also a detection source: they show who is attempting to spoof
your domains globally, not just what reached your own tenant.

## Verification Loop

After lockdown, prove the gap is closed:

1. Re-run the FromIP + PTR sweep over a post-change window.
2. Expected state: 100% of external inbound resolves to gateway PTRs.
3. Alert on drift - a scheduled trace + PTR check catches any new connector
   misconfiguration or an added bypass route before an attacker does.

## Vocabulary

- **MX record** - DNS record telling the internet where to deliver mail for a domain
- **Inbound connector** - Exchange Online policy restricting which IPs can deliver external mail
- **PTR record** - reverse DNS; maps IP to hostname (opposite of an A record)
- **Gateway bypass** - delivering directly to the Exchange endpoint, skipping the gateway
- **Conversation stuffing** - injecting legitimate email content into a lure to fool ML filters
