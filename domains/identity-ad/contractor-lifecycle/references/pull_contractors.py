#!/usr/bin/env python3
"""One-shot fresh contractor pull from AD over WinRM (single op run = one auth prompt).
Puts Get-Contractors-Merged.ps1 on the server, runs it (read-only), fetches newest CSV back.

Env (injected by `op run --env-file .env.op`, references like op://Vault/ad-admin/...):
  AD_HOST, AD_USER, AD_PASS
"""
import os, sys
from pypsrp.client import Client

LOCAL_PS1 = "./data/scripts/Get-Contractors-Merged.ps1"
REMOTE_PS1 = r"C:\Scripts\contractor-check\Get-Contractors-Merged.ps1"
EXPORT_DIR = r"C:\Scripts\contractor-check"
DEST = sys.argv[1]  # local dir to drop the CSV

c = Client(os.environ["AD_HOST"], username=os.environ["AD_USER"],
           password=os.environ["AD_PASS"], ssl=False, auth="negotiate", port=5985)

# ensure export dir + put script
c.execute_ps(f"New-Item -ItemType Directory -Path '{EXPORT_DIR}' -Force | Out-Null")
c.copy(LOCAL_PS1, REMOTE_PS1)
print(f"[OK] put pull script -> {REMOTE_PS1}")

print("--- running Get-Contractors-Merged.ps1 (read-only) ---")
out, streams, had_err = c.execute_ps(f". '{REMOTE_PS1}'")
if out: print(out.rstrip())
if had_err:
    for e in streams.error: print("ERROR:", e)

# newest ContractorsActiveusers CSV
find = (f"Get-ChildItem '{EXPORT_DIR}\\ContractorsActiveusers-*.csv' | "
        "Sort-Object LastWriteTime | Select-Object -Last 1 -ExpandProperty Name")
name, _, _ = c.execute_ps(find)
name = (name or "").strip()
if not name:
    sys.exit("No ContractorsActiveusers CSV found after pull")
remote = f"{EXPORT_DIR}\\{name}"
local = os.path.join(DEST, name)
c.fetch(remote, local)
print(f"[OK] fetched -> {local}")
print(local)
