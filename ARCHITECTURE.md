# Architecture

How one engineer runs a multi-agent security operations system without drowning in it.

## The problem this design solves

Loading everything into an AI agent's context all the time is expensive and noisy. Loading nothing makes it useless. The answer is a hierarchy - the same idea as a CPU cache: keep the hot routing layer tiny and always-on, load capabilities only when a task needs them, and keep policy ambient so no agent can skip it.

## The four layers

```
LAYER 1 - MASTER ROUTER                     always-on, ~1 page
  orchestrator/agent-map.md
  Decides WHICH domain owns a task. Nothing else.
        |
LAYER 2 - DOMAIN ORCHESTRATORS              loaded when their domain is hit
  security-falcon | identity-ad | email-exchange | devices | cloud
  Own their subagents and skills. The router never micromanages;
  domains never route outside themselves.
        |
LAYER 3 - SKILLS AND SUBAGENTS              loaded on demand, by description
  detection-triage, falcon-api, hr-ad-sync (+ its WinRM remoting
  subagent), mailbox-triage, device-correlation ...
  A skill's one-line description is what triggers loading -
  descriptions are kept sharp and non-overlapping on purpose.
        |
LAYER 0 - RULES (ambient, cross-cutting)    always-on policy
  secret-handling | data-sanitization | software-approval
  Apply to every layer above. An agent can't opt out of policy
  by simply not loading it.
```

## How a task flows

"Triage the latest detection export" ->

1. Router matches the task to the security-falcon domain
2. Domain loads the detection-triage skill (report contract, policy lenses, triage order)
3. Rules are already ambient: software-approval policy shapes the verdict, secret-handling governs any API call
4. Output passes the format contract (verdict-first line, EDR-action column, status one-liner)
5. Analyst reviews - judgment stays human

## Lifecycle policy

Agents and skills are cheap to create and expensive to maintain - so creation is gated and retirement is automatic:

- New skill only when the gap will recur, no active agent covers it, and the registry is under its cap
- Registration is one line in the router map - if it isn't registered, it doesn't exist
- Unused for 30 days -> inactive. Scope overlap > 60% -> merge. Never delete - inactive skills can return
- Hard cap on active agents forces prioritization instead of sprawl

## Credentials

No agent holds a secret. The pattern (full detail in [rules/secret-handling.md](rules/secret-handling.md)):

```
vault (1Password) -> reference file (.env.op, addresses only) -> op run injects
ephemeral env vars -> script exchanges long-lived secret for a short-lived token
-> works only with the token
```

Read-only API scopes by default. Write actions require explicit human confirmation.

## Quality gates

Every output that leaves the system passes checks before delivery:

- Hard fails - org identifiers, internal hosts, credentials, personal data: block and fix
- Soft flags - voice, format, vagueness: three flags = revise
- Two failed revisions = escalate to the human

The gate is itself an agent instruction file, versioned with everything else. This repo is the proof: it was built, sanitized, and swept by [the swarm in persona-swarm/](persona-swarm/), using [the shipped sanitization rule](rules/data-sanitization.md).

## Design principles

1. **Thin router, fat domains** - routing knowledge and domain knowledge never mix
2. **Registration is the single source of truth** - one map, no duplicated routing logic
3. **Policy is ambient, capability is lazy-loaded**
4. **Human-in-the-loop where judgment lives** - agents draft, verify, and format; humans decide
5. **State survives sessions** - orchestrators keep a STATE file so any future session resumes where the last one stopped
