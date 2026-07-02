# ORCHESTRATOR

## Role
Route tasks to subagents. Enforce policy. Trigger QA. Manage agent lifecycle.

---

## Main loop

```
INPUT
  └─ classify task type
  └─ check registry.json → find active agent with matching scope
  └─ if match     → route to agent → output → QA
  └─ if no match  → see POLICY.md §creation
  └─ QA result:
      PASS → deliver to user
      FAIL → revise → QA again (max 2 retries)
      FAIL x2 → escalate to user
```

---

## Task routing

| Task | Agent |
|------|-------|
| LinkedIn post, headline, about section | `linkedin-agent` |
| GitHub repo sanitization, profile README | `github-agent` |
| Project write-up, case study, article | `content-agent` |
| Brand/voice check | QA (no agent — QA.md runs directly) |
| Unknown task type | → POLICY.md §creation |

---

## Maintenance loop

Run at session start:

```
FOR each agent in registry.json WHERE status = active:
  IF last_used > 30 days → mark inactive
  IF scope fully covered by another active agent → flag merge

IF active_count > 6 → retire least-recently-used
IF active_count < 2 → flag coverage gap to user
```

---

## Enforced rules (all outputs)

1. No company names, internal domains, internal IPs, employee names
2. Voice matches `design/brand-guide.md`
3. QA.md runs before every delivery
4. Agents operate within scope defined in `registry.json` only
5. New agent creation requires POLICY.md approval

---

## Escalate to user when

- QA fails after 2 retries
- Task scope is ambiguous between agents
- New agent creation needed (needs approval)
- No active agent covers an incoming task

---

## Session startup

1. Run maintenance loop
2. Load `persona-profile.md` + `design/brand-guide.md`
3. Ask: what are we working on?
