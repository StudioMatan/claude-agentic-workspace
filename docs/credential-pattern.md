# The Credential Pattern: Vault -> Pointer File -> Env Injection -> Short-Lived Token

How scripts in this workspace get secrets without ever containing, reading, or persisting one. Standalone teaching doc - the enforcement version lives in `rules/secret-handling.md`.

## The problem

A script that reads its own secrets is a single point of failure. If the script is compromised, the attacker gets both the logic and the keys. And once one script reads a keychain directly, every script does, and rotation means touching all of them.

## The architecture: separation of concerns

Three things need to exist, and they must be separate components:

1. **The secret itself** - lives in a vault, never on disk in plaintext
2. **A pointer to the secret** - a reference file that says *where* the secret lives, not *what* it is
3. **The code** - reads an environment variable, completely unaware of the vault

```
1Password vault (secret lives here, audited, rotated in one place)
        |
        | op://Employee/api-tenant-a/password  <- address only, not the value
        v
.env.op file (pointer file - safe to read, gitignored, never committed)
        |
        | op run --env-file .env.op -- python script.py
        v
Process environment (secret injected ephemerally before Python starts)
        |
        | os.environ.get("API_SEC")
        v
Python script (reads a variable, knows nothing about vaults or keychains)
        |
        | POST /oauth2/token -> short-lived bearer token
        v
API calls (long-lived secret already discarded from memory)
```

## What .env.op actually is

A plain text file with one line per secret the script needs:

```
API_TENANT_A_CID=op://Employee/api-tenant-a/username
API_TENANT_A_SEC=op://Employee/api-tenant-a/password
API_BASE_URL=op://Employee/api-base-url/password
```

Left side: the variable name the script will reference. Right side: the address of the secret inside 1Password - vault name, item name, field name.

The file contains zero actual secrets. It is a lookup table. Safe to have on disk. Never commit it anyway (gitignore via `.env*`).

When you run `op run --env-file .env.op -- python script.py`, the 1Password CLI reads this file, fetches the real values from the vault, and injects them as temporary environment variables before Python even starts. The script never sees the reference file or the vault. It just sees variables that already have values.

## Why this beats reading a keychain in code

| Risk | Keychain subprocess in the script | 1Password op run |
|---|---|---|
| Process table visibility | The keychain lookup command is visible to any process | Secret injected before the process starts, never in args |
| Audit trail | None | Every read logged in 1Password activity |
| Rotation | Update each script + keychain entry separately | Update the 1Password item once, all scripts pick it up |
| Credential logic in code | Yes - subprocess calls baked into the script | No - the script is credentials-agnostic |
| Accidental commit risk | Code with subprocess calls can expose entry names | `.env.op` has only addresses, never values |

## The short-lived-token rule

Never use the long-lived secret (client_id/client_secret, API key) for the actual work. Exchange it for a short-lived token immediately, then discard the secret from memory:

- CrowdStrike: POST /oauth2/token -> 30-minute bearer
- Azure/Entra: MSAL -> access token (60-90 min)
- AWS: STS AssumeRole -> session credentials (1-12 hrs)

The script uses only the short-lived token for all subsequent calls. If someone captures memory mid-run, they get a token that expires - not the master key.

## Production end-state

The local vault pattern is the dev-time stand-in. For deployed workloads, the secret should not live where the agent or human runs at all: managed vault (AWS Secrets Manager, HashiCorp Vault) accessible only by a scoped IAM role / workload identity. The agent invokes the workload and receives results - never the secret.

## Honest limits

A process running as the user can, in principle, read any secret that user can read. This pattern reduces exposure surface, adds consent and audit, and shortens credential lifetime - it does not make a usable secret unreadable to the process using it. Do not claim otherwise.

## Vocabulary

- **Environment variable** - key-value pair injected into a process's memory before it starts; children inherit it, disk never sees it
- **Ephemeral secret** - exists only for the duration of a process run, then gone
- **op run** - 1Password CLI command that resolves vault references and injects them as env vars
- **.env.op** - a reference file containing only `op://` addresses, never actual secrets
- **Short-lived token** - a derived credential (bearer, session token) with fixed expiry, exchanged from a long-lived secret
- **Separation of concerns** - vault holds secrets, reference file holds addresses, code holds logic
- **Single rotation point** - the secret lives in one place, so rotating it updates all consumers automatically
