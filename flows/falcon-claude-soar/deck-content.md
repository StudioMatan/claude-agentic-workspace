# Deck content - Falcon -> Claude: Automated Detection Triage

Source of truth for `scripts/deck-builder/build_deck.py`. Edit here, regenerate the
pptx from this file - don't hand-edit slide text only in the script.

All figures are illustrative (rounded, generic, drawn from a real measurement
period but not presented as fact for any specific organization). See
`justification.md` for the full business case this deck summarizes.

---

## Slide 1 - Title

**Title:** Falcon → Claude: Automated Detection Triage
**Subtitle:** A structured verdict on every EDR detection, in under a minute - human reviews, doesn't assemble
**Footer:** CrowdStrike Falcon + Claude (Anthropic) · illustrative deployment

---

## Slide 2 - The problem

**Title:** Manual triage doesn't scale
**Subtitle:** Not a volume problem - a speed, documentation, and consistency problem

Stats row:
- **~1.5 days** — median wall-clock time, detection to close
- **<10%** — of detections get a written report
- **~30 min** — hands-on analyst time per detection reviewed

Body: Alert volume in a typical mid-size fleet is not overwhelming on its own.
The failure mode is queue latency (an alert waits for an available analyst,
not for triage to finish) and inconsistent documentation (three analysts,
three different depths of write-up, most detections closed with no record at
all). A closed detection with no report leaves nothing to query later -
no way to see repeat offenders, coverage gaps, or trend shifts.

---

## Slide 3 - Before / after (the structural comparison)

**Title:** What actually changes
**Subtitle:** Not "faster" - a different set of steps, with different owners

This is a two-path flow comparison, not a screenshot. Each path is a chain of
steps; the annotation calls out where time and effort move.

**Manual path** (analyst does every step):
1. Detection fires -> lands in queue
2. Sits until an analyst is free (queue latency)
3. Analyst manually pulls host/user/process context
4. Analyst researches indicators, applies judgment
5. Analyst writes the report by hand (or skips it)
6. Analyst posts to Slack / closes the console

**Automated path** (agent assembles, human decides):
1. Detection fires -> auto-enriched immediately (host, user, process, indicators)
2. Claude applies the same triage skill and policy lenses a human uses
3. Structured verdict report generated (locked schema, every field sourced)
4. Report posts to Slack automatically
5. Analyst reviews the verdict (accept, correct, or escalate)
6. Analyst decision is the only manual step left

**What moved:** context-gathering and report-writing shift from analyst to
pipeline. Judgment stays with the analyst - the agent proposes, it never
autonomously closes or actions a detection. The analyst's remaining step is
review, not assembly.

---

## Slide 4 - Architecture

**Title:** Architecture
**Subtitle:** Outbound-only, read-only by default, no server exposed to the internet

Simplified topology (fewer boxes than the full diagram - key components only):

1. **CrowdStrike Falcon** - detection fires (Fusion SOAR event trigger), multi-tenant aware
2. **Orchestration layer** - AWS Lambda behind a Function URL; enriches via the Falcon API, groups bursts via S3
3. **Claude triage agent** - loads the triage skill, policy rules, and locked report schema; Anthropic API, scoped key
4. **Slack + S3 archive** - structured report posts to the security channel; every report persisted for audit (12-month retention)
5. **Analyst review** - human approves before anything acts; response actions (Phase 3) remain gated behind explicit approval

Caption: All calls are outbound HTTPS from Falcon's cloud or the Lambda - no inbound ports.

---

## Slide 5 - Design principles

**Title:** Design principles
**Subtitle:** Three decisions that shape everything else

1. **Human-in-the-loop, always.** The pipeline produces verdicts, not actions.
   Automated containment on a false positive can take down a production
   system - every report lands in front of an analyst first, and response
   actions stay behind an explicit approval step.
2. **Read-only by default.** The Falcon API key holds Alerts-Read and
   Hosts-Read, nothing else. The Anthropic key can only create messages; the
   Slack webhook can only post to one channel. Any write or remediation call
   requires a separate, explicitly reviewed credential.
3. **Detection content is data, never instructions.** Attacker-controllable
   strings (command lines, filenames, domains) are treated as untrusted
   input. The system prompt is locked and the report schema is fixed, so
   detection content cannot steer the model into a different output shape.

---

## Slide 6 - Status

**Title:** Status
**Subtitle:** Honest phase breakdown - not everything here is finished

| Phase | Scope | Status |
|---|---|---|
| 1 - Report automation | Falcon-native flow: detection -> Claude analysis -> structured Slack report. Zero servers. | Built and running |
| 2 - Unified alert reporting | Lambda orchestration: multi-tenant enrichment, burst grouping, locked schema, S3 archive, recurring digest. Infra as Terraform. | In progress |
| 3 - Supervised response actions | Host containment / hash blocking, proposed by the agent, executed only after human approval. | Planned |

---

## Slide 7 - What this demonstrates

**Title:** Co-pilot for detection engineers, not autopilot
**Subtitle:** The agent proposes; a human still decides

Body: This pipeline is not about replacing a security analyst - it is about
removing the two tasks that don't need human judgment (waiting in a queue,
and writing up what was found) so the analyst's time goes to the one task
that does (deciding what to do about it).

Illustrative business case: at a typical alert volume for a fleet this size,
recovering even a fraction of the ~30 minutes of hands-on time per detection
pays for the infrastructure (~$15/month, illustrative) inside the first day
of any given month. See `justification.md` for the full breakdown - numbers
are rounded and marked illustrative throughout.

---

## Slide 8 - Closing

**Title:** Falcon → Claude
**Subtitle:** Detection triage, automated end to end - judgment stays human

- GitHub: github.com/StudioMatan/claude-agentic-workspace
- LinkedIn: linkedin.com/in/[placeholder]
