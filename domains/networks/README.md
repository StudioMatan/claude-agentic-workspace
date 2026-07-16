# networks

Network assessment done read-only-first: a credentialed skill that can log into a branch-office firewall but is procedurally incapable of changing it, built to feed a firewall-to-cloud-managed-network migration.

## What's here

| File / folder | Purpose |
|---|---|
| [`firewall-policy-review/SKILL.md`](firewall-policy-review/SKILL.md) | Read-only Juniper SRX config/state review over SSH for the SRX-to-Meraki MX migration: policies, NAT, VLANs, routing, DHCP, session load |
| [`firewall-policy-review/references/`](firewall-policy-review/references/) | `srx-master.exp` (SSH ControlMaster bootstrap, password entered once from `op run` env) and `srx.exp` (one-shot show-command runner) |

## Highlights

- **Credentialed but never state-changing.** The skill holds a real login to a production firewall, yet the discipline is absolute: `show` commands only, never `configure`/`set`/`commit`/`request`. The expect scripts are the enforcement point - they only ever send what they're given, so the rule lives in the skill and is stated where the commands are built.
- **One password prompt per session.** An SSH ControlMaster socket (30-minute persist) turns interactive password auth into a single `op run` injection; every subsequent query rides the socket with no re-auth. Includes the earned gotcha: Unix sockets cap at ~104 path characters, so the socket lives at `$HOME/.fw.sock`.
- **Assessment output is migration fuel.** The review captures exactly what the replacement design needs - rule-base and its default policy (a default-permit is a finding, not a footnote), NAT, BGP peering, DHCP scopes with stale DNS servers, unused services, session headroom - and redacts reversible Junos `$9$` keys and SNMP communities before anything touches disk.

Credentials follow the `op run` pattern in [`../../rules/secret-handling.md`](../../rules/secret-handling.md) - the same never-on-disk posture as every other credentialed skill in the workspace.
