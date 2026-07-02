#!/usr/bin/env python3
"""
ADP export -> canonical AD-push feed normalizer.  STANDARD PRE-STEP for every cycle.

The push scripts (00-12) NEVER change. They read, after `Select -Skip 1`:
  - 'Work Contact: Work Email'  (user lookup)
  - 'Job Title Description'     (Title + Description)
  - 'Reports to Email'          (Manager)
and expect: line1 = throwaway, line2 = headers, line3+ = data.

ADP exports arrive in different shapes (classic ADP Feed Report, NetSuite-style dumps, etc.).
This normalizer coerces ANY of them into that canonical layout using the ALIAS policy below,
auto-detecting the header row and filtering to Active employees. Known variations run hands-off;
only an UNMAPPABLE required column stops for human attention.

Usage:
    python3 normalize_adp.py <input.csv> [output.csv]
    # writes <input>_NORMALIZED.csv next to input if output omitted
"""
import csv, sys, os, re
from datetime import datetime


def _parse_dt(s):
    for fmt in ("%m/%d/%Y %H:%M", "%m/%d/%Y %H:%M:%S", "%m/%d/%Y", "%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            return datetime.strptime((s or "").strip(), fmt)
        except ValueError:
            continue
    return datetime.min

# ---- POLICY: header aliases (lowercased, punctuation-insensitive) -------------
# Map any incoming header to a canonical feed column. Add new aliases here when a
# new export shape appears - that is the ONE place that needs editing, rarely.
ALIASES = {
    "work contact: work email": ["work contact: work email", "work email", "email", "work contact work email"],
    "job title description":    ["job title description", "job title", "title", "position", "job title desc"],
    "reports to email":         ["reports to email", "supervisor email", "manager email", "reports to"],
    "home department description": ["home department description", "department", "home department", "dept"],
    "office location":          ["office location", "adp office id", "office", "location", "adp location2"],
    "geo":                      ["geo", "adp geo id", "region"],
    "payroll name":             ["payroll name", "full name", "name"],
    "preferred or chosen first name": ["preferred or chosen first name", "first name", "legal first name"],
    "preferred or chosen last name":  ["preferred or chosen last name", "last name", "legal last name"],
    "hire date":                ["hire date"],
    "a2 - manager":             ["a2 - manager", "adp a2 manager", "a2 manager"],
}
# canonical 14-col order the proven feed uses (scripts only NEED the 3 starred,
# the rest are carried for human readability / other scripts)
CANON = ["Payroll Name","Preferred or Chosen  Name","Preferred or Chosen First Name",
         "Preferred or Chosen Last Name","Legal First Name","Legal Last Name","Hire Date",
         "Work Contact: Work Email","Job Title Description","Home Department Description",
         "Reports to Email","A2 - Manager","Office Location","GEO"]
REQUIRED = ["Work Contact: Work Email", "Job Title Description", "Reports to Email"]

# POLICY: active-only. Column that carries status + the value(s) meaning "keep".
STATUS_ALIASES = ["adp position status", "position status", "status", "employee status"]
ACTIVE_VALUES = {"active", "a", "leave of absence"}   # LOA users still hold AD accounts

# POLICY: dedupe. ADP can emit duplicate rows for one person - a current record plus a
# stale one tagged "old_" in the name (e.g. "Doe, old_Jane"). The stale row carries wrong
# title/manager/dept and, being processed last, wins the push. So: (1) drop any row whose
# name contains the literal "old_" marker, (2) collapse remaining duplicate emails keeping
# the most-recently-modified record. Caught in production (an exec title was nearly
# downgraded by a stale duplicate row).
OLD_MARKER = "old_"
LASTMOD_ALIASES = ["last modified", "date modified", "modified", "last updated"]

# POLICY: known email corrections - ADP carries stale/wrong emails for a few users whose
# AD SamAccountName + Mail differ. Remap ADP email -> the address that resolves in AD, so
# every push (Title/Desc/Manager) finds them. Add new ones as they surface in NOT FOUND logs.
EMAIL_CORRECTIONS = {
    "stale.user@olddomain.com": "suser@example.com",   # AD SAM suser, stale acquired-co email
    # NOTE: a user whose AD Mail is CORRECT but whose SAM differs does NOT belong here -
    # the push scripts handle that via Mail-fallback lookup. Do not remap those.
}

# POLICY: office standardization (ALWAYS, every cycle). ADP ships inconsistent office labels -
# most are "Office - <city>", but some carry other prefixes ("Office Location - San Carlos") or
# parentheticals ("United Kingdom (UK)"). Standardize the Office Location column to the canonical
# AD office name so the Office push (07/08) sets a clean, consistent value instead of writing the
# raw ADP string. Rule: strip any known prefix, then apply explicit fixups. "Remote - XX",
# "Sydney - AU", "Israel", "Germany", etc. pass through unchanged. Added after a raw
# "Office Location - San Carlos" value leaked into AD verbatim via the push.
OFFICE_PREFIXES = ("Office Location - ", "Office - ")
OFFICE_FIXED = {
    "united kingdom (uk)": "United Kingdom",
}

def std_office(v):
    v = (v or "").strip()
    for p in OFFICE_PREFIXES:
        if v.lower().startswith(p.lower()):
            v = v[len(p):].strip()
            break
    return OFFICE_FIXED.get(v.lower(), v)


def _norm(s): return re.sub(r"[^a-z0-9]+", " ", (s or "").lower()).strip()

def _detect_header_row(rows):
    """Return index of the row that is the real header (handles blank/title row 1)."""
    flat = {a for al in ALIASES.values() for a in al}
    for i, row in enumerate(rows[:5]):
        normed = {_norm(c) for c in row}
        if normed & flat:        # this row contains recognizable headers
            return i
    return 0

def _build_colmap(header):
    """incoming header list -> {canonical: source_index}. Returns (map, status_idx, unmapped_required)."""
    norm_hdr = [_norm(h) for h in header]
    colmap, status_idx = {}, None
    for canon_key, al in ALIASES.items():
        for a in al:
            if a in norm_hdr:
                target = next((c for c in CANON if _norm(c) == _norm(canon_key)), None)
                if target:
                    colmap[target] = norm_hdr.index(a)
                break
    for a in STATUS_ALIASES:
        if a in norm_hdr:
            status_idx = norm_hdr.index(a); break
    missing = [r for r in REQUIRED if r not in colmap]
    return colmap, status_idx, missing


def normalize(inp, outp):
    with open(inp, newline="", encoding="utf-8-sig") as fh:
        rows = list(csv.reader(fh))
    if not rows:
        sys.exit("ERROR: empty input")

    h_idx = _detect_header_row(rows)
    header = rows[h_idx]
    data = rows[h_idx + 1:]
    colmap, status_idx, missing = _build_colmap(header)

    if missing:
        print("STOP - required columns could not be mapped:", missing)
        print("Incoming headers:", header)
        print("=> Add the right alias to ALIASES in normalize_adp.py, then re-run.")
        sys.exit(2)

    lastmod_idx = next((i for i, h in enumerate([_norm(x) for x in header]) if h in LASTMOD_ALIASES), None)

    staged, dropped, blank_email = [], 0, 0
    for idx, r in enumerate(data):
        if not any(c.strip() for c in r):      # skip wholly blank lines
            continue
        get = lambda canon: (r[colmap[canon]].strip() if canon in colmap and colmap[canon] < len(r) else "")
        if status_idx is not None and status_idx < len(r):
            if _norm(r[status_idx]) not in ACTIVE_VALUES:
                dropped += 1
                continue
        email = get("Work Contact: Work Email")
        email = EMAIL_CORRECTIONS.get(email.lower(), email)   # apply known corrections
        if not email:
            blank_email += 1
            continue
        row = {c: get(c) for c in CANON}
        row["Work Contact: Work Email"] = email
        # apply the SAME email corrections to the manager reference, not just the user's own
        # email, so a stale/wrong manager address is fixed automatically for everyone who
        # reports to that person (caught by diagnose_feed.py).
        mgr = row["Reports to Email"]
        row["Reports to Email"] = EMAIL_CORRECTIONS.get(mgr.lower(), mgr)
        row["Office Location"] = std_office(row["Office Location"])   # standardize office (always)
        lm = r[lastmod_idx] if (lastmod_idx is not None and lastmod_idx < len(r)) else ""
        staged.append((row, lm, idx))

    # POLICY (1): drop "old_"-tagged stale records
    old_rows = [s for s in staged if OLD_MARKER in (s[0]["Payroll Name"] or "").lower()]
    staged = [s for s in staged if OLD_MARKER not in (s[0]["Payroll Name"] or "").lower()]

    # POLICY (2): collapse duplicate emails - keep most-recently-modified (then later row)
    best = {}
    for row, lm, idx in staged:
        e = row["Work Contact: Work Email"].lower()
        key = (_parse_dt(lm), idx)
        if e not in best or key >= best[e][0]:
            best[e] = (key, row)
    dup_collapsed = len(staged) - len(best)
    kept = [v[1] for v in best.values()]

    with open(outp, "w", newline="", encoding="utf-8") as fh:
        fh.write("ADP Feed Report - normalized for AD push\r\n")   # throwaway line 1
        w = csv.DictWriter(fh, fieldnames=CANON, lineterminator="\r\n")
        w.writeheader()
        w.writerows(kept)

    print(f"OK  source={len(data)} rows  kept={len(kept)}  dropped_nonactive={dropped}  blank_email_skipped={blank_email}")
    print(f"    dropped_old_tagged={len(old_rows)}  dup_emails_collapsed={dup_collapsed}")
    if old_rows:
        for s in old_rows:
            print(f"      dropped old_: {s[0]['Work Contact: Work Email']}  name={s[0]['Payroll Name']!r}  title={s[0]['Job Title Description']!r}")
    from collections import Counter
    oc = Counter(r["Office Location"] for r in kept if r["Office Location"])
    leftover = [o for o in oc if o.lower().startswith(("office - ", "office location - "))]
    print(f"    office standardized -> {len(oc)} distinct values"
          + (f"; WARNING unhandled prefix still present: {leftover}" if leftover else "; no raw prefixes remain"))
    print(f"    header detected on source line {h_idx+1}; status filter {'ON' if status_idx is not None else 'OFF (no status col)'}")
    print(f"    output: {outp}")
    print("    sample (the 3 push columns):")
    for r in kept[:5]:
        print(f"      {r['Work Contact: Work Email']:30} | {r['Job Title Description'][:30]:30} | {r['Reports to Email']}")
    return kept


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    inp = sys.argv[1]
    outp = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(inp)[0] + "_NORMALIZED.csv"
    normalize(inp, outp)
