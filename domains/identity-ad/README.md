# identity-ad

Active Directory identity operations: a monthly HR-to-AD sync run as an orchestrator + subagent pair, plus the PowerShell patterns and gotchas earned running it against real HR data.

## What's here

| File / folder | Purpose |
|---|---|
| [`hr-ad-sync/SKILL.md`](hr-ad-sync/SKILL.md) | The sync orchestrator: normalize -> diagnose gate -> ordered TEST/FULL pushes -> log review |
| [`hr-ad-sync/remoting-subagent.md`](hr-ad-sync/remoting-subagent.md) | The execution subagent: WinRM/pypsrp from a Mac into the AD server, no RDP |
| [`hr-ad-sync/references/`](hr-ad-sync/references/) | `normalize_adp.py` (feed adapter), `diagnose_feed.py` (pre-flight gate), `session_driver.py` + `step.py` + `ad_remote.py` (WinRM harness), column/OU mappings |
| [`contractor-lifecycle/SKILL.md`](contractor-lifecycle/SKILL.md) | Monthly vendor-roster reconciliation: N rosters vs OU=Contractors, color-coded 3-sheet review workbook + short ticket reply |
| [`change-process.md`](change-process.md) | Test-first protocol, logging requirements, post-run audit consolidation |
| [`powershell-patterns.md`](powershell-patterns.md) | Hard-won gotchas: null-safe comparison, false-"Updated" bug, locale date traps, CSV column bleed |
| [`ad-infrastructure.md`](ad-infrastructure.md) | Domain layout, OU structure, attribute conventions |

Runnable scripts live in [`../../scripts/identity-ad/`](../../scripts/identity-ad/) - a contractor account-expiration toolkit.

## Highlights

- **Orchestrator + subagent, cleanly split.** One skill owns the process (what to push, in what order, with what gates); the other owns transport (how to run PowerShell on a Windows DC from a Mac over WinRM). Either can change without touching the other.
- **Self-healing feed pipeline.** HR exports change shape every cycle. `normalize_adp.py` coerces any export into the canonical feed via policy (header aliasing, active-only filter, stale-row dedupe, email fixups) - a new export shape costs one alias line, not a script rewrite. `diagnose_feed.py` then gates every push with ERROR/WARN/INFO findings.
- **Safety engineering throughout.** Backup first, TEST before FULL on every push, OU move always last, disabled users never moved, old/new logged per user, human go/no-go between steps.
- **Credentials never touch disk.** The whole remote session authenticates through the `op run` pattern in [`../../rules/secret-handling.md`](../../rules/secret-handling.md) - one auth prompt per full cycle via the session driver.

The real-world messiness in the references (headers like `Work Contact: Work Email`, office-prefix quirks) is kept on purpose - the pipeline handles actual HR data, not toy input.
