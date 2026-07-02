# User-Device Mapping

Companion method note to the device-correlation skill: the compact rules for
resolving the verified owner behind every device.

## Goal

For every device, determine its verified owner. Join on **serial**
(EDR <-> ITSM <-> MDM) and **email** (-> HR feed / AD / contractor roster).

## Sources

- EDR - CrowdStrike Falcon (both tenants): hostname, serial, last_login_user, sensor health
- ITSM - InvGate asset export: serial -> owner email
- MDM - Meraki Systems Manager: serial -> owner "Name <email>" + EDR tag
- HR feed (ADP): email -> name / title / dept / GEO (employees)
- AD active users + contractor roster

## Resolution rule (do NOT violate)

Attach an owner only if verifiable in the **HR feed or the contractor roster**.
Never invent an identity from an unverified EDR login string. Reconcile ITSM vs
MDM email: legacy brand-domain aliases (same local-part, different domain) = same
person; different local-parts = a real conflict. An EDR `last_login_user`
resolves an owner only when it maps to a known HR/contractor person.

## Owner types

Employee | Contractor (roster, not HR feed) | IT-shared (`it@example.com`) |
Ex-identity/Unknown (no roster match) | Conflict (ITSM != MDM, two real people) |
Infrastructure (server/DC) | Unassigned.

## Output

A multi-sheet workbook: Workstations, Servers & DCs, Needs Review, Contractors,
No EDR Coverage, All Devices. Built by the device-correlation pipeline from
exports in `./data/sources/`.

## Reliability note

Sensor reduced-functionality state via API is unreliable (can read "healthy"
while silently broken after an OS upgrade). Treat ownership as solid; treat
EDR-coverage status as needing on-host confirmation.

## Last run (snapshot, approximate)

~1,100 devices; ~900 employee-owned; single-digit true contractors; ~190 with no
EDR sensor; ~46 needs-review (conflicts + ex-identities). The mapping held ~97%
against the EDR's own last-login user.
