# Falcon Triage Workflow

The methodology behind every detection triage session - report style, investigation order, data-type awareness, multi-tenant handling, and enrichment.

## Report Writing Style

- Use `-` for bullet points, never `--` for dashes in prose
- Keep verdicts on the first line: `True Positive (policy violation) - description`
- Explain technical terms in plain language when first introduced (e.g. "Plex (self-hosted Netflix for streaming)")
- When presenting detection tables, ALWAYS include a "CrowdStrike Action" column showing what Falcon did (process killed, detected only, etc.)
- Group DNS/network tables by category (Plex, TrueNAS, Work, Personal), not raw per-domain lists
- Note collateral impact when browser-helper kills affect work tabs too
- When explaining tools/concepts, give the plain explanation first, then the security relevance
- Don't over-analyze beyond what was asked - give the report, stop. If the analyst wants more they'll ask

## Investigation Approach

- Always work step-by-step, one command at a time - never dump all info at once
- Start with structure and counts, then drill into specifics based on findings
- Separate what was blocked vs what passed through - the gap is where risk lives
- Look for user behavioral patterns: persistence, escalation, tool-switching = intent
- When analyzing a detection JSON, first give a quick overview (total, by user, by severity, by rule), then dig into each case separately

## Detection JSON Analysis Workflow

1. Find the latest export in `./data/detections/` by timestamp
2. Quick overview: total count, by user, by severity, by rule, by disposition, time range
3. Per-user deep dive: device info, DNS domains, network destinations, cmdlines, process chain
4. Cross-reference with previous exports only if relevant patterns emerge (repeat offenders)
5. Present the report per case with the standard table format

**Standard detection report format:**

```
### CASE N: username - Short Description (SEVERITY)

Verdict: True Positive (type) - what happened in plain language

[Explanation paragraph - what the user was doing and why it matters]

| Detections | Time (UTC) | Process | Rule | CrowdStrike Action |
|---|---|---|---|---|
| count | time range | process name | rule name | what Falcon did |

[DNS/network table grouped by category]

[Recommendations as bullet list]

**Falcon Status:** TP/FP - One-liner summary. Action taken. Next step.
```

**Falcon console status line:**
After every detection analysis, ALWAYS provide a short one-liner status ready to paste into the Falcon console detection status field. Format: `TP/FP - [Verdict]. [Process] resolved/executed [IOC], matched [rule name]. [X] detections, [action]. [Root cause]. [Action taken]. [Next step].` Keep it to 2-3 short sentences.

**Example:**
`TP - Policy violation. Chrome Helper resolved sentry(.)servarr(.)com, matched Custom IOA "Servarr - Piracy Automation Suite" rule. 36 detections, all process killed. Activity caused by Chrome sync via shared personal Google/Apple ID. User spoken to, advised to separate profiles. Monitoring.`

## Detections vs Automated Leads

Two different data types requiring different investigation approaches:

| | Detections | Automated Leads |
|---|---|---|
| What triggers them | A specific rule or ML model fires on a single event | Falcon AI correlates multiple weak signals across time on a host |
| Granularity | One detection = one event (process, file, network) | One lead = pattern of behaviors over hours/days |
| Confidence | High - specific rule matched | Lower - "looks suspicious when combined" |
| Score | Severity (Low/Med/High/Critical) | Numeric score (higher = more suspicious) |
| Content | Process tree, cmdline, hashes, DNS | Threat graph indicators, MITRE mappings |
| Disposition | Shows what Falcon did (killed, detected, etc.) | Pattern disposition 0 often = nothing blocked |
| Key field | `pattern_disposition_description` | `is_closed` (True = Falcon auto-dismissed) |

**Automated leads triage priority:**
1. Open leads (`is_closed: false`) first - Falcon hasn't dismissed these
2. High score (>= 50) closed leads - sanity check even if auto-closed
3. Hosts with multiple leads across time = recurring suspicious behavior, higher priority
4. Pattern disposition 0 across all indicators = nothing was blocked, needs attention

**Automated leads are noisy by design.** Signal-correlation AI generates significant alert fatigue. Most leads don't result in actionable investigations. Focus on the open ones and high-score ones.

## Multi-Tenant Awareness

The environment has TWO CrowdStrike tenants (both in a 1Password vault, injected via `op run --env-file .env.op`):
- **Tenant A** - env: `CS_TENANT_A_CID` / `CS_TENANT_A_SEC` - ~800 hosts, workstations.
- **Tenant B** - env: `CS_TENANT_B_CID` / `CS_TENANT_B_SEC` - ~100 hosts, servers/DCs/finance.
- Both use `CS_BASE_URL` (`https://api.crowdstrike.com`).

**IMPORTANT:** Devices may exist in either tenant. If a device_id returns 404 or a hostname search returns empty in the primary tenant, ALWAYS check the secondary tenant before concluding the device doesn't exist.

```python
import os
from falconpy import Hosts

def cs_client(ServiceClass, cid_var="CS_TENANT_A_CID", sec_var="CS_TENANT_A_SEC"):
    return ServiceClass(client_id=os.environ.get(cid_var),
                        client_secret=os.environ.get(sec_var),
                        base_url=os.environ.get("CS_BASE_URL", "https://api.crowdstrike.com"))

def cs_client_tenant_b(ServiceClass):
    return cs_client(ServiceClass, "CS_TENANT_B_CID", "CS_TENANT_B_SEC")

def find_host(hostname):
    """Try primary tenant first, then secondary."""
    hosts = cs_client(Hosts)
    q = hosts.query_devices_by_filter_scroll(filter=f"hostname:'{hostname}'", limit=5)
    if q['status_code'] == 200 and q['body'].get('resources'):
        return hosts, q['body']['resources']
    hosts_b = cs_client_tenant_b(Hosts)
    q2 = hosts_b.query_devices_by_filter_scroll(filter=f"hostname:'{hostname}'", limit=5)
    if q2['status_code'] == 200 and q2['body'].get('resources'):
        return hosts_b, q2['body']['resources']
    return None, []
```

## IOC Enrichment

When a detection contains file hashes, IPs, URLs, or domains, enrich them against these services before writing the verdict. A confirmed malicious IOC from any service = TP regardless of other context.

### Services by IOC type

| IOC Type | Services to check |
|---|---|
| File hash (MD5 / SHA256) | VirusTotal, ANY.RUN, Hybrid Analysis |
| IP address | VirusTotal, AbuseIPDB, AlienVault OTX |
| URL | VirusTotal, URLhaus, PhishTank, ANY.RUN |
| Domain | VirusTotal, AlienVault OTX, URLhaus |

### What to extract per service

- **VirusTotal** - detection ratio (e.g. 12/72), community score, first/last seen, malware family tags
- **ANY.RUN** - verdict (malicious/suspicious/clean), behavior category, C2 contacts, MITRE techniques in sandbox
- **Hybrid Analysis** - threat score, malware family, sandbox verdict
- **AlienVault OTX** - pulse count, threat categories, linked malware families, geographic origin
- **AbuseIPDB** - confidence of abuse %, ISP, usage type (datacenter vs residential), report count
- **URLhaus** - status (online/offline), threat type (malware_download/botnet_cc), associated malware
- **PhishTank** - in database, verified phish, target brand being spoofed

### Report format when enrichment returns results

Include a summary line in the report:
`VirusTotal: 8/72 · AbuseIPDB: 87% confidence · OTX: 3 pulses`

Then list: malware family names, C2 infrastructure surfaced, any brand being impersonated.

When all services return clean, state it explicitly: `IOC checked: VirusTotal / AbuseIPDB / OTX - clean. Supports FP.`

### IP geolocation (always run for external IPs)

```python
import requests

def check_ip(ip):
    geo = requests.get(f'http://ip-api.com/json/{ip}?fields=country,regionName,city,isp,org,as,hosting').json()
    shodan = requests.get(f'https://internetdb.shodan.io/{ip}').json()
    return geo, shodan
```

Key signals:
- `hosting: True` = datacenter/VPS, not residential - more suspicious for a workstation
- `hosting: False` = residential ISP - expected for remote workers
- Residential ISPs local to the employee's region are expected for remote workers

## Detection Triage Priority

1. **Bypass attempts first:** Users switching tools (browser -> CLI -> scripting) to reach same target
2. **Repeat offenders:** High detection count per user = intentional, not accidental
3. **System-level noise last:** `_mdnsresponder`, `root` processes are secondary DNS artifacts from user activity

## Policy Violation Response

- Status answer format: Verdict, trigger, evidence, recommendation (5-7 lines)
- Always distinguish between policy violation (user behavior) vs actual threat (malware/exploit)
- For policy violations: recommend user conversation before escalation
- For user notification on blocks: Fusion SOAR + Slack/Teams (preferred) or RTR script (alternative)

## Analyst Posture and Escalation

- Reports are the analyst's own documentation trail, not management-facing
- Do NOT add "alerts left visible for management review" or similar - that's implicit
- Post-notification repeat offenders: note "behavior continues post-notification", monitor for technique escalation, triage as TP

## Scope Discipline

- **Stay focused on the current JSON/task.** Historical data should only be referenced when explicitly asked for, and must be clearly labeled as historical - never mixed into current investigation context.
- When asked about "today's detections," only analyze files from today.
- If historical context is relevant, say: "From the [date] detections (historical):" to clearly separate it.

## Known Piracy/Policy Violation Patterns

### Servarr Tools (Sonarr, Radarr, Prowlarr, Lidarr, Readarr, Bazarr)
- Exclusively piracy automation tools - zero legitimate enterprise use
- Typically not installed on the endpoint - they run on home servers, accessed via browser over direct IP:port
- Custom IOA kills the browser helper process, but the user can just refresh - process kill loop
- DNS indicators: `*.plex.direct`, `pubsub(.)plex(.)tv`, `sentry(.)ixsystems(.)com` (TrueNAS)
- Network indicators: connections to ports 32400 (Plex), 8989 (Sonarr), 7878 (Radarr), 9696 (Prowlarr)
- Browser-helper kills also disrupt legitimate work tabs (Teams, Atlassian, etc.) - note as collateral
- Cannot be fully blocked technically (private IP access) - requires user conversation / HR enforcement

### ClickFix Attacks
- Social engineering: user tricked into pasting commands into Terminal
- Attack chain: phishing lure -> osascript/sh execution -> C2 domain callback
- Indicators: `osascript` + `sh` with suspicious cmdlines (e.g. `echo $((RANDOM % ...))`)
- If all stages blocked: host is clean, notify user about phishing awareness
- Check email for the lure source

## IoC vs IoA Disposition

- **IoA (Indicator of Attack):** Can block/kill process - this is the enforcement layer
- **IoC (Indicator of Compromise):** Domain/IP/hash indicators - typically detect-only, does NOT block DNS resolution
- DNS resolution happens before process kill - IoC detect-only entries are expected alongside IoA blocks
- To block DNS itself, need network-level control (DNS sinkhole, firewall, Falcon Firewall Management)

## Ongoing Incident Updates

When multiple JSON batches relate to the same ongoing incident:

1. **Compare against prior batches:** Same host? Same domain? Same method? Note what changed vs what didn't
2. **Consolidate counts:** "Adding 65 new detections (40 + 25) to the existing 40"
3. **Update format** - append to existing write-up, match tone/structure:
   - New session timestamps and detection counts
   - Method change or lack thereof ("same method - direct browser navigation, no technique change")
   - Controls status ("controls remain effective")
   - Post-notification status if user was already spoken to
4. **Key escalation indicators to watch for across batches:** tool-switching (browser -> CLI -> scripting), bypass attempts, increased frequency, new domains

## Date Format Standard

- ALL data exports and scripts use MM/dd/yyyy or ISO 8601 (yyyy-MM-dd)
- Never rely on system locale for date formatting
- Python: `strftime("%m/%d/%Y")` or `strftime("%Y-%m-%d")`

## API Security Rules

- NEVER write credentials to files, scripts, logs, or terminal output
- ALWAYS use `op run --env-file .env.op` to inject credentials - never read from Keychain in scripts
- READ-ONLY operations only unless a write action is explicitly requested
- Before any write API call, warn the analyst and get explicit confirmation
