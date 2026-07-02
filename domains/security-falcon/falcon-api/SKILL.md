---
name: falcon-api
description: Connect to CrowdStrike Falcon API to pull live detection data with real statuses. Use this skill when the analyst asks to query Falcon detections, get current alert statuses, analyze real detection data, or any task that needs fresh Falcon data. Trigger phrases: "pull from Falcon", "get real detections", "current status", "live alerts", "query Falcon", "check Falcon API".
---

# Falcon API Connector - How to Use

## What This Does
Connects to the CrowdStrike Falcon API via OAuth2 and pulls all detections with their real current status, severity, host, tactic, and behavior data. Outputs a JSON file the agent can read directly.

## Credential Setup (1Password CLI)

Credentials are stored in 1Password and injected at runtime via `op run`. The script reads only env vars - no Keychain subprocess calls, no credentials in code.

**1Password items required** (create once in your vault):

| Item name | Field | Value |
|---|---|---|
| `Falcon-Tenant-A` | username | client_id for main tenant |
| `Falcon-Tenant-A` | password | client_secret for main tenant |
| `Falcon-Tenant-B` | username | client_id for secondary tenant |
| `Falcon-Tenant-B` | password | client_secret for secondary tenant |
| `Falcon-Base-URL` | password | `https://api.crowdstrike.com` |

Create each item:
```bash
op item create --category=login --title="Falcon-Tenant-A" --vault=Vault \
    username=<client_id> password=<client_secret>

op item create --category=login --title="Falcon-Tenant-B" --vault=Vault \
    username=<client_id> password=<client_secret>

op item create --category=login --title="Falcon-Base-URL" --vault=Vault \
    password=https://api.crowdstrike.com
```

The `.env.op` file at `scripts/.env.op` maps these to env var names:

```
CS_TENANT_A_CID=op://Vault/falcon-tenant-a/username
CS_TENANT_A_SEC=op://Vault/falcon-tenant-a/password
CS_TENANT_B_CID=op://Vault/falcon-tenant-b/username
CS_TENANT_B_SEC=op://Vault/falcon-tenant-b/password
CS_BASE_URL=op://Vault/falcon-base-url/password
```

**Required Falcon API scopes per key:**
- `Alerts - Read` (unified replacement for the retired "Detections - Read" scope)
- `Hosts - Read` (used for device enrichment)
- `Incidents - Read` (corpus analysis - optional)

## Running the Pull

```bash
cd ./scripts/
op run --env-file .env.op -- ../.venv/bin/python falcon_pull_detections.py
```

`op run` resolves the `op://` secret references in `.env.op` and injects them as env vars before Python starts. One Touch ID at `op signin`; silent for the rest of the 30-minute session.

Output: `falcon_alerts_BOTH_<timestamp>.json` + `falcon_devices_BOTH_<timestamp>.csv` in the same folder. The script:
- Reads credentials from env vars injected by `op run`
- Calls the unified Alerts API: `/alerts/queries/alerts/v2` + `/alerts/entities/alerts/v2`
- Filters to `product:'epp'` - endpoint detections only, all severities, all statuses
- Writes JSON with live status (new / in_progress / closed / ignored) as of pull time

## Falcon API Base URLs by Region
| Region | Base URL |
|---|---|
| US-1 (default) | https://api.crowdstrike.com |
| US-2 | https://api.us-2.crowdstrike.com |
| EU-1 | https://api.eu-1.crowdstrike.com |
| US-GOV-1 | https://api.laggar.gcw.crowdstrike.com |

## What the Agent Does With the Output

Once the script runs, the agent will:
1. Read the JSON and extract real status breakdown (closed, in_progress, new, ignored)
2. Identify which detections are genuinely open vs. already triaged
3. Generate a full detection report (see Report Generation below)

## Report Generation

After every pull, always generate a detection report automatically. Follow these rules exactly.

### Scope
- **Primary focus:** all `new` and `in_progress` alerts - these need action
- **Closed/ignored:** skip unless a pattern is notable or explicitly asked for

### Report Header
```
## Falcon Detection Report - YYYY-MM-DD

Pull source: falcon_alerts_BOTH_<timestamp>.json
Total alerts: N (N Tenant-A + N Tenant-B)
Open alerts: N
```

### Per-Case Format

One section per open alert, ordered newest first:

```
### CASE N: username - Short Description (SEVERITY)

Verdict: True Positive / False Positive (type) - plain language explanation

[2-3 sentence explanation of what happened, what the user was doing, why it matters or doesn't]
```

Then tables - ALL tables must be inside triple-backtick code blocks for Slack monospace rendering. Use fixed-width ASCII with `|` separators and `-` dividers. Keep columns narrow enough to read without horizontal scrolling.

**Detection table (always include):**
```
Detection  | Time (UTC)           | Process           | Rule           | CS Action
-----------|----------------------|-------------------|----------------|------------------
1          | YYYY-MM-DD HH:MM:SS  | process name      | rule name      | Detect only / Process killed
```

**DNS table (include when DNS indicators present - group by category):**
```
Domain                    | Type   | Notes
--------------------------|--------|---------------------------
example(.)com             | A      | Intel-flagged / Piracy / Work
```

**Network table (include when network connections present):**
```
Remote IP              | Port | Attribution
-----------------------|------|------------------
1(.)2(.)3(.)4          | 443  | AWS / Fastly / Unknown
```

**Process chain (include when parent/grandparent chain is relevant):**
```
grandparent (user)
  └── parent (user)
        └── triggering process (user)
              /full/path/to/binary
```

Then recommendations as a bullet list (max 3), then the Falcon status one-liner:

```
**Falcon status (copy-paste):**
`TP/FP - [Verdict]. [Process] resolved/executed [IOC], matched [rule]. [N] detections, [action]. [Root cause]. [Action taken or recommended].`
```

### Formatting Rules
- Defang all domains and IPs in the report body: dots replaced with `(.)`
- Tables inside code blocks - never raw markdown tables in the body
- Use `-` for dashes, never `--`
- Keep Falcon status one-liner to 2-3 short sentences max
- Do not add management/escalation language - this is the analyst's own documentation

### Verdict Logic
Apply the software approval policy before calling FP:
- Non-OS, non-managed software with no pre-approval = TP (policy violation) even if benign
- Know the business context - e.g. at an ad-tech org, bulk domain resolution of advertising sellers/publishers is normal business activity
- Intel domain matches from business-tooling scripts are high-FP-rate - check cmdline and parent for business context before calling TP

## Security Notes
- Credentials live in 1Password only - never in files, env, or code at rest
- `op run` injects secrets ephemerally as process env vars - they exist only for the duration of the Python process
- Output JSON contains detection content - stored outside Git (`.json` is gitignored)
- Rotate API keys every 90 days - update the 1Password items on rotation, `.env.op` references do not change

## Key Files
- Script: `scripts/falcon_pull_detections.py`
- Env refs: `scripts/.env.op` (gitignored via `.env.*` rule)
