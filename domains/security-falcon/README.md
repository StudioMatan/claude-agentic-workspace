# security-falcon

EDR detection triage and detection engineering on CrowdStrike Falcon, run as a skill-driven Claude Code practice across two tenants (~800 workstations, ~100 servers/DCs).

## What's here

| File | Purpose |
|---|---|
| [`triage-workflow.md`](triage-workflow.md) | Flagship methodology doc - report style, investigation order, detections-vs-leads handling, multi-tenant lookup, IOC enrichment |
| [`detection-triage/SKILL.md`](detection-triage/SKILL.md) | The triage skill: locate JSON -> structural pass -> per-case deep dive -> policy lenses -> standardized report with copy-paste console status line |
| [`falcon-api/SKILL.md`](falcon-api/SKILL.md) | Live API pull skill - OAuth2 via falconpy, credential setup, scopes, report generation |
| [`custom-ioa-management.md`](custom-ioa-management.md) | Custom IOA rule inventory, lifecycle, audit-comment templates, exclusion design process |
| [`software-approval-policy.md`](software-approval-policy.md) | The hard gate applied before any FP verdict - "legitimate vendor" is never enough |

## Highlights

- **Detections vs automated leads are different evidence classes.** A detection is one rule firing on one event; a lead is Falcon's AI correlating weak signals over days. They get different triage priorities and different key fields - treating them the same is how open leads get buried.
- **Detect-first rule lifecycle.** Every new IOA rule ships as Detect, validates in production, then escalates to Kill Process/Block Execution - with an audit comment on every change and platform-aware regex (no `.exe` on Mac/Linux). Duplicate detect/block rule pairs are intentional.
- **Policy before technical.** The software-approval lens runs before any technical FP analysis. Unapproved software defaults to True Positive policy violation regardless of how benign the binary is.
- **Multi-tenant fallback.** A host missing from the primary tenant is looked up in the second tenant before concluding it doesn't exist - a small rule that kills a whole class of wrong "device not found" answers.

All API scripts use the ephemeral credential pattern in [`../../rules/secret-handling.md`](../../rules/secret-handling.md) - `op run` injection, short-lived bearer tokens, read-only by default. The triage skill and report format feed directly into the automated pipeline in [`../../flows/falcon-claude-soar/`](../../flows/falcon-claude-soar/).

## Tools operated

CrowdStrike Falcon (unified Alerts API, Custom IOA, RTR, FQL, Fusion SOAR), Mimecast gateway, Microsoft 365 security stack (Purview, EXO PowerShell), SPF/DKIM/DMARC, Cisco Meraki (MDM, firewall/IDS), PagerDuty, enrichment stack (VirusTotal, ANY.RUN, Hybrid Analysis, OTX, AbuseIPDB, URLhaus, PhishTank, Shodan InternetDB), 1Password CLI, MITRE ATT&CK mapping.
