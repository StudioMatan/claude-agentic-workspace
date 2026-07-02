# Security Model

AI agents with credentials and API access are an attack surface. This page is the threat model of this workspace and how each threat is answered - written by the security engineer who runs it, because "I built agents" without "here is how I secured them" is half a story.

## Threat model

| Threat | Control | Implementation |
|---|---|---|
| Credential exposure on disk or in code | Secrets never touch the repo, scripts, or agent context - reference files hold vault addresses, values are injected at runtime | [rules/secret-handling.md](rules/secret-handling.md) |
| Long-lived credential theft | Every long-lived secret is exchanged immediately for a short-lived token; the secret is discarded, agents work only with the thing that expires | [docs/credential-pattern.md](docs/credential-pattern.md) |
| Prompt injection via detection content | Attacker-controllable strings (command lines, filenames, domains) are treated as untrusted data, never as instructions - locked system prompts, fixed output schemas | [flows/falcon-claude-soar/architecture.md](flows/falcon-claude-soar/architecture.md) |
| Scope creep | Read-only API scopes by default; write actions need a separate, explicitly reviewed credential; agent registry is capped and creation is gated | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Autonomous damage | Agents produce verdicts, not actions - every output lands in front of a human before anything acts; response automation is gated behind validated accuracy | [flows/falcon-claude-soar/architecture.md](flows/falcon-claude-soar/architecture.md) |
| Data leakage in published output | A sanitization QA gate blocks org identifiers, hosts, credentials, and personal data - this repo is the proof: it shipped through that gate | [rules/data-sanitization.md](rules/data-sanitization.md), [persona-swarm/QA.md](persona-swarm/QA.md) |
| Inbound attack surface | There isn't one - every integration is outbound HTTPS; no inbound ports, no exposed servers | [flows/falcon-claude-soar/architecture.md](flows/falcon-claude-soar/architecture.md) |

## Connector inventory

Every external system the agents touch, with its auth method, scope, and direction. Any new connector enters this table before it enters production, with the narrowest scope that works.

| System | Direction | Auth | Scope |
|---|---|---|---|
| CrowdStrike Falcon | outbound HTTPS | OAuth2 client credentials, exchanged for a 30-min bearer token | Alerts-Read, Hosts-Read - nothing else |
| Active Directory | outbound WinRM | credentials injected per-run via `op run`, never stored | targeted OUs only; test-first protocol, every change logged |
| Exchange Online | outbound HTTPS | delegated auth, short-lived session | read-only cmdlets in triage; writes are a separate human step |
| AWS (Lambda / S3) | internal | IAM role, secrets via Secrets Manager | least-privilege role; archive prefix is write-only |
| Slack | outbound HTTPS | incoming webhook | one channel, post-only |
| PagerDuty | outbound HTTPS | scoped integration key | one service, events only |
| Anthropic API | outbound HTTPS | scoped API key | message creation only, token-capped, locked system prompt |
| 1Password | local | biometric-unlocked CLI session | secrets read at runtime, nothing cached to disk |

## The pattern in one line

Vault holds the secret -> reference file holds the address -> runtime injects the value -> value is exchanged for something that expires -> the agent only ever sees the thing that expires.

## Honest limits

No setup makes "an agent with credentials" risk-free. A process running as a user can, in principle, reach what that user can reach. These controls reduce blast radius, shorten credential lifetime, add audit trails, and put a human in front of every action - they do not make risk zero. The trust decision is made per-connector, documented in the table above, so it can be challenged.

## Reporting

Spotted a sanitization miss or a real issue in anything here? Open a private [security advisory](../../security/advisories/new) or reach me on [LinkedIn](https://www.linkedin.com/in/matan-alonn) - not a public issue, please.
