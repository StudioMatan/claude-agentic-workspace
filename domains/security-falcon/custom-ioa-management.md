# Custom IOA Rule Management

Detection engineering methodology and live rule inventory for CrowdStrike Falcon Custom IOA rules.

## Rule Management Approach

- **Detection first, blocking later:** New rules start as Detect, validated in production, then escalated to Kill Process/Block Execution after confirming no false positives.
- **Audit log comments:** Every rule change must include a comment for the CrowdStrike audit trail explaining what was changed and why.
- **Platform separation:** Separate rule groups per platform (Mac, Windows, Linux).
- **Logical grouping:** Rules are grouped by use case (torrent/piracy, unauthorized apps, etc.), not by individual incident.

## Rule Groups

### 1. Block-PeerToPeer-Applications-Mac

- **Platform:** Mac
- **Status:** Enabled
- **Description:** Block peer-to-peer torrent clients on macOS devices

#### Rules in this group:

| # | Rule Name | Type | Severity | Action | Status | Regex / Pattern | Audit Comment |
|---|-----------|------|----------|--------|--------|-----------------|---------------|
| 1 | Block hebits.net - Torrent Tracker | Domain Name | High | Kill Process | Enabled | `.*hebits\.net` | Blocks torrent tracker - policy violation. Covers all subdomains |
| 2 | Detect uTorrent Execution (Mac) | Process Creation | High | **Detect** | Enabled | `.*([Tt]orrent\|[Tt]ransmission\|[Dd]eluge\|[Vv]uze\|[Ff]olx\|[Qq]bittorrent\|[Bb]itcomet).*` | Detects torrent client process creation on Mac. Pending upgrade to Block after validation |
| 3 | Detect Torrent Client Network Connections | Network Connection | High | **Detect** | Enabled | Image: `.*([Tt]ransmission\|[Uu]torrent\|[Bb]ittorrent\|[Qq]bittorrent\|[Dd]eluge\|[Vv]uze).*` / Remote IP: `.*` / Port: `.*` / TCP+UDP | Detects torrent client network activity. Pending upgrade to Kill Process after validation |
| 4 | Block Torrent Client Network Connections | Network Connection | High | Kill Process | **Disabled** | Same as #3 | Blocking version - enable after Detect version validates with no false positives |
| 5 | Block uTorrent Execution (Mac) | Process Creation | High | Block Execution | **Disabled** | Same as #2 | Blocking version - enable after Detect version validates with no false positives |

#### Piracy-automation expansion (same group):

- **Updated Process Creation rules (#2, #5)** - added piracy automation tools (Sonarr, NzbDrone, Radarr, Prowlarr, SABnzbd, Lidarr) to Image Filename regex
- **Updated Network Connection rules (#3, #4)** - same piracy automation tools added
- **Added 8 Domain Name rules** (all High severity, Kill Process, Enabled):

| # | Rule Name | Domain Pattern | Status |
|---|-----------|---------------|--------|
| 6 | Block TorrentLeech - Torrent Tracker | `.*\.torrentleech\.org` | Enabled |
| 7 | Block MyAnonaMouse - Piracy Tracker | `.*\.myanonamouse\.net` | Enabled |
| 8 | Block 4Claw - Piracy Community | `.*\.4claw\.org` | Enabled |
| 9 | Block Servarr - Piracy Automation Suite | `.*\.servarr\.com` | Enabled |
| 10 | Block Sonarr - TV Piracy Automation | `.*\.sonarr\.tv` | Enabled |
| 11 | Block Radarr - Movie Piracy Automation | `.*\.radarr\.video` | Enabled |
| 12 | Block Prowlarr - Piracy Indexer | `.*\.prowlarr\.com` | Enabled |
| 13 | Block Lidarr - Music Piracy Automation | `.*\.lidarr\.audio` | Enabled |

### 2. Block-PeerToPeer-Applications (Windows)

- **Platform:** Windows
- **Status:** Enabled
- **Description:** Block peer-to-peer torrent clients on Windows devices

| # | Rule Name | Type | Severity | Action | Status | Notes |
|---|-----------|------|----------|--------|--------|-------|
| 1 | Detect Torrent Client | Process Creation | High | Detect | Enabled | Image Filename ends with `\.exe` - Windows only |
| 2 | Block hebits.net | Domain Name | High | Kill Process | Enabled | Same as Mac group |
| 3 | Detect uTorrent Execution | Process Creation | High | Detect | Enabled | |
| 4 | Block uTorrent Execution | Process Creation | High | Block Execution | **Disabled** | |

Planned: mirror the piracy-automation regex additions (with `\.exe` suffix) and the domain rules from the Mac group.

### 3. Block-Privacy-Bypass-Applications-Mac

- **Platform:** Mac
- **Status:** Created - rules disabled pending approval from the systems/security team
- **Description:** Detect and block applications that bypass corporate network security controls such as personal VPN/mesh networks and privacy-focused browsers

| # | Rule Name | Type | Severity | Action | Status | Regex | Audit Comment |
|---|-----------|------|----------|--------|--------|-------|---------------|
| 1 | Detect Helium Browser | Process Creation | High | **Detect** | **Disabled - pending approval** | `.*[Hh]elium.*` | Helium privacy browser strips telemetry reducing security visibility. Detect only for now |
| 2 | Block Tailscale VPN | Process Creation | High | **Block Execution** | **Disabled - pending approval** | `.*[Tt]ailscale.*` | Personal mesh network that bypasses corporate firewall and network security controls |

### 4. Block-Unauthorized-Applications (Windows) - planned

| # | Rule Name | Type | Severity | Action | Regex | Audit Comment |
|---|-----------|------|----------|--------|-------|---------------|
| 1 | Detect Helium Browser | Process Creation | High | **Detect** | `.*\\[Hh]elium.*\.exe` | Unmanaged Chromium fork |
| 2 | Detect Tailscale VPN | Process Creation | High | **Detect** | `.*\\[Tt]ailscale.*\.exe` | Personal VPN/mesh network |

## Audit Log Comment Templates

Use these when updating rules in the CrowdStrike console:

- **New rule:** `New rule: [Rule Name]. [Reason]. Initial action: Detect. Created by [analyst] on [date]`
- **Regex update:** `Updated [field] regex to include [additions]. Reason: [incident reference]. Updated by [analyst] on [date]`
- **Action escalation (Detect -> Block):** `Escalated from Detect to Kill Process/Block Execution after [X days] validation with [Y] true positives and [Z] false positives. Approved by [analyst] on [date]`
- **Enable/Disable:** `[Enabled/Disabled] rule. Reason: [reason]. Changed by [analyst] on [date]`

## IOA Exclusion Design (false-positive handling)

Structured approach for creating secure, targeted IOA exclusions instead of broad ML exclusions.

**Phase 1: Incident analysis** - review detection details (host, process, command line, hash), verify legitimacy (digital signature, vendor, prevalence), identify root cause, document evidence (SHA256, certificate info, incident reference).

**Phase 2: Exclusion design** - specificity priority, most specific first:
1. Hash-based (single version only)
2. Certificate + path (if supported)
3. Path pattern + command-line keywords
4. Path pattern only (last resort)

Path pattern security:
- Require GUID/structured paths where possible
- Use character classes: `[a-f0-9-]+` not `.*`
- Include subfolder requirements: `\\Drivers\\Setup\.exe`
- Escape special regex chars: `\{` `\}` `\.`

Command-line validation:
- Include vendor-specific keywords when possible: `.*(keyword1|keyword2|keyword3).*`
- Only use `.*` (permit all) for highly-protected paths

**Phase 3: Security review checklist**
- Path is as specific as possible (GUID structure, subfolders)
- Path location is write-protected or admin-only
- Command line includes vendor keywords (or path is highly protected)
- Only excludes ONE specific IOA rule, not a broad ML exclusion
- Deployed to a test host group first
- Documentation includes the incident reference
- Audit comment is clear and concise

**Phase 4: Testing** - deploy to test group 1-2 weeks, monitor for false negatives, verify legitimate operations no longer alert, then expand to production.

**Example exclusions:**

```
# Windows Update - system-protected path
Image: .*\\Windows\\SoftwareDistribution\\Download\\Install\\.*\\WinREUpdateInstaller\.exe
Command: .*
Security: System-protected path, TrustedInstaller only

# Vendor software - structured path + keywords
Image: .*\\ProgramData\\Dell\\drivers\\[a-f0-9-]+\\.*\\Drivers\\Setup\.exe
Command: .*(RHDSetup|Realtek|media_path).*
Security: GUID structure + vendor keywords required
```

**Security considerations:**
- ML exclusions require certificate uploads - high maintenance
- IOA exclusions are path-based - easier to maintain
- Never use `.*` for both path AND command line
- Layer security: the IOA exclusion excludes one behavior, ML still scans the file

## Key Learnings

- Custom IOA rules can Kill Process (prevention) - Custom IOC rules are detect-only (no prevention capability)
- Domain Name rules kill the process that made the DNS request - the DNS resolution itself still completes (to block DNS, need a network-level sinkhole/firewall)
- Process Creation rules catch app launch; Network Connection rules catch active connections - use both for defense in depth
- Image Filename regex must NOT include `\.exe` for Mac/Linux rules; must include it for Windows rules
- Always use `.*` wildcards for subdomain coverage in Domain Name rules (e.g., `.*\.hebits\.net` catches subdomains)
- Start with Detect, validate, then escalate to Block - avoids breaking legitimate workflows
- Duplicate detect/block rule pairs are intentional: the detect version stays enabled for visibility while the block version is validated separately
