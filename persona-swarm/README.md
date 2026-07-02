# persona-swarm

The agent swarm that built this repo. Meta, but real: every file in claude-agentic-workspace was copied, sanitized, QA-swept, and documented by the agents defined here, running in parallel.

## What's here

| File | Purpose |
|------|---------|
| ORCHESTRATOR.md | Main loop: classify -> route -> output -> QA -> deliver or retry |
| POLICY.md | Agent lifecycle: gated creation, 30-day retirement, overlap merging, hard cap |
| QA.md | The quality gate every output passes - hard fails vs soft flags, retry loop |
| registry.json | Live agent registry: scope, status, usage counters |
| subagents/ | The three workers: linkedin-agent, github-agent, content-agent |

## How this repo was actually built

1. Six sanitization agents ran in parallel, one per domain - each copied sources to staging (sources stayed read-only), applied a substitution table, and self-verified with a grep sweep
2. An orchestrator-level QA pass re-swept everything independently - including the full git history, which caught a pattern file that had to be rewritten out of commit one
3. A content agent wrote the per-domain READMEs from handoff notes the sanitizers left behind
4. Nothing publishes without explicit human approval - the swarm stages, the human ships

## Why show this

Most multi-agent demos are toys. This one has a work product you can inspect: the repo you're reading. The interesting parts are the boring ones - the QA gate that blocks org identifiers, the policy that retires unused agents, the state file that lets any future session resume mid-task.
