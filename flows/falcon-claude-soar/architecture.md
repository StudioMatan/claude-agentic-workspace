# Falcon -> Claude SOAR - Architecture

Automated detection-to-report pipeline. Every CrowdStrike Falcon detection flows through an event trigger (Fusion SOAR webhook, with PagerDuty routing for must-respond alerts) into a Claude-powered triage agent that loads the same triage skill and policy rules a human analyst uses, and posts an analyst-grade structured verdict report to Slack in under a minute. A human reviews every verdict before anything acts - the pipeline replaces the waiting and the writing, not the judgment.

## Topology

```
┌─────────────────────────────┐
│  CrowdStrike Falcon         │
│  Tenant-A (~800 wkstations) │
│  Tenant-B (~100 servers)    │
└──────────┬──────────────────┘
           │ detection fires (Fusion SOAR event trigger)
           ▼
┌─────────────────────────────┐      ┌──────────────────────┐
│  Event routing              │─────▶│  PagerDuty           │
│  webhook out of Falcon      │      │  must-respond alerts │
└──────────┬──────────────────┘      └──────────────────────┘
           │ HTTPS (outbound only, no inbound ports)
           ▼
┌─────────────────────────────┐
│  Orchestration layer        │
│  AWS Lambda (Function URL)  │
│  - enrich via Falcon API    │
│  - burst-group via S3       │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│  Claude triage agent        │
│  loads: triage skill,       │
│  policy rules, report spec  │
└──────────┬──────────────────┘
           │ structured verdict report (locked schema)
           ▼
┌─────────────────────────────┐      ┌──────────────────────┐
│  Slack #security-alerts     │─────▶│  Analyst review      │
│  + S3 archive (audit trail) │      │  human approves      │
└─────────────────────────────┘      └──────────┬───────────┘
                                                │ (future - Phase 3)
                                                ▼
                                     ┌──────────────────────┐
                                     │  Response actions    │
                                     │  back to Falcon      │
                                     │  (contain, block)    │
                                     └──────────────────────┘
```

All calls are outbound HTTPS from Falcon's cloud or the Lambda - no inbound ports, no server exposed to the internet.

## Components

| Component | What it does | Tech | Auth pattern |
|---|---|---|---|
| Falcon Fusion SOAR | Fires on every detection, both tenants; carries detection fields into the flow | CrowdStrike Fusion SOAR event workflow | Tenant context (native, no credentials in workflow body) |
| PagerDuty routing | Separate trigger logic for must-respond alerts (custom criteria, not just severity label) | PagerDuty Events API v2 | Scoped integration key, single service, stored in Falcon credential store |
| Orchestration layer | Receives the webhook, enriches the detection (host, device, tenant), groups bursts (same user + rule, 30-min window) | AWS Lambda (Python) behind a Function URL; S3 for grouping state and archive - no API Gateway, no DynamoDB (volume does not justify them) | IAM role -> Secrets Manager injection; no env vars in code, no keys on disk |
| Falcon API enrichment | Pulls full detection + device context via the unified Alerts API (`/alerts/v2`) | REST, OAuth2 client credentials | Long-lived secret exchanged immediately for a 30-min bearer token; read-only scopes (Alerts-Read, Hosts-Read) |
| Claude triage agent | Applies verdict logic in a locked order - software-approval lens, then bypass-pattern lens, then known-pattern lens - and emits the fixed report schema | Anthropic API, locked system prompt, `max_tokens` capped | Scoped API key (`/v1/messages` only), stored in the credential store, rotated on schedule |
| Slack delivery | Posts the rendered report to the security channel | Incoming webhook | Webhook URL scoped to one channel (#security-alerts) |
| Archive | Every report persisted for audit and for the recurring coverage/repeat-behavior digest | S3 (12-month retention) | Same Lambda IAM role, write-only to the archive prefix |
| Local dev runner | Same triage agent runnable from the analyst workstation against pulled detection JSON | Python + 1Password CLI | `op run --env-file .env.op` - secrets injected as ephemeral env vars, `op://` references only on disk |

## Design decisions

- **Human-in-the-loop, always.** The pipeline produces verdicts, not actions. Automated containment on a false positive can take down a production system - so every report lands in front of an analyst, and response actions (Phase 3) will sit behind an explicit approval step until verdict accuracy is validated over time.
- **Read-only API scopes by default.** The Falcon key holds Alerts-Read and Hosts-Read, nothing else. Any write or remediation call requires a separate, explicitly reviewed credential and a security gate. The Anthropic key can only create messages; the Slack webhook can only post to one channel. Least privilege at every hop.
- **Detection-first philosophy.** Prompt injection is a real concern in an LLM triage pipeline: attacker-controllable strings (command lines, filenames, domains) are treated as untrusted data, never as instructions. The system prompt is locked; the report schema is fixed; the model cannot be steered into a different output shape by detection content.
- **Multi-tenant by design.** Two Falcon tenants feed the same pipeline - Tenant-A (~800 workstations) and Tenant-B (~100 servers, domain controllers, finance systems). Every record is tagged with its tenant; host lookups fall back across tenants because a device can live in either.
- **Verdict logic is policy-first.** The agent decides through ordered lenses before technical analysis: is the software pre-approved (unapproved software defaults to policy-violation True Positive regardless of how benign it looks), is the user showing bypass patterns (browser -> CLI -> scripting), does it match a known pattern. This mirrors how the human analyst actually triages.
- **Boring, cheap infrastructure.** One Lambda, a Function URL, S3 - roughly $15/month all-in including model usage (illustrative). The whole thing is disposable; the config is the asset.

## Phases

| Phase | Scope | Status |
|---|---|---|
| 1 - Report automation | Falcon-native flow: detection -> Claude analysis -> structured Slack report. Built entirely inside Fusion SOAR with outbound HTTP actions - zero servers. | **Built and running** |
| 2 - Unified alert reporting | Lambda orchestration layer: multi-tenant enrichment, burst grouping, locked report schema, S3 audit archive, recurring coverage/repeat-behavior digest (EventBridge cron). | **In progress** - multi-tenant pull, report template, and verdict schema are done; Lambda wiring and the recurring digest are being built. All infrastructure is defined in Terraform - an in-progress learning track, deliberately done as IaC rather than console clicks. |
| 3 - Supervised response actions | Falcon response actions (host containment, hash blocking) proposed by the agent, executed only after human approval. | **Planned** - gated on Phase 2 verdict accuracy validation and a dedicated security review. |
