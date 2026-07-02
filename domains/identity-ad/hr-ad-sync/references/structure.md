# Folder Structure & Log Reference

Base: `./data/HR/`

## Per-cycle folder (one per month)
```
./data/HR/<month yy>/                    e.g. june 26/ , may 26/
├── ADP_Changed_Users_<Month><yy>.xlsx   <- FINAL deliverable (changed users, old/new, highlight on real change)
├── ADP_Update_Summary_<Month><yy>.md    <- summary
├── reports/                             <- raw export + normalized feed used this cycle
└── logs/                                <- FULL push logs + ADP_Push_FullLog_<Month><yy>.xlsx
    └── partial/                         <- TEST logs (kept, tucked away)
```
Keep every TEST + FULL log. Only true intermediates (preview renders, helper scripts,
duplicate downloads, superseded transforms) get removed.

## Server (AD box, driven via the remoting subagent)
```
C:\Users\AdminUser\Documents\HR List\ADP UPDATE\
├── 00_Pull-AD-State.ps1
├── 01..12  (TEST/FULL pairs: Title, Description, Manager, Office, Department; 09/10 OU move)
├── <newest normalized .csv>            <- scripts auto-pick the newest .csv here
└── Logs\                               <- every run writes a timestamped CSV log
```

## Tooling (skill references/)
- `normalize_adp.py` - Phase 1: any export -> canonical feed (aliases, active-only, drop old_
  dups, EMAIL_CORRECTIONS on user + manager, office standardization)
- `diagnose_feed.py` - Phase 2: pre-flight anomaly gate
- `column-map.md` / `ou-mapping.md` - column definitions + Office -> OU mapping

## Log column reference
**Title / Description logs:** `SamAccountName, DisplayName, Old<Attr>, New<Attr>, Status`
Status: `Updated | No Change | Not Found | Error: <msg>`

**Manager log:** `UserEmail, DisplayName, OldManager_InAD, NewManager_FromADP, Status`
Status: `Updated | No Change | Not Found | No Manager in ADP`

**Office log:** `SamAccountName, DisplayName, OldOffice_InAD, NewOffice_FromADP, Status`
