---
name: ad-remoting
description: >
  Remote PowerShell execution from a Mac into the AD server over WinRM, authenticated through
  1Password (op run). Use whenever the HR->AD sync (or any AD PowerShell work) needs to actually
  RUN on the domain server instead of via RDP - copying the normalized CSV onto the server,
  running the numbered push scripts, and pulling logs back. Subagent of hr-ad-sync.
---

# AD Remote Execution - WinRM + 1Password (Subagent)

Subagent of the `hr-ad-sync` orchestrator. That skill owns the *process* (script order, OU
mapping, known users). THIS skill owns *how to run it from the Mac*.

The Mac cannot run `ActiveDirectory` cmdlets locally. To run the push without RDP, open a
WinRM session to the domain server, where the AD module lives, and drive PowerShell there.

---

## Connection facts

| Item | Value |
|---|---|
| AD server | `10.0.1.10` |
| Transport | WinRM **HTTP 5985**, auth `negotiate` (NTLM) - payload is encrypted even over HTTP |
| Closed | 5986 (WinRM HTTPS), 22 (SSH) - RDP 3389 open (the old manual path) |
| Account | `AdminUser@ad.example.com` |
| Domain | `ad.example.com` |
| Client lib | Python **`pypsrp`** in a venv - NOT native pwsh (macOS pwsh has no WSMan client) |
| Server script folder | `C:\Users\AdminUser\Documents\HR List\ADP UPDATE\` (00-12 push scripts + Logs\) |

---

## Authentication - 1Password only (never typed, never on disk)

Credentials live in 1Password and are injected at runtime via `op run`. The script reads only
`os.environ` - zero credential logic in code. Running `op run` pops Touch ID / the 1Password
prompt, resolves the references, injects them for the one process, then they're gone.

**1Password item:** `ad-admin` in your vault.
- `username` = `AdminUser@ad.example.com`
- `password` = the on-prem domain password

Create it once:
```bash
read -s -p "domain admin password: " PW && \
  op item create --category login --title "ad-admin" --vault Vault \
  'username=AdminUser@ad.example.com' "password=$PW"; unset PW
```

**`.env.op`** (references only - safe, gitignored via `.env.*`), lives in this skill folder:
```
AD_HOST=10.0.1.10
AD_USER=op://Vault/ad-admin/username
AD_PASS=op://Vault/ad-admin/password
```

**Run anything through it:**
```bash
op run --env-file .env.op -- ./.venv/bin/python <script>.py
```

---

## One-time setup

```bash
python3 -m venv .venv
./.venv/bin/pip install -q pypsrp
# then create the ad-admin 1Password item (command above)
```

---

## Harness scripts (in references/)

- `references/ad_remote.py` - library + CLI. Reads creds from env (`op run` injects them).
  Subcommands:
  - `test` - smoke test: whoami, hostname, domain, AD module present, sample Get-ADUser
  - `put <local> <remote>` - copy a file to the server (e.g. the normalized CSV)
  - `run <remote.ps1>` - run a server-side script, stream output back
  - `fetch <remote> <local>` - pull a log back for review
  - `ps "<powershell>"` - run an inline snippet

Smoke test:
```bash
op run --env-file .env.op -- ./.venv/bin/python references/ad_remote.py test
```

Note the `run` implementation detail: it dot-sources the server script with `Read-Host` stubbed
to a no-op - the interactive "Press Enter" gate can't be answered over WinRM, and the analyst's
per-step approval IS the confirmation. The script file itself stays untouched.

---

## Avoiding repeated 1Password prompts (use this for a full cycle)

`op run` re-authenticates on EVERY invocation, and each shell call is a fresh process - so
calling `ad_remote.py` once per action means one auth prompt per action. Two harnesses fix this:

- **`references/step.py`** - one `op run` = one prompt PER STEP. In a single process it runs the
  `.ps1`, finds the newest matching log, and fetches it:
  ```bash
  op run --env-file .env.op -- ./.venv/bin/python references/step.py \
    "C:\...\ADP UPDATE\06_Push-Manager-FULL.ps1" "06_Push-Manager-FULL" "<local logs dir>"
  ```
- **`references/session_driver.py`** - ONE prompt for the WHOLE cycle (preferred for multi-step
  runs). Launch ONCE in the background under `op run`; it holds creds + the WinRM client in
  memory and processes command files dropped in a control dir, writing result files back:
  ```bash
  CTRL=<scratch>/ad_session; mkdir -p "$CTRL"
  op run --env-file .env.op -- ./.venv/bin/python references/session_driver.py "$CTRL" &
  ```
  Then per step write `cmd_<n>.json` and wait for `res_<n>.json`:
  - `{"action":"run_fetch","ps1":"<server.ps1>","prefix":"<log prefix>","dest":"<localdir>"}` (ps1:"" = fetch only)
  - `{"action":"put","local":"<l>","remote":"<r>"}` - `{"action":"ps","script":"<powershell>"}` - `{"action":"quit"}`

  This keeps the secret in ONE process's memory for the run, no disk, one audit entry.

  **WinRM gotchas:** do NOT `fetch` large files (a ~224KB backup timed out at 30s and then
  poisoned the connection - HTTP 400 on every later command; only a session restart recovers).
  For bulk data run a compact `ps` query instead (e.g. `Get-ADUser -Filter * | ForEach {
  $_.SamAccountName + [char]9 + $_.physicalDeliveryOfficeName }` -> small TSV). Keep inline
  ps output modest.

---

## Full run flow (Title + Description + Manager example)

1. Normalize the new export -> validated CSV (show sample, get OK)
2. `ad_remote.py put <csv> "C:\Users\AdminUser\Documents\HR List\ADP UPDATE\<name>.csv"`
   (scripts auto-pick the newest .csv in the folder)
3. `ad_remote.py run "...\00_Pull-AD-State.ps1"` -> backup -> **stop, show result**
4. `01` TEST -> `fetch` log -> **stop, review** -> `02` FULL -> review
5. `03/04` Description, `05/06` Manager - same TEST -> review -> FULL -> review rhythm
6. Hunt `NOT FOUND` / `ERROR` in each log (see hr-ad-sync "Not Found Investigation")

Golden rules from the orchestrator still apply: 00 first, TEST before FULL, read every log,
OU move last, disabled users never moved.

---

## Safety

- Read-only by default. Every push is a write to AD - run TEST first, stop after each step
  for the analyst to examine the log before the FULL run.
- Never persist the credential; `op run` injection only.
- The scripts themselves contain the write logic and per-user before/after logging - don't
  bypass them with ad-hoc `Set-ADUser` calls.
