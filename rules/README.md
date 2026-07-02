# rules

Always-on policy files. The two-tier split that makes an always-on agent workspace scale:

- **Rules = always-on policy.** Loaded into every session, no trigger needed. Small, terse, non-negotiable: how secrets are handled, what never goes into a commit. Every line here costs tokens on every task, so they stay lean.
- **Skills = on-demand capability.** Loaded only when a task matches their description. They can be long because they cost nothing until invoked.

Policy is ambient, capability is lazy-loaded. The [orchestrator map](../orchestrator/) routes to skills; rules constrain how anything is done regardless of which skill is doing it.

## Files

| File | Purpose |
|---|---|
| [`secret-handling.md`](secret-handling.md) | The flagship file of the repo. The `op run --env-file` pattern (vault -> pointer file -> ephemeral env injection -> credentials-agnostic script), the mandatory short-lived-token rule, and an "honesty about limits" section that states plainly what these controls do NOT achieve - a process that uses a secret can read it; the controls shrink exposure and add audit, nothing more |
| [`data-sanitization.md`](data-sanitization.md) | The pre-commit/pre-publish scrub: corporate identifiers, internal IPs, paths, and account IDs that never enter a public commit, plus the replacement standards |

Meta-point: this repo was sanitized using the rule it ships. Every file here passed the grep-for-corporate-identifiers sweep that `data-sanitization.md` prescribes.
