# Secret & Credential Handling (always-on)

How the agent must obtain and use any secret (API key, client_secret, token, password, connection string) on this machine. Applies to every project unless a project rule is stricter.

## Core principle

A secret should be readable only by the smallest identity, for the shortest time, with every access logged - and the component that *holds* the secret must be separated from the component that *uses* it. Use derived, short-lived tokens; never the long-lived secret directly when a token will do.

## Credential source priority

1. **1Password CLI (`op`) via `op run --env-file`** - required for all scripts. Credentials are stored in the `Employee` vault at `yourorg.1password.com` and injected as ephemeral process env vars at runtime. The script reads only `os.environ` - no credential-reading code inside the script itself.
2. **OS keychain** - legacy fallback only for interactive one-off lookups. Do not use in new scripts.
3. **Never** a plaintext file, `.env` committed to git, hardcoded literal, or shell history.

## The op run pattern (canonical for all scripts)

Scripts never read credentials directly. A companion `.env.op` file holds only 1Password references (not secrets):

```
# .env.op - references only, safe to read, gitignored via .env.*
CS_TENANT_A_CID=op://Employee/falcon-tenant-a/username
CS_TENANT_A_SEC=op://Employee/falcon-tenant-a/password
```

`op run` resolves these references and injects the real values as process env vars before the script starts:

```bash
op run --env-file .env.op -- python script.py
```

Inside the script, read only env vars - no subprocess, no keychain calls:

```python
import os
cid = os.environ.get("CS_TENANT_A_CID")
sec = os.environ.get("CS_TENANT_A_SEC")
```

Why this is safer than subprocess keychain access:

- Secrets never pass through a child process observable by the OS process table
- Secrets live only in process memory for the run duration, then gone
- Every `op read` is logged in the 1Password activity audit log
- Rotate in one place (the 1Password item) - all scripts pick it up automatically via the reference
- The script itself contains zero credential-reading logic - it is credentials-agnostic

**1Password vault:** `Employee` at `yourorg.1password.com` (account: `user@example.com`)

## The short-lived-token rule (mandatory)

- When a long-lived secret (client_id/client_secret, refresh token, API key) can be exchanged for a **short-lived token** (OAuth bearer, STS credential, session token), do the exchange immediately and then **use only the short-lived token** for subsequent calls.
- Discard the long-lived secret from memory right after minting the token - do not pass it further down the script.
- Treat the short-lived token as the working credential. Let it expire naturally; re-mint when needed. Never extend or persist it.
- Example (CrowdStrike): read client_secret -> POST /oauth2/token -> get 30-min bearer -> use bearer for all /alerts, /devices calls -> secret is no longer referenced.

## Never persist or expose

- Never write a secret OR a token to a file, log, terminal output, commit, code comment, or error message.
- Never echo a secret to confirm it. To verify, print only length or first/last 4 chars.
- Never include secrets/tokens in data exports, screenshots, or pasted output.
- If a secret is ever printed or written by mistake, flag it immediately and recommend rotation.

## Least privilege & default read-only

- Use the most narrowly-scoped credential available (read-only over read-write; single-service over broad).
- Default to **read-only API operations**. Before any write/destructive API call, warn the user and get explicit confirmation.
- Prefer per-tenant / per-purpose keys over one all-powerful key.

## Production end-state

For deployed/automated workloads, the secret must not live where the agent or human runs. Put it in a managed vault (AWS Secrets Manager, Vault) accessible only by a scoped IAM role / workload identity; the agent invokes the workload and receives results, never the secret. The local 1Password pattern is the dev-time stand-in for this.

## On honesty about limits

A process running as the user can, in principle, read any secret that user can read. These controls reduce exposure surface, add consent + audit, and shorten credential lifetime - they do not make a usable secret unreadable. Be honest about this; do not claim a secret is "inaccessible" to a process that uses it.
