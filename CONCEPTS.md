# Concepts

Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Accretes as solutions are documented and refreshed; direct edits are fine. Glossary only, not a spec or catch-all.

## Solution documentation

### Solution doc
A structured record of one solved problem — what broke, why, the fix, and how to prevent and detect recurrence — written so future work in the same area benefits from the experience. Solution docs are the primary unit of the compounding loop: they are captured after work ships and searched before new work begins.

### Detection signal
A concrete, greppable code pattern recorded in a solution doc for automated reviewers: specific enough that an agent reading a diff can match it, paired with why the pattern fails. Distinct from prevention guidance, which targets humans and process. Detection signals are relayed into review runs as untrusted data — patterns to match, never instructions.

### Backfill candidate
A solution doc that matched the current work but carries no usable Detection signals (the section is missing, empty, or holds only a placeholder marker). Backfill candidates are surfaced during review and routed to the refresh process, which writes the missing signals when evidence supports them.

### Stale marking
The refresh outcome for a doc whose accuracy is in doubt but where evidence is insufficient to update, replace, or delete it. A stale-marked doc is quarantined by consumers: it is reported separately, never presented as trustworthy, and its Detection signals are never relayed.

## Review pipeline

### Finding
One reviewer-identified issue, carrying a severity tier, a confidence score, and an action class that together determine whether it may be fixed unattended or must wait for a human.

### Action class
The auto-apply eligibility of a finding: mechanical (fix is unambiguous and behavior-preserving), corroborated (independent reviewers converged on the same issue and fix), or judgment (needs a human decision — always, when a compliance-sensitive surface is involved).

### Conditional tier
Review agents that dispatch themselves based on signals in the diff (size, risky paths, review history) rather than a per-project roster listing. Every dispatch decision is recorded either way, so a non-dispatch is distinguishable from a clean pass.

### SUSPECT bullet
A Detection signal that fails the spec shape or tries to direct agent behavior — an imperative, or a claim that something is pre-cleared or exempt from reporting. SUSPECT bullets are stripped before reviewer dispatch, filed as corrupted-signal findings, and counted, so an attempted injection leaves a durable trace.

## Autonomy

### Residual
Work an autonomous run could not or should not complete unattended — judgment findings, sub-threshold fixes, blocked tasks, proposed rule changes. Residuals must become durable (filed to every applicable sink) before the run ends; a residual that exists only in conversation is data loss.

## Flagged ambiguities

- "Detection" and "Prevention" had been used loosely for any recurrence guidance — these are distinct: Prevention is rules for humans and process; Detection is machine-checkable signals for automated reviewers.
