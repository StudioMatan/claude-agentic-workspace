---
name: contractor-lifecycle
description: Monthly contractor reconciliation (recurring Jira HELP ticket, "Contractor Check for <Month>"). Reconciles the vendor rosters (Vendor-A through Vendor-D) against AD OU=Contractors and produces a 3-sheet review workbook with yellow/red notes plus a SHORT ticket reply. Trigger phrases - "contractor check", a HELP ticket titled "Contractor Check", or new vendor roster xlsx files arriving.
---

# Monthly Contractor Check

Recurring Jira service request (monthly, from the HR requester). Attachments: one roster
per staffing vendor (Vendor-A, Vendor-B, Vendor-C, Vendor-D). Deliverable is the
**annotated MainCheck Excel attached back to the ticket** with a **3-line Jira comment** -
NOT a long write-up.

## The report format (fixed - do not invent new structures)

`Contractor'sMainCheck_<Mon><YY>.xlsx` with EXACTLY 3 sheets:

| Sheet | Columns | Content |
|---|---|---|
| `Contractors to AD` | Name, Email on Vendor List, Contractor, Note | every active roster entry; note+color only on problems |
| `AD to Contractors` | Name, Email, Contractor, Manager, Note | every enabled AD user of the main vendors |
| `Soon-to-Expire` | Name, Email, Contractor, Manager, EndDate, DaysLeft, Status | all expired + <=30d, sorted by DaysLeft |

Color convention (the legend posted in the ticket):
- **Yellow `FFEB9C`** = data update requirement. **Red `FFD9D9`** = missing users.
  **Red `FFC7CE`** on Soon-to-Expire = expired; yellow = expiring <=30d.
- **Noted rows sort FIRST** in every sheet: red on top, yellow next, clean rows below.
- Notes are full plain-language sentences addressed to the vendor coordinator, e.g.:
  - `Your list still shows the old legacy-brand address - the account was migrated. Please update the list to: <current email>`
  - `Email on your list does not match our records - please update to: <x>` / `Email missing on your list - please add: <x>`
  - `Name is misspelled on your list - our records show: <x>. Please correct the list`
  - `Has an active AD account but does NOT appear on your list - please confirm: still active, or should we deactivate?`
  - `Listed manager (<name>) has left the company - please provide the current manager`
  - Soon-to-Expire status: `EXPIRED <n>d ago - still on vendor list, end date needs extension` / `- not on any vendor list, review for deactivation`

Jira reply style (short - see HELP-XXXX for the reference reply):
> Notes: Yellow - data update requirement. Red - missing users - review for deactivation.
> Expiration date alerts on the last sheet.
Plus one line on anything unusual (e.g. a big cohort of lapsed dates). Attach the xlsx.

## Process

1. **Folder**: `./data/contractor-check/<Month YY>/` - save the vendor roster attachments there.
2. **Fresh AD pull** (read-only, PDC-pinned): run the merged contractor export script on
   the AD server via WinRM - use `references/pull_contractors.py` through the remoting
   subagent (one `op run` = one auth prompt):
   ```bash
   op run --env-file .env.op -- \
     python3 references/pull_contractors.py "<month folder>"
   ```
   Output: `ContractorsActiveusers-<ts>.csv` (Name, Email, UPN, ChildOU, IsMainVendor,
   Description, Manager, EndDate, CreationDate).
3. **Reconcile** - runnable as-is:
   ```bash
   python3 references/reconcile.py "<month folder>"
   ```
   Auto-detects the vendor rosters + newest `ContractorsActiveusers-*.csv` in the folder,
   handles all roster formats, writes `Contractor'sMainCheck_<Folder>.xlsx` (3 sheets,
   noted rows first). If a vendor changes their file layout the run fails loudly -
   inspect the new format and update the matching `load_*()` function, then note the
   change in "Roster format quirks" below.
4. **Review with the analyst.** They handle publishing/sharing and the ticket reply -
   give them the finished xlsx + a short draft comment. Never post or modify AD without
   explicit OK.

## Roster format quirks (verify each month - formats drift)

- **Vendor-A**: sheet `Active Roster`, header row 3 (index 2). Name col 2,
  `Date Ended` col 6 (non-empty = ended -> exclude), corporate email col 15.
- **Vendor-B**: sheet `Roster`, header row 1. `Full Name` col 5. NO email column - name match only.
- **Vendor-C**: sheet named for the month (e.g. `June 2026`) - top is a pivot; the person
  list starts after the row whose cell says `Corp Email`. Cols: 1 Resource Name, 2 Billing,
  3 Corp Email. Active = Billing in {Billable, AV, Floater}; `Deactivated` = should have NO
  enabled AD account (check they really are disabled). Many stale legacy-domain emails -
  flag yellow.
- **Vendor-D**: `Sheet1`, header row 1: First/Last Name, Corp Email, Status (only `Active` counts).

## Matching rules

- Match by email localpart first, then token-aware name match (subset / Jaccard >= 0.6 /
  SequenceMatcher >= 0.9 on sorted-token names).
- Maintain a known-alias table for cross-spelling (roster spells a name one way, AD
  another) - one dict entry per known case, never fuzzy-guess silently.
- AD vendor = immediate parent OU (`ChildOU`). Non-main OUs (smaller vendors with no
  roster) go on Soon-to-Expire with "not on any list" when expired; disabling needs
  manager confirmation, not automatic.

## Interpretation rules (learned in production)

- **Expired + still on active roster = EXTEND the date, not a leaver.** Large cohorts
  lapse together (e.g. 50+ dated the same day) - that is a stale-expiration problem;
  say so in one line.
- **Expired + off-roster / unrostered OU = disable candidate** - confirm before touching.
- Expiration reads must use the raw `accountExpires` attribute + `FromFileTime` - the
  friendly `AccountExpirationDate` property can return blank on some domains. Pin all
  reads and writes to the PDC emulator.
- Keep the final report SHORT: counts per vendor, the yellow/red legend, expiration
  headline. The Excel carries the detail.

## References

- `references/reconcile.py` - the full reconciliation + workbook writer (runnable template)
- `references/pull_contractors.py` - one-shot WinRM pull of the fresh AD export (single `op run`)
