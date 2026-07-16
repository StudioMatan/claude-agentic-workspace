---
name: firewall-policy-review
description: SSH into the site-a Juniper SRX320 cluster (via 1Password op run) to pull config/state for the SRX-to-Meraki MX migration. Use when the analyst mentions the SRX, the office firewall, the FW project, or the network migration pack. Read-only show commands only.
---

# Firewall policy review (Juniper SRX -> Meraki MX migration)

Credentialed, read-only assessment of a branch-office firewall ahead of replacing it
with a cloud-managed appliance. The point of the skill: gather everything the migration
needs (policies, NAT, VLANs, routing, sessions) without ever being able to change state.

## Connection
- Credentials: password-manager item `op://Vault/firewall-srx/...` (username / password /
  url=host). Never on disk - injected per run via `op run --env-file references/.env.op`.
- Scripts in `references/`: `srx-master.exp` opens an SSH ControlMaster socket (password
  entered once, socket persists 30 min); reuse it with plain
  `ssh -S $HOME/.fw.sock "$SRX_USER@$SRX_HOST" '<show cmd> | no-more'` inside
  `op run --env-file references/.env.op -- bash ...`.
- The socket path must be SHORT (`$HOME/.fw.sock`) - Unix socket ~104 char limit.
- Close when done: `ssh -S $HOME/.fw.sock -O exit "$SRX_USER@$SRX_HOST"`.
- Reachable only from the office network, not from outside (an open item in the pack
  proposes a scoped VPN rule for remote access).

## Read-only discipline
Only `show` commands. Never `configure`, `set`, `commit`, `request`. Pipe long output
through `| display set | no-more`. The credential is interactive-login capable, so the
guarantee is procedural: the expect scripts only ever send `show` - keep it that way.

## The migration project
- Doc: `./data/fw-project/Network_PreMigration_Pack.docx` - the pre-migration pack for
  the SRX320 cluster -> Meraki MX cutover.
- Raw sanitized config export: `./data/fw-project/SRX_Config_Export_<date>.txt`
  (BGP keys + SNMP community redacted before it touches disk).
- Key facts to capture for any migration of this shape (pulled once, kept in the pack):
  - eBGP to the upstream ISP (local AS / peer AS, one line each)
  - WAN VLAN tags for primary and backup circuits
  - The full security-policy rule-base and its default policy (here: 5 policies with a
    default-permit - a finding in itself, flag it)
  - Source-NAT rules (here: a single rule, internal 10.0.0.0/16 -> interface)
  - DHCP served by the firewall per VLAN, including the domain name and any stale DNS
    servers handed out (here: a decommissioned resolver at 10.0.1.32 still in scope)
  - Services NOT in use (UTM/IDP), session load vs capacity (~8k of 65k), auth model
    (local only), logging destination (syslog local only - nothing off-box)
- When redacting exports: strip `authentication-key "$9$..."` (reversible Junos
  obfuscation - treat as a secret, not a hash) and SNMP community strings.

## References
- `references/srx-master.exp` - ControlMaster bootstrap, password sent once from env
- `references/srx.exp` - one-shot command runner (semicolon-separated `SRX_CMDS`)
