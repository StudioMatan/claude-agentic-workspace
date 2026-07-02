#!/usr/bin/env python3
"""One push step in a SINGLE process = one op run = one auth prompt.
Runs a server .ps1, finds the newest matching log, fetches it back.

Usage (inside op run):
  op run --env-file .env.op -- ./.venv/bin/python references/step.py \
      <remote_ps1> <log_prefix> <local_dest_dir>

  <remote_ps1>   full server path to the .ps1 (use "" to skip running, just fetch)
  <log_prefix>   log basename prefix, e.g. 05_Push-Manager-TEST
  <local_dest>   local folder to drop the fetched log into
Prints the local path of the fetched log on the last line.
"""
import os, sys
from pypsrp.client import Client

REMOTE_LOGDIR = r"C:\Users\AdminUser\Documents\HR List\ADP UPDATE\Logs"

def client():
    return Client(os.environ["AD_HOST"], username=os.environ["AD_USER"],
                  password=os.environ["AD_PASS"], ssl=False, auth="negotiate", port=5985)

def main():
    remote_ps1, prefix, dest = sys.argv[1], sys.argv[2], sys.argv[3]
    c = client()
    if remote_ps1:
        print(f"--- running {remote_ps1} ---")
        wrapper = (
            "function global:Read-Host { param([Parameter(ValueFromRemainingArguments=$true)]$a) return '' }\n"
            f". '{remote_ps1}'\n"
            "Remove-Item function:\\Read-Host -ErrorAction SilentlyContinue\n"
        )
        out, streams, had_err = c.execute_ps(wrapper)
        if out: print(out.rstrip())
        if had_err:
            for e in streams.error: print("ERROR:", e)
    # newest log matching prefix
    find = (f"Get-ChildItem '{REMOTE_LOGDIR}\\{prefix}*.csv' | "
            "Sort-Object LastWriteTime | Select-Object -Last 1 -ExpandProperty Name")
    name, _, _ = c.execute_ps(find)
    name = (name or "").strip()
    if not name:
        sys.exit(f"No log found for prefix {prefix}")
    remote = f"{REMOTE_LOGDIR}\\{name}"
    local = os.path.join(dest, name)
    c.fetch(remote, local)
    print(f"[OK] fetched -> {local}")
    print(local)

if __name__ == "__main__":
    main()
