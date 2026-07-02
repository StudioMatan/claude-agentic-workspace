# Software Approval Policy

## Core Policy
- **All software must be pre-approved (whitelisted) to be considered legitimate on a corporate endpoint.**
- "It's a real/known/legitimate vendor product" is NOT sufficient to verdict a detection as False Positive.
- Detections involving non-pre-approved software are **True Positive (policy violation)** even when the software is benign in nature.

## Verdict Rules for Detection Triage
When analyzing a Falcon (or other EDR) detection, before calling FP because the software "looks legitimate":

1. **Is the software OS-native (Windows / macOS) or a known managed corporate tool (EDR agent, Microsoft 365, email gateway, MDM, org-deployed agents)?**
   - Yes -> FP analysis can proceed on the technical merits.
   - No -> continue to step 2.

2. **Has the software been pre-approved / whitelisted by the security team?**
   - Yes -> FP analysis can proceed on the technical merits.
   - No -> **default verdict is True Positive (policy violation - unapproved software)**, regardless of how benign the software is.

3. **Prevalence check (CrowdStrike `global_prevalence` / `local_prevalence`):**
   - If the binary is used by **only one user** on the fleet -> alert and treat as unapproved Shadow IT, requires user conversation.
   - If used by **many users / fleet-wide** -> likely already organisationally accepted; flag for whitelist confirmation rather than user enforcement, but still note that no formal approval list has been published.

## Why
- No published pre-approved software list exists - so default posture is "deny unless explicitly known good".
- Users installing arbitrary "legitimate" software (printer/scanner utilities, vendor updaters, browser extensions, productivity tools) still creates supply-chain risk, increases attack surface, and bypasses procurement / security review.
- A benign auto-updater still phones home, runs as user/SYSTEM, may auto-execute downloaded binaries, and can be hijacked upstream.

## How to apply in detection reports
- Lead the verdict line with the policy lens, not the technical lens:
  - `True Positive (policy violation - unapproved software) - <vendor/product> installed without pre-approval`
- Include a short note describing what the software is and what it does (so the analyst can decide on user conversation vs whitelist add).
- Recommendation section MUST include one of:
  - "User conversation - request software justification and route through procurement / security review."
  - "Whitelist if approved" (only when prevalence is fleet-wide and the product is plausibly enterprise-standard).
- Do NOT recommend simply "add SHA256 to exceptions" without the approval-routing step.

## Examples
- **Fujitsu/Ricoh ScanSnap updater** on a single user -> TP (policy violation). Software is benign, but not pre-approved. Recommend user conversation.
- **Dell Realtek HD Audio driver installer** on a Dell laptop -> Generally an OEM-bundled driver, fleet-wide prevalence likely high. Note as "vendor OEM driver - confirm fleet prevalence; whitelist if approved", not as a user-fault policy violation.
- **Helium browser / Tailscale** -> Already covered by the Block-Privacy-Bypass-Applications IOA group. TP policy violation regardless.
- **Servarr / piracy automation tools** -> Already covered by the Block-PeerToPeer-Applications IOA group. TP policy violation + security risk.

## Linked docs
- `custom-ioa-management.md` - the IOA groups that already enforce blocks for known-bad unapproved categories (piracy, privacy-bypass).
- `triage-workflow.md` - detection report format.
