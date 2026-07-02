#!/usr/bin/env python3
"""Long-lived WinRM session driver - ONE op run = ONE auth for the whole cycle.

Launched once in the background under `op run` (creds injected into THIS process
memory only, never on disk). It then watches a control directory for command
files and executes each against a single persistent WinRM client, so subsequent
push steps need no further 1Password prompt.

Launch (background):
  op run --env-file .env.op -- ./.venv/bin/python references/session_driver.py <ctrl_dir>

Protocol (caller writes cmd_<n>.json, driver writes res_<n>.json):
  {"action":"run_fetch","ps1":"<server.ps1>","prefix":"05_Push-Manager-TEST","dest":"<localdir>"}
  {"action":"put","local":"<local>","remote":"<server>"}
  {"action":"ps","script":"<powershell>"}
  {"action":"quit"}
Driver writes res_<n>.json = {"ok":bool,"out":str,"path":<fetched local path or null>}.
Create a file named STOP in ctrl_dir (or send quit) to end the session.
"""
import os, sys, json, glob, time
from pypsrp.client import Client

REMOTE_LOGDIR = r"C:\Users\AdminUser\Documents\HR List\ADP UPDATE\Logs"

def client():
    return Client(os.environ["AD_HOST"], username=os.environ["AD_USER"],
                  password=os.environ["AD_PASS"], ssl=False, auth="negotiate", port=5985)

def run_fetch(c, ps1, prefix, dest):
    out_parts = []
    if ps1:
        wrapper = (
            "function global:Read-Host { param([Parameter(ValueFromRemainingArguments=$true)]$a) return '' }\n"
            f". '{ps1}'\n"
            "Remove-Item function:\\Read-Host -ErrorAction SilentlyContinue\n"
        )
        out, streams, had_err = c.execute_ps(wrapper)
        if out: out_parts.append(out.rstrip())
        if had_err:
            for e in streams.error: out_parts.append("ERROR: " + str(e))
    find = (f"Get-ChildItem '{REMOTE_LOGDIR}\\{prefix}*.csv' | "
            "Sort-Object LastWriteTime | Select-Object -Last 1 -ExpandProperty Name")
    name, _, _ = c.execute_ps(find)
    name = (name or "").strip()
    local = None
    if name:
        local = os.path.join(dest, name)
        c.fetch(f"{REMOTE_LOGDIR}\\{name}", local)
        out_parts.append(f"[OK] fetched -> {local}")
    else:
        out_parts.append(f"[WARN] no log for prefix {prefix}")
    return True, "\n".join(out_parts), local

def main():
    ctrl = sys.argv[1]
    os.makedirs(ctrl, exist_ok=True)
    c = client()
    # ready marker
    open(os.path.join(ctrl, "READY"), "w").write(str(os.getpid()))
    seen = set()
    while True:
        if os.path.exists(os.path.join(ctrl, "STOP")):
            break
        for cf in sorted(glob.glob(os.path.join(ctrl, "cmd_*.json"))):
            if cf in seen:
                continue
            seen.add(cf)
            n = os.path.basename(cf)[4:-5]
            res = os.path.join(ctrl, f"res_{n}.json")
            try:
                cmd = json.load(open(cf))
                a = cmd.get("action")
                if a == "quit":
                    json.dump({"ok": True, "out": "bye", "path": None}, open(res, "w"))
                    return
                elif a == "run_fetch":
                    ok, out, path = run_fetch(c, cmd.get("ps1", ""), cmd["prefix"], cmd["dest"])
                elif a == "put":
                    c.copy(cmd["local"], cmd["remote"])
                    ok, out, path = True, f"[OK] put -> {cmd['remote']}", None
                elif a == "ps":
                    o, streams, had_err = c.execute_ps(cmd["script"])
                    out = (o or "").rstrip()
                    if had_err:
                        out += "\n" + "\n".join("ERROR: " + str(e) for e in streams.error)
                    ok, path = not had_err, None
                else:
                    ok, out, path = False, f"unknown action {a}", None
                json.dump({"ok": ok, "out": out, "path": path}, open(res, "w"))
            except Exception as e:
                json.dump({"ok": False, "out": f"EXC: {e}", "path": None}, open(res, "w"))
        time.sleep(1.5)

if __name__ == "__main__":
    main()
