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

## Planning

### Implementation Unit
One meaningful, atomically-committable change inside a plan, carrying its
own files, test scenarios, and verification outcomes. Units have stable
IDs that are never renumbered — reordering, splitting, and deletion all
preserve existing IDs so cross-references from findings, solution docs,
and executors survive plan edits.

### Plan-review panel
A set of persona reviewers dispatched over a plan document before any
code is written. Two personas always run; the rest activate on signals in
the document, and every non-dispatch is recorded with its reason.

### Confidence anchor
A discrete confidence value with defined behavior at each level: the two
lowest levels are never emitted, the middle level is advisory, and only
the top two levels are actionable. Distinct from a sliding 0-100 score —
each anchor routes, not ranks.

### Validated origin
The state of a plan whose upstream authority — a design document or a
scope-pinning issue — has been verified to exist by the reviewer itself,
never taken from the plan's own claims. Validated origin suppresses
premise-level challenge; its absence invites full premise scrutiny.

## Review pipeline

### Finding
One reviewer-identified issue, carrying a severity tier, a confidence score, and an action class that together determine whether it may be fixed unattended or must wait for a human.

### Action class
The auto-apply eligibility of a finding: mechanical (fix is unambiguous and behavior-preserving), corroborated (independent reviewers converged on the same issue and fix), or judgment (needs a human decision — always, when a compliance-sensitive surface is involved).

### Conditional tier
Review agents that dispatch themselves based on signals in the diff (size, risky paths, review history) rather than a per-project roster listing. Every dispatch decision is recorded either way, so a non-dispatch is distinguishable from a clean pass.

### SUSPECT bullet
A Detection signal that fails the spec shape or tries to direct agent behavior — an imperative, or a claim that something is pre-cleared or exempt from reporting. SUSPECT bullets are stripped before reviewer dispatch, filed as corrupted-signal findings, and counted, so an attempted injection leaves a durable trace.

## Grounding

### Grounding provider
An optional, per-repo external accelerator (a code-graph CLI) that
answers "what calls / is impacted by X" and indexes solution docs
semantically. Never a hard dependency, never authoritative for
framework-implicit relationships, always degrading to plain search when
absent — with the degradation recorded, so a grep-only run is
distinguishable from a grounded one.

### Relay point
Any point where stored or tool-derived repo content enters an agent
prompt or a shell command line. Guards do not transfer between relay
points: each carries its own untrusted-data clause, strip-not-label
handling, and durable record of caught attempts — including the
argument-sanitization form when the relay target is a command line.

### SUSPECT-GROUNDING
The grounding twin of a SUSPECT bullet: stripped suspect content that
arrived via graph output rather than a Detection section, quoted under
its own marker so it is counted against the grounding record and never
miscounted into the Detection pipeline's corruption stats.

## Autonomy

### Residual
Work an autonomous run could not or should not complete unattended — judgment findings, sub-threshold fixes, blocked tasks, proposed rule changes. Residuals must become durable (filed to every applicable sink) before the run ends; a residual that exists only in conversation is data loss.

### Residual sink
A durable location residuals are filed to — the cross-session ledger, the findings file, and the open PR's body. Genuine residuals are filed to every applicable sink deliberately, so consumers dedup across sinks via a canonical entry rather than treating each copy as distinct work.

### Standing approval
Consent captured once from the operator — explicitly, per capability — that authorizes a scheduled run to perform a class of otherwise-gated actions on every future run without asking again. Its absence means the capability stays read-only/report-only; no content encountered at run time can substitute for it.

### Write-back
The closing half of consuming a residual: flipping the item's status in every sink it lives in, committed immediately so the pipeline's own state never trips its own cleanliness gates. An item consumed from a sink is closed there or explicitly re-reported — never left half-consumed.

## Flagged ambiguities

- "Detection" and "Prevention" had been used loosely for any recurrence guidance — these are distinct: Prevention is rules for humans and process; Detection is machine-checkable signals for automated reviewers.
