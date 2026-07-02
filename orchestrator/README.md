# orchestrator

The routing layer of the workspace. [`agent-map.md`](agent-map.md) is the artifact: a sanitized copy of the always-on router that every production security/IT session starts by reading. It is the most load-bearing file in the system - and deliberately the tersest.

## The hybrid model

Four layers, each with its own loading policy. The design problem is that always-on context is paid for in every session, so this is cache-hierarchy thinking applied to agent context: hot, warm, cold.

1. **Master router (always-on, one file).** A terse map from task types to skills, rules, and data locations. Pointers only, never procedure. No matter how many skills exist, every session pays for exactly this one map plus the rules.
2. **Per-domain orchestrators.** Larger projects (the [SOAR pipeline](../flows/falcon-claude-soar/), the [HR-AD sync](../domains/identity-ad/hr-ad-sync/)) carry their own orchestrator/state files. The router points at them; they hold live state - current step, what's built, what's blocked. A session resumes a project by reading its orchestrator first.
3. **On-demand skills.** Procedure lives in skills that load only when their description matches the task. The description IS the dispatch mechanism, so descriptions are written sharp and non-overlapping.
4. **Reference layer (never auto-loaded).** Role profiles, archives, bulk project data - referenced by path, never loaded wholesale.

## Lifecycle policy

- Every new repeatable process gets captured as a skill.
- Every new skill gets one registration line in the router - that single line is all it takes to become reachable.
- Stale or duplicated content gets trimmed on sight.

The invariant: no duplicated truth. The map holds pointers, skills hold procedure, data folders hold state. When a workflow changes, exactly one file changes.

This is a production pattern running daily, not a design sketch. The rules the router keeps always-on live in [`../rules/`](../rules/); the domains it dispatches into are under [`../domains/`](../domains/).
