# claude-agentic-workspace

An orchestrated multi-agent security operations workspace - detection triage, identity sync, device correlation, SOAR flows. Built with Claude, sanitized from production.

## Who built this

I'm Matan Alon - an IT systems engineer who runs hybrid infrastructure and identity for a ~1,400-person global company, and is responsible for securing what he runs: endpoints, email, identity, and cloud. This repo is the actual system I work with, sanitized for sharing: an orchestrated set of AI agents that handle the repetitive half of security operations, so I can spend my time on the judgment half.

Every agent here solves a problem I actually had - triaging EDR detections at volume, syncing HR data into Active Directory without breaking anyone, figuring out which of four systems knows a device's real owner. Nothing is theoretical.

Open to security engineering roles and independent automation projects - [LinkedIn](https://www.linkedin.com/in/matan-alonn).

## How it works

```
                        MASTER ROUTER (orchestrator/agent-map.md)
                     thin, always-on - routes tasks, nothing else
                                       |
        +----------------+-------------+--------------+----------------+
        |                |             |              |                |
  security-falcon   identity-ad   email-exchange   devices          cloud
  detection triage  HR->AD sync   mailbox triage   device           forensics
  Falcon API        WinRM subagent gateway-bypass  correlation      runbooks
  IOA lifecycle     AD patterns   methodology      identity ladder  SSO review
        |
        +--> flows/falcon-claude-soar - the automated detection-to-report pipeline
```

Three layers under the router:

- **Domain orchestrators** own their subagents and skills - the master never micromanages
- **Skills** load on demand by description - only the router stays always-on (context stays lean)
- **Rules** are the always-on policy layer - secret handling, sanitization, approval policy

Full design: [ARCHITECTURE.md](ARCHITECTURE.md)

## Repo map

| Area | What's inside |
|------|---------------|
| [orchestrator/](orchestrator/) | The master routing pattern - one thin map, skills load on demand |
| [domains/security-falcon/](domains/security-falcon/) | EDR detection triage methodology, Falcon API skill, custom IOA rule lifecycle |
| [domains/identity-ad/](domains/identity-ad/) | HR-to-AD sync orchestrator + WinRM remoting subagent, PowerShell patterns |
| [domains/email-exchange/](domains/email-exchange/) | Mailbox triage skill, gateway-bypass detection methodology (FromIP/PTR) |
| [domains/devices/](domains/devices/) | 4-source device correlation and owner identity resolution |
| [domains/cloud/](domains/cloud/) | AWS volume forensics runbook, Azure SSO app review checklist |
| [domains/networks/](domains/networks/) | Read-only firewall policy review (Juniper SRX → Meraki migration assessment) |
| [flows/falcon-claude-soar/](flows/falcon-claude-soar/) | The SOAR pipeline: Falcon -> PagerDuty -> Claude -> Slack, with architecture |
| [rules/](rules/) | Always-on policy: secret handling (1Password op-run pattern), data sanitization |
| [docs/](docs/) | Standalone teaching docs: credential architecture, email gateway defense-in-depth |
| [scripts/](scripts/) | Sanitized, parameterized PowerShell utilities |
| [persona-swarm/](persona-swarm/) | Meta: the agent swarm that built and sanitized this very repo |

## Start here

1. [flows/falcon-claude-soar/architecture.md](flows/falcon-claude-soar/architecture.md) - the centerpiece: automated detection-to-report pipeline
2. [SECURITY.md](SECURITY.md) - the threat model of this system and the full connector inventory: every external system, its auth, its scope
3. [rules/secret-handling.md](rules/secret-handling.md) - how agents get credentials without ever holding them
4. [domains/security-falcon/triage-workflow.md](domains/security-falcon/triage-workflow.md) - the triage methodology the agents follow

## Use this yourself

The sanitized placeholders are the template - this clones as a working starting point:

1. `git clone https://github.com/StudioMatan/claude-agentic-workspace`
2. Create your vault items (1Password or equivalent), copy each `.env.op.example` to `.env.op`, point the `op://` references at your items - no code changes
3. Copy the `SKILL.md` folders you want from `domains/*/` into your project's `.claude/skills/`
4. Replace the placeholders (`example.com`, `Tenant-A`, `10.0.1.x`) with your environment's values
5. Point the `./data/` paths at wherever your exports land

Every script is parameterized - domains, OUs, and paths are arguments, not hardcoded values. Read [SECURITY.md](SECURITY.md) before wiring any connector.

## Honesty notes

- This is a sanitized copy of a working production system. Org identifiers, internal hosts, credentials, and personal data are replaced with generic equivalents - the sanitization rule that did it ships in [rules/data-sanitization.md](rules/data-sanitization.md).
- Metrics marked "illustrative" are rounded approximations, not measured claims.
- Phase status in the SOAR flow is honest: Phase 1 is built and running, Phase 2 is in progress, Phase 3 is planned. Terraform is a learning track, not a claimed skill.

## Related

- [learning-lab](https://github.com/StudioMatan/learning-lab) - where I practice. Rough edges intentional.
