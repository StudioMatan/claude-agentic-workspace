# Security Agent - Orchestration Map (always-on router)

This is the production pattern, genericized. One security agent is the orchestrator: every security/IT task starts here. This file is a terse ROUTER - it says which skill/rule/project handles what and where things live. Detail lives in the skills it points to; never duplicate skill content here.

## The pattern

- **Always-on layer (kept lean):** only this map plus a small set of cross-cutting rules load into every session. Everything always-on costs context in every conversation, so it must stay terse.
- **On-demand layer:** skills load by description match when a task triggers them. The skill description is the routing key - sharp, non-overlapping descriptions are what make dispatch work.
- **Reference layer (never auto-loaded):** agent role profiles, archives of past scripts and outputs, and project data. Referenced by path when needed, never loaded wholesale.

## Where things live

- **LOCAL `~/.claude/`** (live, always-on): this map + the core rules + all active skills. Skills load on demand by description - only this map and the rules are always-on, so keep them lean.
- **Reference library** (NOT loaded): agent role profiles + `archive/` (past scripts and outputs).
- **Project data** stays in its domain folder under `./data/`, referenced - never loaded wholesale.

## Tools -> projects -> skills (use which when)

### EDR (CrowdStrike Falcon)
- `falcon-detection-triage` - triage a detection JSON ("check last json")
- `falcon-api` - pull live detections / alerts / devices from the Falcon API
- `device-master` - rebuild the device inventory workbook
- rules (always-on): falcon-incident-analysis, custom-detection-rules, software-approval-policy
- **SOAR project** (automated alert reporting):
  - `soar-project` - architecture, decisions, status of the pipeline
  - `soar-justification` - the business case / numbers
  - `user-device-mapping` - resolve device owners across EDR + asset inventory + MDM + HRIS + AD
  - data: `./data/falcon-soar/`, `./data/incidents/`, `./data/assets/`

### Active Directory / HR
- `hr-ad-sync` - push HRIS data to AD (titles, managers, OU). Includes the standard export-adaptation policy - normalizes any export shape to the canonical feed before pushing; scripts stay rigid.
- `ad-remoting` - subagent: run the push on the AD server from the workstation over WinRM, authenticated via the secrets manager (`op run`). Use instead of RDP. Host `ad-server.example.com:5985`, credential item `AD-Admin` in the vault.
- rules: ad-infrastructure, hr-ad-change-process
- data: `./data/ad/`

### Exchange / Email
- `exchange-mailbox-triage` - mailbox / sent-items / mail-gateway issues

### Cross-cutting (always-on rules, apply everywhere)
secret-handling, output-formatting, data-sanitization, language-correction, cloud-security-architect, security-agent-workflow

## Credentials
EDR: secrets vault - items `EDR-Tenant-A` (~800 workstation hosts) and `EDR-Tenant-B` (~100 server hosts). Injected via `op run --env-file .env.op`. Scripts read `os.environ` only - no keychain subprocess. Exchange the long-lived secret for a 30-min bearer token, never persist long-lived secrets. See the secret-handling rule.

## Authoring new skills (lifecycle policy)
- Cross-cutting (used everywhere) -> the global skills directory. Project-specific -> keep with the project (or global while still local-only).
- Always add the new skill to this map so the orchestrator knows it exists.
- Keep skill `description` sharp and non-overlapping - that is what actually triggers loading.

---

## Why it works (annotation for readers of this repo)

Three properties make this router scale where a monolithic system prompt does not:

1. **Constant always-on cost.** No matter how many skills exist, every session pays only for this one map plus the rules. Ten skills or a hundred - the router stays the same size.
2. **Single registration point.** A new capability becomes reachable by adding one line here. Nothing else changes; the orchestrator discovers it through the map, the runtime loads it through its description.
3. **No duplicated truth.** The map holds pointers, the skills hold procedure, the data folders hold state. When a workflow changes, exactly one skill file changes.
