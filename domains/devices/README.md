# devices

Entity resolution applied to IT asset management: correlating four asset sources across a ~800-endpoint fleet to answer "which active employee owns which device, and is it visible in every tool?"

## What's here

| File / folder | Purpose |
|---|---|
| [`device-correlation/SKILL.md`](device-correlation/SKILL.md) | The correlation skill - sources, run procedure, join rules, workbook output |
| [`device-correlation/references/identity-resolution.md`](device-correlation/references/identity-resolution.md) | The six-rung fuzzy resolution ladder with its verification gate |
| [`user-device-mapping.md`](user-device-mapping.md) | Compact owner-resolution ruleset and the owner taxonomy |
| [`invgate-api/SKILL.md`](invgate-api/SKILL.md) | Live InvGate ITSM lookups: serial -> asset -> owner resolution, offboarding and returned-device checks, API gotchas |

## Highlights

- **Four sources, none authoritative alone.** ITSM (InvGate) has ownership but stale emails; MDM (Meraki SM) has enrollment but blank owners and free-text names; EDR (Falcon) knows who logged in last - which may be an admin or a departed employee; the HR/AD roster knows who actually works here today. The workbook is the intersection.
- **The discipline is what NOT to match on.** Hostnames never join devices (the same laptop carries different names per tool, and one name can cover five machines) - devices join on serial only, people resolve on email/name only. ITSM ownership takes precedence; an EDR login string resolves an owner only if it maps to a verified HR or contractor identity.
- **Conflicts are surfaced, never silently resolved.** Same local-part on a legacy brand domain = same person; two different real people claiming one device = a Conflict row for a human, not a coin flip. Everything that falls off the ladder lands in "needs review". ~97% agreement against EDR last-login on the last full run.
- **Outputs drive actions**: reclaim ex-employee devices, fix mis-owned inventory, close EDR coverage gaps.

The EDR pull uses the multi-tenant Falcon API pattern from [`../security-falcon/`](../security-falcon/), with credentials injected per [`../../rules/secret-handling.md`](../../rules/secret-handling.md).

## Tools operated

CrowdStrike Falcon (multi-tenant, FalconPy), Meraki Systems Manager, InvGate ITSM, ADP HR feed + AD pulls; Python/pandas/openpyxl pipeline producing a color-coded multi-sheet Excel workbook.
