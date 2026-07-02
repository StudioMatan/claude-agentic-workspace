# Identity Resolution Ladder

How a device's owner is resolved to exactly one active person when no two tools
agree on identity format. Applied in strict order - first rung that produces a
verified roster match wins; anything that falls off the bottom is surfaced as
"needs review", never guessed.

## The ladder

1. **Exact owner email -> roster.** ITSM owner email matches an active HR/AD user
   directly. Done.
2. **Domain-alias equivalence.** The org has multiple legacy brand domains; the
   same local-part on any of them is the same person
   (`jdoe@example.com` == `jdoe@brand-b.example`). Different local-parts across
   tools = a real conflict, not an alias - flag it.
3. **Local-part alias matching.** Tools drift on the local-part itself
   (ITSM says `jdoe@`, roster says `jmdoe@`). Match only when the candidate is
   unambiguous against the roster.
4. **Unique full-name key.** Build alpha-stripped `first+last` and `last+first`
   keys from the tool's owner-name field; match only if the key is UNIQUE in the
   roster. Two employees with the same name = no match, needs review.
5. **MDM blank-owner fallback: parse the device NAME's leading tokens.**
   "Jane Doe MBP M4" -> first two tokens -> unique-name lookup -> `jdoe`. This is
   owner resolution from a human-entered name field - it is NOT hostname-based
   device matching (which stays forbidden).
6. **EDR `last_login_user` -> roster** via exact local-part or unique name - and
   only as a fallback when ITSM/MDM gave nothing. A login string that maps to no
   known person resolves to nothing; never invent an identity from an unverified
   login.

## Verification gate

An owner is attached only if the resolved identity exists in the HR feed or the
contractor roster. Everything else lands in one of the explicit buckets:

Employee | Contractor (roster, not HR feed) | IT-shared | Ex-identity/Unknown |
Conflict (two real people claim it) | Infrastructure (server/DC) | Unassigned.

## Why serial-only for devices, name-ladder only for people

- Hostnames collide (default OS names cover many machines) and drift (renames,
  re-images). Serials survive re-enrollment and re-imaging.
- Human names in owner fields are messy but verifiable against a closed roster;
  hostnames are messy and verifiable against nothing.

## Precedence and anti-double-claiming

ITSM ownership propagates across the serial join to MDM and EDR rows for the same
physical device. One serial -> at most one active owner. When two sources resolve
to two different real people, that is a Conflict row - the pipeline never picks a
winner silently.

## Reliability note

EDR sensor-health flags (reduced-functionality mode) are unreliable via API - a
sensor can read "healthy" while silently broken after an OS upgrade. Treat
ownership output as solid; treat sensor-coverage output as needing on-host
confirmation.

## Track record

Last full run: ~1,100 devices resolved, ~900 employee-owned, single-digit true
contractors, ~46 needs-review (conflicts + ex-identities). The resolved mapping
agreed with the EDR's own last-login user for ~97% of devices - the disagreements
were mostly the interesting rows (shared machines, departed users, admins).
