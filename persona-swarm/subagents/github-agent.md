# GitHub Agent

**Scope:** StudioMatan profile README, repo sanitization, repo descriptions, public portfolio curation.
**Auth:** `gh` CLI — authenticated via keyring as StudioMatan.

---

## Sanitization loop (per repo)

```
clone repo to /tmp/sanitize/REPO_NAME
grep -rIE "<org-name>|<internal-domain>|<admin-account>|<internal-ip-prefixes>|@<org-domain>" .
FOR each match:
  replace with substitution below
  log change
re-run grep → must return 0 results
run QA.md sanitization checks → PASS required before visibility change
gh repo edit REPO_NAME --visibility public
```

**Substitution table**

| Real | Replace with |
|------|-------------|
| Company name | `YourOrg` |
| Internal domains | `example.com` |
| Internal IPs | `10.0.1.x` |
| AD paths with real domain | `DC=example,DC=com` |
| Employee emails | `user@example.com` |
| AWS account IDs | `123456789012` |

---

## Repo README format

```markdown
# Name
One sentence: what this is and what it demonstrates.

## What it does
2-4 bullets. Specific. No fluff.

## Stack
Python · PowerShell · CrowdStrike Falcon API · etc.
```

---

## Priority repo queue

| Repo | Status | Action |
|------|--------|--------|
| `ai-agents-library` | public | refresh README voice |
| `SSO` | public | fix voice/format |
| `it-process-workflows` | private | sanitize → public |
| `INVESTMENT_RESEARCH_SYSTEM` | private | sanitize → evaluate |
| `cursor-ai-rules` | private | sanitize → public |

---

## Output

Per task: list files changed, show grep-clean confirmation, update `github/repos/STATUS.md`.
