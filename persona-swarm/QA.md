# QA

Runs after every agent output. Orchestrator triggers this before delivery.

---

## Sanitization checks (hard fail — must fix before delivery)

- [ ] No company names (your employer's names, current and past)
- [ ] No internal domains (your internal domains)
- [ ] No internal IPs (10.x, 172.16-31.x, 192.168.x)
- [ ] No internal hostnames or AD paths (`DC=`, `OU=` with real orgs)
- [ ] No employee names (other than Matan)
- [ ] No AWS account IDs, ARNs, or instance-specific identifiers

---

## Voice checks (soft fail — flag and suggest fix)

- [ ] No banned phrases: passionate, leverage, synergy, "I'm excited to announce", "let me know in the comments"
- [ ] No bullet overload (max 5 consecutive bullets)
- [ ] First sentence works standalone
- [ ] Reads naturally aloud — no AI sentence patterns
- [ ] Specific (tool names, real outcomes) — not vague

---

## Format checks (by output type)

**LinkedIn post**
- [ ] No emojis
- [ ] 1-3 hashtags at end only
- [ ] Under 1300 characters for short posts
- [ ] No direct CTA ("contact me", "follow me")

**GitHub README**
- [ ] Has: one-liner, what it does, how to use (or: what it demonstrates)
- [ ] No internal references in code examples
- [ ] Sample data replaces real data

**Project write-up**
- [ ] Client/org described generically ("a media company", "a fintech client")
- [ ] Outcomes stated without internal-only metrics

---

## QA loop

```
run checks
IF all hard checks pass AND < 3 soft flags → PASS
IF any hard check fails → FAIL → return to agent with specific issue
IF ≥ 3 soft flags → FAIL → return to agent with flags listed
IF FAIL after 2nd attempt → escalate to user
```

---

## Log

Each QA run appends one line to `qa-log.json`:
`{ "date", "agent", "output_type", "result", "flags" }`
