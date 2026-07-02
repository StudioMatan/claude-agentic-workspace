---
name: device-correlation
description: Rebuild the device-to-user master workbook by correlating four asset sources - ITSM inventory (InvGate), MDM (Meraki Systems Manager), EDR (CrowdStrike Falcon), and the HR/AD active-user roster. Invoke when the user says "update the device master", "rebuild the device list", or drops fresh inventory exports. Produces a multi-sheet workbook showing which employee owns which device and whether every device is present, and correctly owned, in every tool.
---

# Device Correlation Skill

## The problem this solves

Four tools each hold a partial, mutually inconsistent picture of a ~800-endpoint
fleet:

- **ITSM (InvGate)** - the purchasing/ownership record. Owner email is sometimes
  an alias, sometimes an IT shared account, sometimes missing.
- **MDM (Meraki SM)** - enrollment record. Owner field often blank; device names
  are human free-text ("Jane Doe MBP M4").
- **EDR (CrowdStrike Falcon)** - live sensor telemetry. Knows `last_login_user`,
  which may be an admin, a departed employee, or a service account.
- **HR/AD roster (ADP feed + AD pulls)** - who actually works here today.

Hostnames do NOT match across tools (the same laptop can be `MACBOOK-PRO-2.LOCAL`
in one tool and "Jane Doe MBP" in another - and `MACBOOK-PRO-2.LOCAL` can cover
five different machines). Naming conventions drift per tool and per year. Owner
identity has to be resolved through a fuzzy ladder, not a join. The output answers:
which active employee owns which device, is that device visible in every tool, and
what is orphaned, mis-owned, or left behind after a departure.

## Run procedure

1. **Refresh the EDR pull** so the device list is current (API, both tenants;
   credentials injected via `op run --env-file .env.op` from a password manager
   vault - the script reads `os.environ` only).
2. **Confirm latest source exports** in `./data/sources/`:
   - ITSM asset export (must contain the Owner email column - some exports omit it)
   - MDM devices export
   - AD user pulls (remote + office OUs)
   - HR feed CSV
3. **Build:** `python scripts/build_master.py` - each source is auto-picked
   newest-by-mtime, so dropping fresh exports is the only manual step.
4. **Report** the Summary counts and actionable gaps (not a row dump).

## Matching principles (DO NOT VIOLATE - these were hard-won)

1. **Devices join across tools by SERIAL only.** Serials are normalized to bare
   alphanumeric (`re.sub(r"[^A-Z0-9]","",s.upper())`) to strip slashes and
   dashes. Never match devices by hostname/device name - proven unreliable.
2. **Users resolve by owner EMAIL + FULL NAME, never by hostname.** The
   resolution ladder is in `references/identity-resolution.md`.
3. **ITSM owner is the source of truth.** Its ownership propagates to the same
   serial in MDM/EDR. A serial maps to at most ONE active user (ITSM owner wins;
   MDM/EDR identity is only a fallback when ITSM has no resolvable owner). This
   prevents double-claiming.
4. **Servers and domain controllers are NOT personal devices.** A user being the
   last login on a server does not make it theirs. Pure-EDR servers are excluded
   from per-user attribution - BUT a device in ITSM inventory with a real owner
   is kept even if the EDR mislabels it "Server".
5. **Active user list = HR feed reconciled with AD.** Drop HR users no longer in
   AD (departed); add AD users missing from HR; skip vendors, service/shared
   mailboxes (`svc_*`, office/team accounts, test users), and ended accounts.
6. **Same-machine-different-serial stays as two rows.** A device with a vendor
   service tag in ITSM but a BIOS serial in MDM/EDR is NOT auto-merged - the only
   link would be the device name, which is unsafe. Surface it for manual cleanup.

## The 5 output sheets

1. **Summary** - totals, cross-tool gaps, active-user coverage, owner mismatches,
   +added/-removed user reconciliation.
2. **ITSM Devices** - every inventory device + resolved owner + present in MDM /
   EDR (+ recency).
3. **Users** - one row per user-device: user info -> Serial -> each tool (yes/no +
   that tool's owner name) -> device status. Multi-device users flagged; users
   with no device anywhere get a `NO DEVICE` row.
4. **MDM Devices** - each MDM device -> user | EDR | ITSM.
5. **EDR Devices** - each EDR device -> user | MDM | ITSM (+ type, sensor health,
   tenant).

Color key: red = missing in that tool / owner not a current employee; amber =
needs attention (wrong ITSM owner, sensor in reduced-functionality mode, stale
check-in); green = active user; blue = multi-device.

## What to report back

- Summary counts (devices per tool, coverage, gaps).
- Owner mismatches (devices owned by `it@example.com` or an alias - fix the ITSM
  owner).
- Active users with no device anywhere (often just an alias mismatch between the
  roster local-part and the device systems).

## Roadmap: full API automation

Replace file readers with live pulls - EDR already is; MDM Dashboard API and ITSM
REST API next; HR feed stays periodic. Keep all six matching principles unchanged
(only the data-loading layer changes), default to read-only API scopes, mint
short-lived tokens, secrets stay in the vault (`op://Vault/...` references only).
