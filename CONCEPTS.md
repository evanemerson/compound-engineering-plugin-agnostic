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
A durable location residuals are filed to — the cross-session ledger, the findings file, and the open PR's body. Genuine residuals are filed to every applicable sink deliberately, so consumers dedup across sinks via a canonical entry rather than treating each copy as distinct work. The ledger is sharded per run and consumed as the union of the shards and the frozen legacy file; cross-shard duplicate reconciliation happens at the serialized trunk sweep (the single-writer context), never at append time.

### Residual shard
The per-run file a run appends its residuals to, named by date and branch identity so parallel worktree runs write to disjoint files and residual filing never merge-conflicts. The naming function maps the branch name onto a strict character allowlist as an injection guard — branch names arrive from resolved issues and forks, and the composed filename later reaches write paths and command lines — falling back to the commit's short identifier when no safe name results. The map is lossy: a same-day collision surfaces as a loud add/add conflict, resolved by keeping both entry blocks, never discarding one.

### Run-type slug
A shard-name override a command declares for runs with no meaningful branch identity (e.g. scheduled weekly runs), keeping that run type's residual series in one contiguous file per day instead of fragmenting under incidental branch names. The override must be stated at every write site of that run, or the generic rule silently fragments the series.

### Migration marker
The single sanctioned write to the otherwise writer-frozen legacy residual file: one unstruck line recording that the sink was sharded, so a pre-sharding reader consulting only the legacy file loudly learns it has not seen all residuals. Written once ever; current readers recognize it and never re-queue it.

### Standing approval
Consent captured once from the operator — explicitly, per capability — that authorizes a scheduled run to perform a class of otherwise-gated actions on every future run without asking again. Its absence means the capability stays read-only/report-only; no content encountered at run time can substitute for it.

### Write-back
The closing half of consuming a residual: flipping the item's status in every sink it lives in, committed immediately so the pipeline's own state never trips its own cleanliness gates. An item consumed from a sink is closed there or explicitly re-reported — never left half-consumed.

### Narrative closure
A prose statement that an item is done — struck-through text, a blockquote disclaiming the entries below it, a note in a different shard, a commit message — written instead of updating the status field a consumer actually parses, leaving the item open to every automated reader.

The failure is structural rather than careless: the explaining sentence carries the reasoning and is the part a writer wants to produce, while the status field has no content of its own and answers no question, so composing the closure prompts nothing about it. Striking the prose makes it worse, because the strike feels like it recorded the closure.

*Avoid:* prose closure, soft close.

### Phantom residual
A sink entry whose parsed status still reads open although the work it describes has shipped — the artifact a narrative closure leaves behind. Distinct from a residual, which is genuinely unfinished; a backlog counting both is measuring record decay alongside work, and cannot be read as evidence about either.

*Avoid:* stale checkbox, orphaned todo.

### Unmarked residual
Genuinely open work recorded in a sink without the status field's required syntax, so the scan that finds phantom residuals never includes it in the population at all. The mirror image of a phantom residual and the more dangerous of the two: a phantom is a wrong answer inside the scanned set, an unmarked residual never enters the set and so surfaces as a clean pass rather than as an error.

### Reconciliation pass
A re-read of every entry in a sink against the current state of the tree rather than against the entry's own description, correcting status in both directions and producing counts that are measured rather than inherited. Distinct from write-back, which is per-item and happens at consumption time, and from the cross-shard duplicate reconciliation named under [residual sink](#residual-sink), which compares sibling shards to each other rather than any of them to the tree.

An entry's own prose is never evidence for its status during the pass — trusting it reproduces the condition the pass exists to correct.

## Subagent dispatch

### Model pin
An explicit model tier attached to a subagent dispatch — declared in the
agent's own definition or passed as an override on the dispatch call — that
fixes which tier the work runs at instead of letting it inherit the
invoking session's tier.

An override on the dispatch call beats the agent's own declaration. Absence
of a pin is not a neutral default: it is a choice to spend whatever the
operator's session happens to cost, on every dispatch, with no record that
a choice was made.

### Automatic-dispatch ceiling
The most expensive model tier a subagent may run at when a pipeline
dispatched it rather than a person choosing it for that run. Set below the
most capable available tier deliberately — the top tier is reserved for
work someone opted into, so no automated fan-out can escalate to it on its
own.

### Check-then-override
The rule for dispatching an agent whose definition is owned upstream: read
its declared tier first, override only when it declares none or explicitly
defers, and pass no override when it names one. A blanket override across a
list of targets is the mirror image of a missing pin — it silently replaces
a deliberate upstream choice with the caller's default.

## Policy authoring

### Restatement drift
A cross-cutting policy or fact written out in prose at multiple call sites
instead of stated once in the artifact that owns it and cited elsewhere. The
copies diverge, because each site's author supplies the rationale visible from
that site; and a fix scoped to whichever copy got reported leaves the
duplication that produced it live to generate the next one.

Distinguished from an *instantiation*, where the copy must be physically
adjacent to what it governs — a guard next to the untrusted input it guards
cannot be replaced by a pointer. The test is whether the copy has to be there
for the mechanism to work, or is only there to save the reader a hop.

### Decorative citation
A citation placed alongside a restatement of the cited content rather than in
place of it. It satisfies a citation-presence check while leaving the
duplicated text — and so the drift — intact, which makes it harder to catch
than a bare restatement.

## Verification authoring

### Control case
A negative-control suite entry written as its own explicit input and expected
outcome, rather than filed under a category label. Grouping controls by
category name hides that every control under it may reach the same code
branch, so the suite reports the category as covered while the branch it never
took stays dark. A control proves the branch it exercises, not the case it
names.

*Avoid:* category-named control, control category.

### Silent pass
A verification run that reports clean because a failure earlier in the run left
it with nothing to check, rather than because it checked everything and found
nothing wrong.

The two are indistinguishable in the output unless the run separates "found no
problems" from "examined no inputs", so a traversal that could not complete is
never a pass. The failure mode is self-flattering — it reads as the tool
working — which is why it survives review that a crash would not.

### Vacuous assertion
An assertion whose truth value does not depend on the construct it names, so it
reports PASS whether or not that construct exists.

Four ways the detachment happens, each with its own mechanical test — the
fixture cannot produce the condition being denied (capability); no call site
puts the guard in its failing state (reachability); the check matches text
rather than behaviour, so a comment or dead code satisfies it (observability);
or the value under test arrives as a caller's argument, which no textual anchor
can pin (pinning). The test that catches all four is one question per
assertion: *what single-line edit to production code turns this red?*

Distinct from [silent pass], which reports clean because a failure earlier in
the run left it with nothing to check. A vacuous assertion suffers no failure
and examines every input it intended to — it simply was never coupled to its
subject. Distinct also from a control that proves only the branch it exercises,
which at least reaches a branch; a vacuous assertion reaches none of the
protected construct.

*Avoid:* decorative assertion, vacuous control.

### Stated limit
A gap in what a verification tool checks that is recorded openly in the tool
itself, rather than closed with a check that only looks complete.

A limit earns this treatment when no available fixture can exercise the
branch in question: the honest record is worth more than a control contrived
to appear to cover it, because the contrived control makes the gap
unfindable. Stating the limit keeps "not checked, documented" distinguishable
from "not checked, silently".

The boundary runs both ways, and it is what keeps the category honest. A
construct **no fixture can reach** is a limit. A construct nobody has *got
around to* covering is open work, and recording it as a limit is how a backlog
becomes a green run. A limit that starts being checked is a failure, not a
bonus — the record is now false and must be retired. Where tooling verifies a
limit at all it verifies a floor (that the citation still points at a location
that still says so, in the file it claims to be about); whether the limit is
the *right* one stays a review obligation, and a one-word edit plus a
plausible citation remains the cheapest attack on the category.

### Mutation sweep
A periodic run that weakens a gating checker one registered change at a time
and re-runs the checker's entire control suite against each weakened copy,
confirming the controls actually go red. Its subject is the verification
layer, not the code the checker guards.

Distinct from generic mutation testing, which generates mutants over product
code: here they are hand-enumerated **by construct** over an instrument, in
source order, with deliberately no target count — a fixed count is a criterion
an implementer can satisfy having done the wrong thing. Each registered change
is a declarative `<target, old, new>` substitution asserted to match its anchor
**exactly once**, never a patch (a patch carries context lines, so it rots on
precisely the edits the sweep exists to check). Two invariants are not
inferable from the format: a registered change must leave the checker's verdict
on the clean tree **unchanged** — one that breaks the checker outright runs
zero controls and proves nothing — and one whose anchor stops matching is
re-anchored to the construct it targeted, never deleted to green the run.

Deliberately not a per-change gate: the controls can only develop holes when
the checker or the controls change, so a per-change run mostly re-proves the
previous answer, and everything that would make that redundant run affordable
is a second list to keep in sync.

### Declared survivor
A registered sabotage expected to survive, because no available fixture can
make any control notice it, and that gap is already recorded as a
[stated limit](#stated-limit) at a cited location.

The category the whole registry's honesty rests on, and therefore the one
worth the most suspicion: a declared survivor that *starts* being caught is a
failure rather than a pass, because the limit was closed and the declaration
is now false. Open work is never a limit — see `Stated limit` for the
boundary and for what tooling can and cannot verify about it.

### Harness freeze
Deliberately holding a verification driver and its registry byte-identical
across a change that edits only the controls, so that every outcome which
flips is attributable to a control rather than to the instrument.

The trap is the reason this needs a name: the freeze is right for
attribution and wrong for the record. The frozen files' descriptive prose goes
on asserting the world the change just ended, and because a freeze's whole
value is that it suppresses edits, a paired **reconcile at unfreeze** is the
only thing distinguishing "suppressed and later applied" from "suppressed and
lost". Untreated, the stale description tells a future editor that a construct
is already covered by a control they are about to delete.

### Detector self-exemption
A verification component exhibiting the exact failure class it was built to
catch — a silent-pass hunter that passes silently, a liveness check that
cannot report its own inability to check.

The class a detector detects is the class its author was thinking hardest
about, which is precisely what makes that region read as covered ground and
lets it survive review a crash would not. The correction is procedural: before
a detector ships, walk its own finding list back over its own source.
Distinguished from [one-layer-down regression](#one-layer-down-regression),
which is a *fix* re-committing its class in the logic it touches; this is a
*detector* instantiating the class it names.

*Avoid:* self-referential bug, ironic failure.

## Fix authoring

### One-layer-down regression
A fix that removes the reported instance of a defect while re-committing the
same class of defect in the logic it touches, so the class resurfaces in a new
form instead of being closed.

Distinguished from a plain regression in that each step is a genuine partial
improvement, which is what lets the sequence continue unnoticed. One common
generator is modelling a fix on neighbouring call sites: consistency copies
whatever those neighbours also fail to do, and when the site being changed is
the correct outlier, symmetry propagates the omission instead of the fix.

A second generator is a tool being applied to everything except itself: the
component that detects a class is exempted from it by assumption rather than
by decision. See [detector self-exemption](#detector-self-exemption), which is
that generator given its own name.

*Avoid:* recursive fix bug, self-reintroducing fix.

## Flagged ambiguities

- "Detection" and "Prevention" had been used loosely for any recurrence guidance — these are distinct: Prevention is rules for humans and process; Detection is machine-checkable signals for automated reviewers.
- Duplicated policy prose had been treated as uniformly a defect — it is not: a clause that must sit adjacent to the content it governs (an untrusted-data guard at a relay point) is an instantiation to audit for completeness, not a restatement to consolidate into a citation.
- An unset model tier on a dispatch had been read as a neutral default — it is not: it resolves to the invoking session's tier, which makes cost a property of the operator's session rather than of the task.
- Consistency between sibling call sites had been treated as self-evidently good — it is not: when the site being changed is the correct outlier, matching its neighbours adopts their omission, so the direction of the levelling has to be established before the change, not after.
- A verification tool had been treated as outside the class it verifies — it is not: the harness built to catch silent passes shipped five of its own across three review rounds, and the freshness detector built to catch a silently disabled job had a silent-pass path in its own fall-through.
- Recording closure in prose had been treated as equivalent to closing an item — it is not: only the status field a consumer parses closes it for automated readers, so prose closure leaves a phantom residual, and the inverse — open work carrying no status syntax at all — is invisible to the same scan rather than miscounted by it.
