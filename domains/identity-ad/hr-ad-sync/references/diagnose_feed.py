#!/usr/bin/env python3
"""Pre-flight DIAGNOSIS of a normalized ADP feed - run at the Diagnose gate, before any push.

Surfaces the classes of problems that have bitten past cycles (duplicate/old_ rows like a
"Doe, old_Jane" record, stale acquired-company domains, blank/self managers, un-standardized
offices, unknown new locations) so the analyst gets a go/no-go picture up front.

Usage:
    python3 diagnose_feed.py <normalized_feed.csv> [ad_office.tsv] [ad_mail.tsv]
    # optional TSVs (SAM<TAB>value) from a live AD pull enable cross-checks:
    #   ad_office = Get-ADUser -Filter * -Properties physicalDeliveryOfficeName
    #   ad_mail   = Get-ADUser -Filter * -Properties mail

Exit 0 always (advisory). Findings printed grouped ERROR / WARN / INFO.
"""
import csv, sys, os, collections

KNOWN_OFFICES = {
    "Baltimore","Bellevue","Burlington","Chicago","Dallas","Kitchener","Los Angeles",
    "New York City","San Diego","San Francisco","San Carlos","Toronto","Virginia",
    "United Kingdom","Israel","Germany","Japan","Singapore","Philippines","Malaysia",
    "Sydney - AU","Melbourne - AU","Remote - Australia",
}
HOME_DOMAINS = {"example.com", "acquiredco.com"}   # acquiredco = acquired company, intentional
STALE_DOMAINS = ("olddomain.com", "legacydomain.com")  # pre-merger domains, must not survive in AD Mail

def load_tsv(p):
    d={}
    if p and os.path.exists(p):
        for line in open(p, encoding="utf-8-sig"):
            sam,val=(line.rstrip("\n").split("\t",1)+[""])[:2] if "\t" in line else (line.strip(),"")
            if sam.strip(): d[sam.strip().lower()]=val.strip()
    return d

def main():
    feed=sys.argv[1]
    ad_off=load_tsv(sys.argv[2] if len(sys.argv)>2 else None)
    ad_mail=load_tsv(sys.argv[3] if len(sys.argv)>3 else None)
    rows=list(csv.reader(open(feed, encoding="utf-8-sig")))
    hdr=rows[1]; data=[r for r in rows[2:] if any(c.strip() for c in r)]
    col={h.strip():i for i,h in enumerate(hdr)}
    E=col["Work Contact: Work Email"]; M=col["Reports to Email"]
    O=col.get("Office Location"); N=col.get("Payroll Name")
    def g(r,i): return r[i].strip() if i is not None and i<len(r) else ""

    errors, warns, infos = [], [], []

    # emails present as their own row (to know if a manager exists in the feed)
    own_emails={g(r,E).lower() for r in data if g(r,E)}

    # 1. old_-tagged rows - normalizer should have dropped; flag if any survived
    old=[g(r,N) for r in data if "old_" in g(r,N).lower()]
    if old: errors.append(f"{len(old)} 'old_'-tagged duplicate row(s) survived normalization: {old}")

    # 2. duplicate user emails
    dupe=[e for e,c in collections.Counter(g(r,E).lower() for r in data if g(r,E)).items() if c>1]
    if dupe: errors.append(f"{len(dupe)} duplicate user email(s): {dupe}")

    # 3. blank / self manager
    blankmgr=[g(r,E) for r in data if g(r,E) and not g(r,M)]
    selfmgr=[g(r,E) for r in data if g(r,E) and g(r,M).lower()==g(r,E).lower()]
    if blankmgr: infos.append(f"{len(blankmgr)} user(s) with NO manager in ADP (manager left as-is/blank)")
    if selfmgr: warns.append(f"{len(selfmgr)} user(s) list THEMSELVES as manager: {selfmgr}")

    # 4. foreign-domain emails (user + manager)
    fu=sorted({g(r,E) for r in data if g(r,E) and g(r,E).split('@')[-1].lower() not in HOME_DOMAINS})
    fm=sorted({g(r,M) for r in data if g(r,M) and g(r,M).split('@')[-1].lower() not in HOME_DOMAINS})
    if fu: warns.append(f"{len(fu)} user email(s) on foreign domain (SAM strip still works, but verify): {fu}")
    if fm: warns.append(f"{len(fm)} manager email(s) on foreign domain - must resolve in AD or reports get no manager: {fm}")

    # 5. manager email that is neither a feed user nor home-domain -> Not Found risk
    risk=sorted({g(r,M) for r in data if g(r,M)
                 and g(r,M).lower() not in own_emails
                 and g(r,M).split('@')[-1].lower() not in HOME_DOMAINS})
    if risk: warns.append(f"{len(risk)} manager(s) not present as a feed user AND foreign domain (Not Found risk): {risk}")

    # 6. office standardization residue + unknown offices
    if O is not None:
        leftover=sorted({g(r,O) for r in data if g(r,O).lower().startswith(("office - ","office location - "))})
        if leftover: errors.append(f"office prefix NOT standardized (normalizer gap): {leftover}")
        unknown=sorted({g(r,O) for r in data if g(r,O) and not g(r,O).lower().startswith("remote - ")
                        and g(r,O) not in KNOWN_OFFICES})
        if unknown: warns.append(f"unknown/new office value(s) - confirm mapping + OU: {unknown}")

    # 7. live-AD cross checks (only if TSVs supplied)
    if ad_mail:
        bad=[]
        for sam,m in ad_mail.items():
            if m and ("," in m or m!=m.strip() or m.split('@')[-1].lower() in STALE_DOMAINS):
                bad.append(f"{sam}=[{m}]")
        if bad: warns.append(f"{len(bad)} AD Mail attribute(s) malformed/stale (breaks manager resolution): {bad[:20]}")
    if ad_off is not None and O is not None:
        downgrade=[]
        for r in data:
            sam=g(r,E).split('@')[0].lower(); adp=g(r,O)
            cur=ad_off.get(sam,"")
            # AD holds a more specific city than ADP's country label
            if cur and adp and adp in ("United Kingdom","Germany") and cur.lower() not in (adp.lower(),):
                downgrade.append(f"{sam}: AD '{cur}' vs ADP '{adp}'")
        if downgrade: warns.append(f"{len(downgrade)} office precision-DOWNGRADE - AD more specific, do NOT overwrite: {downgrade}")

    # report
    print(f"DIAGNOSE  feed={feed}  active_rows={len(data)}")
    for tag,items in (("ERROR",errors),("WARN",warns),("INFO",infos)):
        for it in items: print(f"  [{tag}] {it}")
    if not (errors or warns):
        print("  [OK] no blocking anomalies. INFO items above (if any) are expected.")
    print(f"SUMMARY  errors={len(errors)} warns={len(warns)} infos={len(infos)}")

if __name__=="__main__":
    main()
