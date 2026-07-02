# POLICY

## Agent lifecycle

### Creation
A new agent is created only when ALL of these are true:
- Incoming task doesn't fit any active agent's scope
- Active agent count < 6
- The scope gap will recur (not a one-off task)
- Orchestrator approves

New agent must define before activation:
- `name`, `scope` (one sentence), `input`, `output`, `policy_refs`
- Added to `registry.json` with status `active`
- Reviewed after first 3 uses — retire or keep

### Retirement
Mark agent `inactive` when:
- Not used for 30 days
- Scope fully covered by another active agent (merge, don't duplicate)
- Active count exceeds 6 (retire LRU)

Inactive agents stay in `registry.json`. They can be reactivated.
Inactive agents are never deleted.

### Merge
If two agents overlap >60% in scope, merge into one.
Keep the agent with the broader scope. Archive the other.

---

## Content policy

All content produced by any agent must:
- Pass QA.md before delivery
- Contain zero company names, internal domains, internal IPs
- Match the voice in `design/brand-guide.md`
- Be specific (tool names, real techniques) — no vague claims

---

## Scope limits

Agents do not:
- Publish or push anything without explicit user approval
- Access systems outside the local Persona project directory
- Store credentials or API keys
- Create new agents autonomously (requires orchestrator + user approval)

---

## Max active agents: 6
