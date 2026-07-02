---
name: hr-ad-sync
description: >
  HR -> Active Directory sync orchestrator. Handles the full monthly/quarterly cycle of
  pushing HR data from ADP feed reports into on-prem AD: Job Title, Description, Manager,
  Office attribute, and OU placement. Use whenever an ADP report / HR update arrives or the
  user says "run the HR update", "do the AD push", or "push to AD". Knows the folder
  structure, column mappings, script inventory, OU mapping, and the safe order of operations.
  Delegates remote execution to the remoting subagent (see remoting-subagent.md).
---

# ADP HR -> AD Sync (Orchestrator)

This skill is the *orchestrator* of a two-agent design:

- **This agent** owns the process: normalize -> diagnose gate -> push order -> log review.
- **The remoting subagent** (`remoting-subagent.md`) owns *how* to run it: WinRM from a Mac
  into the AD server, authenticated via 1Password `op run`.

Reference docs:
- `references/structure.md` - folder layout, script names, log locations
- `references/column-map.md` - ADP report column definitions
- `references/ou-mapping.md` - Office Location -> AD OU DN mapping

---

## How It Works

1. HR sends an ADP report (.xlsx / .csv)
2. **Normalize it** - `references/normalize_adp.py` coerces any export shape to the canonical
   feed (active-only, drop `old_` dups, email corrections on user + manager, office standardization)
3. **Diagnose it (GATE)** - `references/diagnose_feed.py <feed>` surfaces anomalies (duplicate
   rows, stale domains, un-standardized offices, Not-Found risks). Review ERROR/WARN, get
   go/no-go. Fix ERRORs (edit feed or add a normalizer fixup, re-run) BEFORE pushing.
4. Drop the normalized CSV into the `ADP UPDATE` folder (scripts auto-pick the newest .csv)
5. Run the numbered scripts in FULL order on the AD server, TEST -> review -> FULL -> review each
6. Diagnose each log; build the final changed-users workbook; organize the cycle folder

The push scripts (00-12) never change and stay config-free (`$PSScriptRoot`). The moving parts
are the normalize + diagnose pre-steps - both prebuilt and policy-driven, not per-cycle custom work.

---

## ADP Export Adaptation Policy (standard pre-step)

ADP exports do not always arrive in the same shape (classic ADP Feed Report, NetSuite-style
dumps, column reorders, headers on row 1 vs row 2). The push scripts are rigid by design - they
read by exact header name after `Select -Skip 1` and expect **line1 throwaway / line2 headers /
line3+ data**. Rather than hand-edit the file or the scripts each cycle, **always run the
normalizer first**. It is the prebuilt adaptability layer; the scripts stay untouched.

**Canonical columns the scripts require:** `Work Contact: Work Email`, `Job Title Description`,
`Reports to Email` (plus carried-along Dept/Office/Geo/name columns).

**Adapter:** `references/normalize_adp.py`
```bash
python3 references/normalize_adp.py <any_adp_export.csv> "<ADP UPDATE>/<normalized>.csv"
```
What it does automatically (the policy):
- **Header aliasing** - maps known variants to canonical names (`Email`/`Work Email` ->
  `Work Contact: Work Email`, `Job Title`/`Position` -> `Job Title Description`,
  `Supervisor Email`/`Manager Email` -> `Reports to Email`, etc.)
- **Auto-detects the header row** (blank/title row 1 or headers on row 1) and rewrites the canonical layout
- **Active-only filter** (drops Inactive/Terminated; keeps Active + Leave of Absence)
- **Skips blank-email rows**, prints a validation sample + counts

**When it needs human attention (the only case):** if a *required* column can't be mapped, it
STOPS and prints the incoming headers. Fix = add the new alias to `ALIASES` at the top of
`normalize_adp.py` (one line), re-run. That edit is the policy growing - it then handles that
shape forever after, hands-off.

**Always show the analyst the validation sample** (3 push columns + known-problem-user presence)
before placing the file and running 00.

To RUN the scripts on the server from a Mac (instead of RDP), see `remoting-subagent.md`
(WinRM + 1Password `op run` auth).

---

## The Golden Rules

1. **Always run 00 first** - backs up current AD state before anything changes
2. **TEST before FULL** - every push has a TEST (10 users) and FULL (all users)
3. **Watch the output** - every user prints live with before/after
4. **After every FULL run, check the log** - look for NOT FOUND and ERROR entries
5. **Office push (07/08) before OU move (09/10)** - always in this order
6. **OU move is always last** - never combine with attribute pushes
7. **Disabled users are never moved** - scripts 09/10 skip any account where Enabled=False and
   log `Skipped - Disabled`. Never move a user out of the Disabled Users OU. (This check exists
   because a disabled user was once accidentally moved and had to be moved back by hand.)

---

## Complete Run Order

```
(normalize -> diagnose GATE -> then:)
00  Pull AD state (backup)
01  Push Job Title       TEST -> check log -> 02 FULL
03  Push Description     TEST -> check log -> 04 FULL
05  Push Manager         TEST -> check log -> 06 FULL
07  Push Office          TEST -> check log -> 08 FULL
11  Push Department      TEST -> check log -> 12 FULL
09  Move OU              TEST -> check log -> 10 FULL   <- ALWAYS LAST (after Office + Dept)
```
All scripts live in: `C:\Users\AdminUser\Documents\HR List\ADP UPDATE\`

**Per-run scope is a choice, not a permanent setting.** Some cycles HR asks for only a subset
(e.g. Title + Description + Manager on yellow-marked rows), with Office/OU/Dept intentionally
skipped. That restriction applies to THAT run only - never disable or remove the other scripts.
The only thing ALWAYS on regardless of scope is office standardization in the normalizer.

---

## Folder Structure

```
ADP UPDATE\
├── 00_Pull-AD-State.ps1
├── 01_Push-JobTitle-TEST.ps1
├── 02_Push-JobTitle-FULL.ps1
├── 03_Push-Description-TEST.ps1
├── 04_Push-Description-FULL.ps1
├── 05_Push-Manager-TEST.ps1
├── 06_Push-Manager-FULL.ps1
├── 07_Push-Office-TEST.ps1
├── 08_Push-Office-FULL.ps1
├── 09_Move-OU-TEST.ps1
├── 10_Move-OU-FULL.ps1
├── <newest normalized .csv>            <- scripts auto-pick the newest .csv
└── Logs\
    ├── AD_State_<timestamp>.csv
    ├── 01_Push-JobTitle-TEST_<timestamp>.csv
    └── ...
```

---

## ADP CSV Format

Row 1: blank. Row 2: headers. Row 3+: data.

| Column | Header | Used for |
|--------|--------|----------|
| H | Work Contact: Work Email | User lookup - strip @example.com = SamAccountName |
| I | Job Title Description | -> Title + Description |
| K | Reports to Email | -> Manager |
| M | Office Location | -> Office attribute + OU move |

---

## Office Name Normalization

**Standardization happens in the normalizer (ALWAYS, every cycle) - `normalize_adp.py`
`std_office()`.** It strips any `Office - ` / `Office Location - ` prefix and maps
parentheticals (`United Kingdom (UK)` -> `United Kingdom`) so the feed already carries clean AD
office names. Added after a raw ADP value (`Office Location - San Carlos`) leaked into AD
verbatim through the Office push. The normalizer prints an office summary and WARNS if any
unhandled prefix survives - if it warns, add the new prefix/fixup to `OFFICE_PREFIXES` /
`OFFICE_FIXED`. Note: ADP only carries country-level labels for some sites (`United Kingdom`,
`Germany`) while AD may hold a more specific city (`London`, `Frankfurt`) - confirm before
letting the Office push overwrite the more-specific AD value.

The ADP report uses an "Office - " prefix for US/Canada offices. Sample of the mapping:

| ADP value | AD Office attribute | AD OU |
|---|---|---|
| Office - Baltimore | Baltimore | OU=Baltimore,OU=USA |
| Office - Dallas | Dallas | OU=Texas,OU=USA |
| Office - Kitchener | Kitchener | OU=Waterloo,OU=Canada |
| Office - San Francisco | San Francisco | OU=Redwood City,OU=USA <- SF maps to Redwood City OU |
| United Kingdom (UK) | United Kingdom | OU=UK,OU=Europe |
| Israel | Israel | OU=Tel Aviv,OU=Middle East |
| Japan | Japan | OU=Tokyo,OU=APAC |
| Malaysia | Malaysia | OU=APAC-Remote |
| Remote - * | Remote - * | OU=US-Remote (all US remotes) |
| Remote - Australia | Remote - Australia | OU=APAC-Remote |

Full table: `references/ou-mapping.md`.

---

## Known Problem User Patterns

Real HR feeds carry identity mismatches. Classes seen in production (users anonymized), all
handled either by `EMAIL_CORRECTIONS` in the normalizer or by the Mail-fallback lookup in the
push scripts:

| Pattern | Example | Fix |
|---|---|---|
| Wrong SAM in ADP | ADP says `user1`, AD SAM is `suser1` | Email correction in normalizer |
| Stale acquired-company domain in ADP | `user2@olddomain.com` | Remap to `user2@example.com` |
| SAM mismatch, Mail correct | ADP `user3@example.com`, AD SAM `cuser3`, AD Mail correct | Mail-fallback lookup: try SAM first, then `Get-ADUser -Filter "Mail -eq '$email'"`, update via `-Identity $adUser` (the object, not the SAM string) |
| AD Mail attribute stale/typo | old domain, `example,com` comma typo, leading space | Fix Mail attribute in AD - until fixed, manager push fails for anyone reporting to that user |
| Manager listed with stale email | 5 reports pointed at a manager's old-domain address | Email corrections apply to the manager column too, so one entry fixes everyone reporting to that person |
| Acquired-company users | AD accounts AND Mail both on the acquired domain | Not a problem - SAM and Mail lookups both work; do not "fix" them |

---

## Not Found Investigation Process

When users show as NOT FOUND in logs:

1. Cross-reference the ADP email against `AD_State_*.csv` (from script 00) - search by both SAM
   (strip @domain) and full email
2. Categories and fixes:
   - **NOT IN AD**: user genuinely missing - check with HR if they should exist
   - **SAM MISMATCH**: email exists in AD under a different SAM - ADP has wrong username
   - **WRONG DOMAIN in AD Mail**: AD Mail attribute has an old domain - update Mail attribute in AD
   - **TYPO in AD Mail**: comma instead of dot, leading space - fix Mail attribute in AD
   - **OK - MANAGER RELATED**: user exists fine, their MANAGER was not found - check manager's email
3. After fixing: add corrected users to the main ADP CSV using the same column format.
   Already-correct users will show NO CHANGE - no harm running them again.

---

## Picking Up Mid-Cycle

Check `Logs\` filenames - they tell you exactly what ran:

| Log file | Meaning |
|---|---|
| AD_State_* | Backup done |
| 02_Push-JobTitle-FULL_* | Title push complete |
| 04_Push-Description-FULL_* | Description push complete |
| 06_Push-Manager-FULL_* | Manager push complete |
| 08_Push-Office-FULL_* | Office push complete |
| 10_Move-OU-FULL_* | OU move complete - cycle done |

Always read the most recent FULL log before deciding the next step. NOT FOUND entries need
investigation, ERROR entries need immediate attention.
