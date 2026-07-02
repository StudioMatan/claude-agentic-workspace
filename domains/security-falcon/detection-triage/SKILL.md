---
name: falcon-detection-triage
description: Triage CrowdStrike Falcon detection JSON exports. Invoke when the analyst says "analyze the json", "check last detection", or otherwise asks to triage a Falcon detection export. Produces a structured per-case report (verdict, table, recommendations, Falcon console status line) and applies the software-approval policy before assigning FP.
---

# Falcon Detection Triage Skill

Operational workflow for triaging CrowdStrike Falcon detection JSON exports across both tenants.

## When to invoke
- The analyst says: "check last json", "analyze the json", "triage the detection".
- A detection JSON path is dropped into the conversation.
- Working in the detections export folder.

## Workflow

### 1. Locate the JSON
- Default to the latest file by modification date in `./data/detections/`.
- Naming pattern: `detections_YYYY-MM-DDTHH_MM_SS.sssZ.json`.
- Multiple files same day = related batches for one ongoing incident.

### 2. Structural pass
- Confirm list vs dict (dict often wraps under `resources`).
- Total count, severity / tactic / technique / disposition breakdown.
- User + host breakdown: who, on what, how many times.
- Split IoA (kill/block) vs IoC (detect-only). The gap is where risk lives.

### 3. Per-user / per-case deep dive
Extract for each detection:
- `user_name`, `device.hostname`, `device.platform_name`, `device.external_ip`, `device.local_ip`
- `filename`, `filepath`, `cmdline`, `parent_details`, `grandparent_details`
- `pattern_disposition_description` (what Falcon did)
- `mitre_attack[*].tactic` / `technique` (T-codes)
- `global_prevalence` / `local_prevalence` (drives the software-approval check)
- DNS domains and network destinations (group by category: piracy, work, personal)
- `context_timestamp` for timeline

### 3.5 IOC Enrichment (when indicators are present)

When the detection contains file hashes, IPs, URLs, or domains - enrich before writing the verdict. Check each indicator against the relevant services below.

**Which service covers which IOC type:**

| IOC Type | Services |
|---|---|
| File hash (MD5 / SHA256) | VirusTotal, ANY.RUN, Hybrid Analysis |
| IP address | VirusTotal, AbuseIPDB, AlienVault OTX |
| URL | VirusTotal, URLhaus, PhishTank, ANY.RUN |
| Domain | VirusTotal, AlienVault OTX, URLhaus |

**What to extract per service:**
- **VirusTotal** - detection ratio (e.g. 12/72 engines), community score, first/last seen, file type, tags, malware family names
- **ANY.RUN** - verdict (malicious/suspicious/clean), behavior category, C2 domains/IPs contacted, MITRE techniques observed in sandbox
- **Hybrid Analysis** - threat score, malware family identified, sandbox environment results
- **AlienVault OTX** - pulse count (how many threat feeds flagged it), threat categories, linked malware families, geographic origin
- **AbuseIPDB** - confidence of abuse %, ISP, usage type (datacenter vs residential), total report count
- **URLhaus** - status (online/offline), threat type (malware_download/botnet_cc), associated malware family
- **PhishTank** - in database (yes/no), verified phish status, target brand being impersonated

**Include in the report when enrichment returns any positive result:**
- One summary line: `VirusTotal: 8/72 · AbuseIPDB: 87% confidence · OTX: 3 pulses`
- Any malware family names identified across services
- Any C2 infrastructure surfaced
- If any service confirms malicious: verdict is always TP regardless of other context - do not downgrade based on policy lens alone

**When all services return clean:** note it explicitly - "IOC checked across VT/OTX/AbuseIPDB: clean" - this supports an FP verdict.

### 4. Apply policy lenses BEFORE the technical verdict

**Software approval lens (always run first):**
1. Is the binary OS-native or a known managed corporate tool (EDR agent, M365, email gateway, MDM, org-deployed agents)? -> proceed on technical merits.
2. Otherwise is it on a published approved list? (No published list exists today -> default deny.)
3. Check `local_prevalence`:
   - `unique` or low + non-OS vendor -> **TP (policy violation - unapproved software, single-user Shadow IT)**. Recommend user conversation.
   - Fleet-wide + plausibly enterprise-standard (Dell/HP OEM driver, Microsoft, Adobe) -> note "vendor OEM / confirm fleet approval; whitelist if approved".
4. Never call FP solely because the software is from a "legitimate vendor".

**Bypass-pattern lens:**
- Tool-switching by same user (browser -> CLI -> scripting) = intentional circumvention -> TP, prioritize.
- Repeat detections post-notification = behaviour escalation -> TP, monitor for technique change.

**Known-pattern lens:**
- Servarr / Plex / TrueNAS-on-port-XXXX -> piracy automation (TP policy violation, IOA already in place).
- `osascript`+`sh` with random echo / known C2 domain -> ClickFix phishing chain.
- Privacy browsers, personal mesh VPNs (Tailscale) -> privacy-bypass IOA group (TP policy violation).

### 5. Falcon API access (canonical credential)

Credentials live in a 1Password vault, injected via `op run --env-file .env.op`. Scripts read only `os.environ` - no subprocess or Keychain calls.

**1Password items:**
- `Falcon-Tenant-A` - main tenant, ~800 hosts, client_id `a1b2c3d4...` (workstations). username = client_id, password = client_secret.
- `Falcon-Tenant-B` - secondary tenant, ~100 hosts, client_id `e5f6a7b8...` (servers/DCs/finance). username = client_id, password = client_secret.
- `Falcon-Base-URL` - API base URL. password = `https://api.crowdstrike.com`.
- A device missing from one tenant may live in the other - check both before concluding it does not exist.

**Endpoint to use:** the unified `/alerts/queries/alerts/v2` + `/alerts/entities/alerts/v2`. The legacy `/detects/queries/detects/v1` returns 404 (decommissioned by CrowdStrike). Required scope on the key: **Alerts - Read**.

**Run script with:**
```bash
op run --env-file .env.op -- ../.venv/bin/python script.py
```

**Script pattern (read env vars only):**
```python
import os

def falcon_creds(cid_var, sec_var):
    return os.environ.get(cid_var), os.environ.get(sec_var)

def base_url():
    return os.environ.get("CS_BASE_URL", "https://api.crowdstrike.com").rstrip("/")
```

## Report format (per case)

```
### CASE N: username - Short Description (SEVERITY)

Verdict: True Positive (type) / False Positive (type) - plain-language summary

[Explanation paragraph - what the user/process was doing and why it matters]

| Detections | Time (UTC) | Process | Rule | CrowdStrike Action |
|---|---|---|---|---|
| count | time range | process name | rule name | what Falcon did |

[DNS/network table grouped by category if relevant]

[Recommendations - bulleted]

**Falcon Status:** TP/FP - One-liner summary. Action taken. Next step.
```

After every case, ALWAYS provide a `Falcon status (copy-paste):` block ready to paste into the Falcon console detection status field. Format:
`TP/FP - [Verdict]. [Process] resolved/executed [IOC], matched [rule name]. [X] detections, [action]. [Root cause]. [Action taken]. [Next step].`

## Output style
- Hyphens `-` for dashes. Never `--`.
- Defang malicious / suspicious domains: `example-c2(.)com`. Don't defang internal / clearly-benign domains.
- Concise. Stop at the report unless the analyst asks for more.

## Slack handoff template
When the analyst needs to escalate software-approval questions to Security/IT admins (typical with unapproved-software TPs), produce a short Slack-ready block:

```
Hi Security / IT Admins,

Falcon flagged [N] [technique] detection(s) today on [platform] endpoints. Sharing for approval review.

[per detection:]
- Host (User) - Software name
  - Binary: <filename>
  - SHA256: <hash>
  - Prevalence: <local prevalence / fleet context>
  - Question: is <product> approved? If yes, please whitelist. If no, I'll reach out to the user.

Disposition: [block / detect-only]. No follow-on activity / suspicious behaviour.
Awaiting your call on approval status before I close in Falcon.

Thanks
```

## Linked files
- Policy: `../software-approval-policy.md` (hard policy - applied before any FP verdict).
- Methodology: `../triage-workflow.md` (report format, detections vs leads, multi-tenant pattern).
- IOA inventory: `../custom-ioa-management.md` (rule groups + lifecycle).
