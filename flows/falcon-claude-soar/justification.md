# Business Case - Why Automate Triage

All figures below are approximate and illustrative, drawn from a real 12-week baseline measurement but rounded and genericized for publication.

## The argument is not "we are drowning"

Alert volume in this environment is low - roughly 15 EPP alerts per week across ~900 devices. Leading a business case with volume would be false and would get the project killed. The real problems are speed, documentation, and consistency:

| Pillar | Baseline (measured, ~12 weeks, illustrative) | With auto-triage |
|---|---|---|
| Speed | Median ~1.5 days wall-clock from detection to close; tail cases up to several days | Verdict-first report in under 60 seconds, every alert |
| Documentation | Under 10% of alerts got a written report | 100% - every alert produces the same structured report, archived |
| Consistency | 3 analysts, 3 different triage standards and depths | 1 expert standard, encoded once in the triage skill and applied uniformly |
| Analyst time | ~30 min hands-on per alert -> several hours/week on routine triage | Pre-triaged verdict + evidence; analyst reviews instead of assembles |
| Coverage insight | None - closed alerts left no queryable trail | Full archive enables recurring coverage and repeat-behavior analysis |

Important honesty note: the baseline "time to close" numbers are wall-clock queue latency, not analyst labor minutes. The pipeline attacks the queue (an alert waits for nobody) and the writing (the report is free), not some imaginary mountain of labor.

## What the archive unlocks

Manual triage leaves nothing behind. With every verdict logged to a locked schema, a recurring job can answer questions that were previously unanswerable:

- Which users/devices are repeat offenders, and are they escalating (tool-switching, rising frequency, continuing after being notified)?
- Where are the coverage gaps - sensors in reduced-functionality mode, detect-only rules that should be blocking, hosts that stopped reporting?
- What changed versus the prior period?

In the baseline environment, roughly a fifth of the fleet had sensors in a degraded visibility state - a fact that only surfaced because the pipeline work forced a systematic device pull. That kind of finding is the recurring report's job.

## Audit trail

Every alert, verdict, and report is persisted immutably (12-month retention). That gives:

- A defensible record of what was seen and how it was dispositioned
- Evidence for detection-rule tuning decisions (detect -> block escalations backed by measured false-positive rates)
- A training corpus for validating verdict accuracy before any response action is automated

## Cost

Illustrative: serverless infrastructure (~$8/month) plus model usage at this alert volume (~$5-7/month) - roughly $15/month total. Against even one analyst-hour per week recovered, the pipeline pays for itself in the first day of each month.
