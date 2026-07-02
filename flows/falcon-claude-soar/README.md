# falcon-claude-soar

An always-on first analyst: every CrowdStrike Falcon detection is auto-triaged by a Claude agent that loads the same triage skill and policy rules a human uses, and posts a structured verdict report to Slack in under a minute. A human reviews every verdict before anything acts - the pipeline replaces the waiting and the writing, not the judgment. Start with [`architecture.md`](architecture.md); it is the centerpiece.

## Files

| File | Purpose |
|---|---|
| [`architecture.md`](architecture.md) | Topology, component/auth table, design decisions (outbound-only, read-only scopes, prompt-injection handling, human gate), phase status |
| [`report-format.md`](report-format.md) | The locked analyst report schema - verdict-first line, EDR-action column, grouped indicator tables, copy-paste console status line |
| [`justification.md`](justification.md) | The business case - deliberately not volume-led: speed, documentation, consistency, coverage (illustrative numbers) |

## Status

| Phase | Status |
|---|---|
| 1 - Report automation (Falcon-native, Fusion SOAR, zero servers) | Built and running |
| 2 - Unified alert reporting (Lambda + S3 archive, Terraform, recurring digest) | In progress |
| 3 - Supervised response actions (contain/block, human approval required) | Planned - gated on Phase 2 accuracy validation |

The triage logic and policy gates come from [`../../domains/security-falcon/`](../../domains/security-falcon/); credentials follow [`../../rules/secret-handling.md`](../../rules/secret-handling.md).
