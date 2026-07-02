# cloud

The cloud slice of the workspace: AWS incident-response forensics plus Entra ID identity governance. Deliberately smaller than the endpoint domain - cloud work here is IR support and identity plumbing, not platform engineering.

## What's here

| File | Purpose |
|---|---|
| [`aws-volume-forensics-runbook.md`](aws-volume-forensics-runbook.md) | Hands-on EBS forensics procedure: detach a suspect volume, mount it read-only on a clean investigation host, examine, document |
| [`azure-sso-review.md`](azure-sso-review.md) | The SSO onboarding gate: every app through Entra ID, security approval, least-privilege grants, quarterly review |

## Highlights

- **Never trust the compromised OS.** The forensics runbook examines a suspect volume from a clean host, mounted `ro,noexec,nosuid,nodev` - snapshot before touching anything, handle dirty journals with `norecovery`/`noload` so even the filesystem replay can't write. Chain-of-custody thinking throughout, derived from a workflow actually run repeatedly, not theory.
- **Never trust the app's own auth.** The SSO review gate routes every application through Entra ID with security sign-off, assigned-users-only, and a naming convention - and treats OAuth consent as the real risk surface: the SSO itself is harmless, the API permissions the app asks for are not.
- Both docs are the same posture applied to different layers: default-deny plus documented exceptions.

The forensics runbook pairs with [`../../docs/credential-pattern.md`](../../docs/credential-pattern.md) - same explain-the-why-after-the-how style.
