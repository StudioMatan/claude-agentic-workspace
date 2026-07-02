# Email Gateway Architecture: Defense in Depth and the Bypass Gap

A case study in layered email security: how a missing transport-layer control let a spoofing campaign skip the gateway entirely, how it was detected with FromIP/PTR analysis, and how it was closed. Names, dates, and internal domains sanitized; the attacker infrastructure domain is kept defanged.

## The layered model

Email security is a stack. Each layer catches what the previous one misses - and a gap in any layer lets attackers bypass everything above it.

```
Layer 1 - DNS (MX record)       -> tells senders where to deliver
Layer 2 - Gateway (SEG)         -> scans and filters all inbound
Layer 3 - Transport (Connector) -> Exchange only accepts from gateway IPs
Layer 4 - Auth (SPF/DKIM/DMARC) -> proves sender legitimacy
Layer 5 - Detection             -> content/behavior analysis
```

## The gap

Layer 3 was missing: no inbound connector restricting Exchange Online to the secure email gateway's IP ranges. The MX record pointed at the gateway - but an MX record is a suggestion, not an enforcement. Attackers ignored it and delivered straight to the tenant's `*.mail.protection.outlook.com` endpoint, skipping the gateway scan entirely.

This is the cloud equivalent of a security guard at the front door and an unlocked back door.

## Detection: FromIP analysis

Every email has two identities:

- **Display address** (From: header) - what the attacker shows you. Can be forged freely.
- **FromIP** - the actual server that delivered it. Cannot be faked.

The investigation workflow:

1. Pull message trace (`Get-MessageTraceV2`) - gives FromIP for every inbound message
2. PTR lookup on each unique IP - resolves the IP to a hostname (the server's real identity)
3. PTR contains the gateway vendor's name -> legitimate path. Anything else -> bypassed the gateway.
4. Group by IP + sender domain -> same IP spoofing multiple of your domains = shared attacker infrastructure

## Red flags observed (spoofing campaign)

| Signal | What was seen | Why it mattered |
|---|---|---|
| PTR mismatch | Delivery IP resolved to `therdpsdaddy(.)store` | A legitimate sender for the corporate domain would not deliver from a random unrelated host |
| Burst timing | ~270 emails in about 3 minutes | Humans do not send at machine speed |
| One IP, many domains | Same IP spoofing multiple corporate domains | Shared attacker infrastructure, single campaign |
| Subject template | "NSA: [Company] Executed NDA Agreement" identical across all messages | Automated campaign impersonating a document-signing notification, not a real one |
| Conversation stuffing | Random legitimate email thread appended below the lure | Technique to fool ML content filters with benign context |

## The fix: inbound connector

Lock Exchange Online to accept external SMTP only from the gateway's published IP ranges (a partner inbound connector with restricted source IPs, plus rejection of direct external delivery). Internal M365 traffic - tenant-to-tenant mail, service notifications - is unaffected: it routes through Exchange's internal fabric, not external SMTP.

After the connector: direct-to-tenant delivery fails, and the MX record stops being a suggestion and becomes the only way in.

## Takeaways

- An MX record pointing at your gateway proves nothing about what Exchange will accept. Verify the transport layer, not just DNS.
- FromIP + PTR is the fastest ground-truth check for "did this actually come through the gateway" - headers lie, delivery IPs do not.
- Hunt for the gap proactively: message-trace all inbound for a week, PTR-resolve the unique FromIPs, and anything not resolving to your gateway is your back door.
- Burst timing, IP/domain fan-out, and template reuse separate automated campaigns from one-off spoofs faster than content analysis does.

## Vocabulary

- **MX record** - DNS record telling the internet where to deliver mail for a domain
- **SEG** - secure email gateway; the filtering layer in front of the mail platform
- **Inbound connector** - Exchange Online policy restricting which IPs can deliver external mail
- **PTR record** - reverse DNS; maps IP -> hostname (the opposite of an A record)
- **SPF** - DNS record listing IPs authorized to send as your domain
- **DKIM** - cryptographic signature proving the message was not tampered with in transit
- **DMARC** - policy for what receivers do when SPF/DKIM fail (none/quarantine/reject)
- **Conversation stuffing** - appending legitimate email content to a lure to fool ML filters
- **Gateway bypass** - delivering directly to the mail platform's endpoint, skipping the gateway
