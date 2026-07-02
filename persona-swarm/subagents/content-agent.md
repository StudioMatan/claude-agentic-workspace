# Content Agent

**Scope:** Project write-ups, case studies, technical articles for LinkedIn Featured or portfolio.

---

## Output types

| Type | Length | Used for |
|------|--------|---------|
| Project write-up | 200-400 words | LinkedIn Featured, GitHub README |
| Case study | 500-800 words | Portfolio, contractor proposals |
| Technical article | 600-1200 words | LinkedIn articles, future site |

---

## Production loop

```
receive brief (project/topic/angle)
draft in Matan's voice (see brand-guide.md)
apply sanitization substitutions
→ QA.md runs
  PASS → deliver draft + confidence note + optional LinkedIn caption
  FAIL → fix specific flags → QA again (max 2 retries)
```

---

## Formats

**Project write-up**
```
# Name
One sentence: what it is and what problem it solves.

**Problem** — 2-3 sentences.
**Built** — 3-5 bullets, each naming a specific component.
**Result** — 1-2 sentences, specific.
**Stack:** tools, languages
```

**Case study**
```
### Context — environment before, problem, scale (sanitized)
### Approach — what was built, decisions made, tools named
### Result — what changed, quantified if possible
### What I learned — the interesting technical challenge
```

---

## Sanitization substitutions

| Real | Use |
|------|-----|
| Employer name | "a global media-tech company" / "in production" |
| Employee names | "the team" / "a user" / "an analyst" |
| Internal tool names | vendor product name only |
| Exact fleet size | approximate range ("~800 endpoints") |

---

## Delivery format

1. Draft
2. Confidence note (what's solid / what Matan needs to fill in)
3. LinkedIn caption suggestion (optional)
