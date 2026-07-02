#!/usr/bin/env python3
"""
AD remote PowerShell over WinRM. Credentials come ONLY from env (inject via op run):
    op run --env-file .env.op -- ./.venv/bin/python references/ad_remote.py <cmd> [args]

Env: AD_HOST, AD_USER (AdminUser@ad.example.com), AD_PASS  (all from 1Password).

Commands:
    test                      smoke test: identity, host, domain, AD module, sample Get-ADUser
    put <local> <remote>      copy a local file to the server
    fetch <remote> <local>    copy a server file back
    run <remote.ps1>          execute a server-side .ps1, stream stdout/stderr
    ps  "<powershell>"        run an inline PowerShell snippet
"""
import os, sys
from pypsrp.client import Client


def _client():
    host = os.environ.get("AD_HOST")
    user = os.environ.get("AD_USER")
    pw   = os.environ.get("AD_PASS")
    if not (host and user and pw):
        sys.exit("Missing AD_HOST/AD_USER/AD_PASS - run via `op run --env-file .env.op -- ...`")
    return Client(host, username=user, password=pw, ssl=False, auth="negotiate", port=5985)


def _run_ps(c, script, label=""):
    out, streams, had_err = c.execute_ps(script)
    if out:
        print(out.rstrip())
    for w in getattr(streams, "warning", []) or []:
        print("WARN:", w)
    if had_err:
        for e in streams.error:
            print("ERROR:", e)
    return not had_err


def cmd_test(c):
    checks = {
        "whoami":            "whoami",
        "hostname":          "$env:COMPUTERNAME",
        "domain":            "(Get-WmiObject Win32_ComputerSystem).Domain",
        "AD module present": "if (Get-Module -ListAvailable ActiveDirectory) {'YES'} else {'NO'}",
        "sample Get-ADUser": "try { (Get-ADUser -Identity $env:USERNAME -EA Stop).SamAccountName } catch { 'AD query failed: ' + $_.Exception.Message }",
    }
    ok = True
    for label, ps in checks.items():
        out, streams, had_err = c.execute_ps(ps)
        tag = "ERR" if had_err else "OK "
        print(f"[{tag}] {label:20} -> {(out or '').strip()}")
        ok = ok and not had_err
    return ok


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    c = _client()
    if cmd == "test":
        sys.exit(0 if cmd_test(c) else 1)
    elif cmd == "put":
        local, remote = sys.argv[2], sys.argv[3]
        c.copy(local, remote)
        print(f"[OK] put {local} -> {remote}")
    elif cmd == "fetch":
        remote, local = sys.argv[2], sys.argv[3]
        c.fetch(remote, local)
        print(f"[OK] fetch {remote} -> {local}")
    elif cmd == "run":
        remote = sys.argv[2]
        print(f"--- running {remote} ---")
        # Dot-source so $PSScriptRoot resolves to the script's folder, with Read-Host
        # stubbed to a no-op (the interactive "Press Enter" gate can't be answered over
        # WinRM; the analyst's per-step approval IS the confirmation). Script file untouched.
        wrapper = (
            "function global:Read-Host { param([Parameter(ValueFromRemainingArguments=$true)]$a) return '' }\n"
            f". '{remote}'\n"
            "Remove-Item function:\\Read-Host -ErrorAction SilentlyContinue\n"
        )
        ok = _run_ps(c, wrapper)
        sys.exit(0 if ok else 1)
    elif cmd == "ps":
        ok = _run_ps(c, sys.argv[2])
        sys.exit(0 if ok else 1)
    else:
        sys.exit(f"unknown command: {cmd}\n{__doc__}")


if __name__ == "__main__":
    main()
