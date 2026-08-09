---
name: file-todos
description: Structured YAML frontmatter format for review findings in todos/. The single canonical spec, produced by /cepa:review, /cepa:plan-review, and /cepa:resolve-pr, consumed by /cepa:triage, /cepa:lfg, and /cepa:sweep.
---

# File-Based Todo Tracking

## Overview

Define the structured format for review findings stored in `todos/`. Each review run produces one file. Findings use YAML frontmatter for machine-parseable metadata and markdown body for human-readable detail.

## File Format

### Filename Convention

```
todos/review-YYYY-MM-DD-HHMMSS.md          # per-PR review (/cepa:review)
todos/review-weekly-YYYY-MM-DD-HHMMSS.md   # debt tier (/cepa:review cadence:weekly)
```

Both keep the `review-` prefix so consumers globbing `review-*` match them.
**A consumer that SELECTS one file (rather than scanning all) must
discriminate on `scope:`, not on the filename** — `review-weekly-*` sorts
after every `review-<digit>-*` lexicographically, so a naive "most recent"
comparison picks the weekly file permanently once one exists.

### Document Structure

```markdown
---
date: 2026-02-17T14:30:00
scope: feature/billing-phase-7
branch: dev
agents:
  - learnings-researcher
  - security-sentinel
  - performance-oracle
  - python-reviewer
summary:
  total: 12
  p1: 2
  p2: 5
  p3: 5
  pending: 12
  ready: 0
  skipped: 0
---

# Review Findings — 2026-02-17 14:30

## Findings

### 1
- status: pending
- severity: P1
- agent: security-sentinel
- category: Compliance
- confidence: 90
- action_class: corroborated
- file: backend/apps/communications/views/thread.py
- lines: 42-48
- title: PHI exposed in log statement

**Problem:**
Patient name is included in a structlog info call...

**Fix:**
Remove patient name from log parameters...

### 2
- status: pending
- severity: P2
- agent: performance-oracle
- category: Database
- confidence: 75
- action_class: mechanical
- file: backend/apps/billing/views.py
- lines: 155-170
- title: N+1 query in payment list view

**Problem:**
...

**Fix:**
...
```

## Finding Fields

Each finding under `## Findings` uses this structure:

| Field | Required | Values | Description |
|---|---|---|---|
| `status` | yes | `pending`, `ready`, `skipped`, `applied`, `deferred`, `completed` | Triage state (see Status Lifecycle) |
| `severity` | yes | `P1`, `P2`, `P3` | Priority level |
| `agent` | yes | agent name | Which agent found it |
| `category` | yes | free text | Agent-specific category (OWASP, Database, Migration, etc.) |
| `confidence` | yes | `0`-`100` | How certain the finding is real and the fix is right. 100 = verified against the code; 75 = strong evidence; 50 = plausible but unverified |
| `action_class` | yes | `mechanical`, `corroborated`, `judgment` | Auto-apply eligibility — see the `autonomy` skill §4. `mechanical` = unambiguous fix; `corroborated` = multiple agents converged on it; `judgment` = needs a human decision |
| `file` | yes | relative path | File where the issue is |
| `lines` | no | `N` or `N-M` | Line number or range |
| `title` | yes | short text | One-line summary |
| `resolved` | no | date + branch/PR | Only on `deferred → completed`: when and where the deferred item was fixed |
| `counter_convention` | no | `legacy-total-shrink`, `persona-merged` | File-level: its counters follow a superseded convention and cannot be verified against its body. A checker skips on THIS field, never on a filename |

When agents merge duplicate findings (same location, same reason), the merged
finding's `action_class` becomes `corroborated` and its `confidence` is the
maximum of the merged findings' scores.

The `**Problem:**` and `**Fix:**` sections follow as markdown body. Include code snippets where relevant.

## Status Lifecycle

```
(created) →  deferred (cadence:weekly runs ONLY — a debt-tier run applies
                       nothing by design, so every finding it produces is a
                       residual at creation. The only birth state other than
                       `pending`; see /cepa:review's Cadence section)
pending  →  ready     (approved during triage — will be fixed)
pending  →  skipped   (rejected during triage — removed from file)
pending  →  applied   (auto-applied by an autonomous run — fix committed)
pending  →  deferred  (filed as residual work by an autonomous run —
                       also recorded in the memory/tasks.d/ shard and
                       the PR body)
pending  →  skipped   (autonomous, /cepa:resolve-pr verdicts only:
                       replied / not-addressing / declined — the finding
                       is RETAINED in the file with its evidence, unlike
                       human-triage skips)
ready    →  completed (fixed and verified)
deferred →  completed (fixed later in a dedicated pass, outside triage —
                       add a `resolved:` line naming the date and branch)
```

`completed` also covers a finding resolved because **the artifact it reviewed
was superseded** — a plan-review finding against a plan that was blocked and
replaced, where nobody fixed the defect and nobody rejected the finding: its
subject ceased to exist. The `resolved:` line must say which happened, because
the status alone cannot: distinguish *adopted into the replacement* from *moot
by supersession* from *surface deleted*. Getting this wrong in the closing
direction is expensive — one such file held six P1s that every subsequent
review re-surfaced for two days after their subject was gone.

A `superseded` enum value was considered and **rejected**: every consumer
(`/cepa:triage`, `/cepa:sweep`, `/cepa:lfg`) only needs to know whether a
finding is terminal, both states are terminal, and a new value would make every
existing parser wrong to gain a distinction only metrics want. Recorded so it is
not re-proposed. The cost is real and accepted: a count over `completed`
overstates work actually performed.

`skipped` removal applies to human-driven triage only (a batch-table reply
or the one-at-a-time flow). Autonomous runs never delete findings:
unresolved items become `deferred` so the record survives — and the one
sanctioned autonomous `skipped` (the /cepa:resolve-pr verdict edge above)
retains the finding in the file with its evidence, never removes it.

## Frontmatter Summary

The `summary` block in frontmatter is updated by `/cepa:triage` (both modes)
and by autonomous runs as decisions are made:

```yaml
summary:
  total: 12
  p1: 2
  p2: 5
  p3: 5
  pending: 1    # Updated as triage progresses
  ready: 4
  skipped: 2
  applied: 3    # Auto-applied fixes (tests passed)
  deferred: 2   # Filed as residual work (memory/tasks.d/ shard + PR body)
  completed: 0  # ready/deferred findings since fixed and verified
```

**The state counters must sum to `total`**, as must `p1 + p2 + p3`. An
omitted counter reads as zero (a freshly written file carries only
`pending`), but every `status` value in the lifecycle above has one available
— `completed` included, so a `deferred → completed` write-back has somewhere
to land. A transition with no counter forces the writer to choose between an
unbalanced block and an invented field, and different runs choose
differently.

**The sum is not enough, and checking only the sum is the documented
failure.** Every wrong distribution with the same total satisfies it: a file
declaring `p2: 6, p3: 2` over a body of seven P2s and one P3 balances
perfectly. That shipped, was reported as "counters verified", and was caught
only by a later review — twice. So the counters must also **agree with the
body**:

> Each state counter equals the number of findings in the body carrying that
> `status:` value, **plus** any findings removed from the file by human-driven
> triage. `p1`/`p2`/`p3` equal their body counts exactly on any file that has
> had no removals.

**One encoding for a removal, mandated — both were in use and the invariant
could not tell them apart.** `total` is fixed when the file is written and is
**never shrunk**. A human-triage removal increments `skipped` by exactly one and
leaves `total` alone. The rejected alternative — shrink `total`, leave
`skipped: 0` — erases the removal from every parsed field, leaving it only in
`triage:` prose, which is the closure-claim class this repo already documents.

That makes the gap an **equality**, not a bound:

> `total − (findings present in the body)` **equals** the number of human-triage
> removals, and that number is what `skipped` holds — minus any retained skips,
> which are still in the body and already tallied there.

An inequality (`gap ≤ skipped`) would be satisfied by `gap = 0, skipped = 0`,
which is precisely the encoding being rejected: a file can shrink `total` to
absorb any number of removals and still pass. That is a check that cannot fail
on the state it exists to catch.

The two kinds of skip behave differently and a checker must not assume one —
human-triage skips are **removed** from the body, while the `/cepa:resolve-pr`
verdict skips are **retained** in it. A file with only retained skips has no gap.

**Stated limit:** `skipped` is a single scalar with no severity breakdown, so
once a file has had a removal, `p1`/`p2`/`p3` cannot be re-derived from the body
alone — the removed finding's severity is unrecoverable. The severity counters
are therefore verifiable only on files with no removals. This is a real hole,
recorded rather than papered over; closing it would need a per-severity removal
field, which no consumer has asked for.

Verify against the body, never against the block's own arithmetic:

```bash
grep -oE '^-?[[:space:]]*severity: P[123]'  todos/review-<stamp>.md | sort | uniq -c
grep -oE '^-?[[:space:]]*status: [a-z]+'    todos/review-<stamp>.md | sort | uniq -c
```

**The leading `-` is optional and the pattern must tolerate both.** Two field
formats are live in this repo — `- severity: P1` and bare `severity: P1` — and a
pattern anchored to one returns **zero rows on the other, silently**. A zero
count is not a clean file; it is a pattern that did not fire. Compare the row
count against the `### N` headings before reading any tally as a result.

**Three shapes are NOT tallyable**, and all must be reported as such rather than
counted as disagreement:

- a **severity suffix** naming a range or batch — `severity: P2/P3 (batch)`;
- a **heading range** — `### 21-25`, one `severity:`/`status:` pair covering
  several enumerated findings;
- **persona-merged entries** (pre-2026-07-18 plan reviews) — `total` counts raw
  per-agent findings while the body carries deduplicated groups, sometimes with
  a `(Merges Fx+Fy)` citation and sometimes not. Where the citations are
  present the counts reconcile; where they are absent the file cannot be
  verified from its body at all.

A file whose counters follow a superseded convention carries
`counter_convention:` in its frontmatter naming it — `legacy-total-shrink`,
`persona-merged`. **A checker skips on that field, never on a filename.** A
grandfather clause that lives only in prose beside the file is unreadable to
every consumer, which is the defect this spec exists to prevent; it must be a
field or it is not an exemption.

Miscounting these is not hypothetical. A scan of this repo reported twelve bad
files when six were bad, by treating batch suffixes as drift; a later pass then
shrank a *correct* file's `total` from 30 to 26 and declared four findings
unrecoverable, because a heading-range block was invisible to a per-line tally.
They were never lost. Expand the block, then count.

## Run Metadata (optional frontmatter fields)

Review runs record dispatch decisions and the deploy verdict in frontmatter —
these fields, not ad-hoc prose, are the sanctioned "header record":

```yaml
agents_skipped:
  - agent: frontend-reviewer
    rule: "no templates/JS/CSS in diff"
conditional_dispatch:            # all three conditional agents, every run
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff touches billing paths"
  - agent: reliability-reviewer
    dispatched: false
    reason: "no queue/webhook/transaction/external-call code"
  - agent: previous-comments-reviewer
    dispatched: false
    reason: "excluded by cepa.local.md (!previous-comments-reviewer)"
deploy_verdict:
  verdict: GO            # GO | NO-GO | GO WITH CONDITIONS | not-evaluated
  basis: "no P1s; two P2s are post-deploy hygiene"
  conditions: []         # e.g. ["run migration 0042 before deploy"]
detection_signals:               # Detection pipeline coverage, every run
  matched_docs: 4                # solution docs matching the diff
  docs_with_detection: 2         # of those, docs that had a ## Detection section
  signals_passed: 5              # Detection bullets relayed to review agents
  sources:
    - docs/solutions/ui-bugs/example-doc.md
  backfill_candidates:           # matched docs lacking Detection — feed /cepa:compound-refresh
    - docs/solutions/logic-errors/old-doc.md
  suspect_bullets: 0             # SUSPECT-quoted bullets stripped before dispatch
                                 # (each also becomes a corrupted-signal finding)
  corpus: present                # present | none | not-consulted — none when
                                 # the repo has no docs/solutions at all;
                                 # not-consulted when the researcher was never
                                 # dispatched (cadence:weekly). All three are
                                 # distinct from zero matches against a real corpus
reviewed_through: a1b2c3d        # cadence:weekly ONLY — the trunk tip this run
                                 # scoped to. The next weekly run reads it as
                                 # its watermark instead of a wall-clock window,
                                 # so a missed run is absorbed rather than
                                 # leaving an unreviewed gap. Written only when
                                 # a review actually completed
learnings_research: "ok"         # ok | "failed — <reason>" (researcher errored)
                                 # | "skipped — <reason>" (never dispatched, e.g.
                                 # cadence:weekly). Emitted on EVERY run: absence
                                 # would make "ran fine" and "never ran"
                                 # indistinguishable, and a lost institutional-
                                 # memory input must never look like a normal run
grounding:                       # only when cepa.local.md configures a
  provider: graphify             # grounding: key — see emission scope below
  status: fresh                  # fresh | stale — <reason> |
                                 # degraded — <verb> failed after N queries
                                 # (partial output was relayed and stands) |
                                 # unavailable — <reason>
  refreshed: true                # graphify update ran this run (code-layer
                                 # freshness ONLY — semantic nodes reflect the
                                 # last human-scheduled pass)
  queries: 3                     # shared total, orchestrator + researcher
                                 # pre-step (budget 5 — cepa:grounding skill);
                                 # researcher addend comes from its mandatory
                                 # status line, never estimated
  pre_step: ok                   # the researcher's status line verbatim:
                                 # ok — N queries used, … | skipped — <reason>
                                 # | failed — <reason> | none (researcher not
                                 # told grounding was available) | none —
                                 # researcher not dispatched (cadence:weekly;
                                 # distinct from "dispatched but uninformed")
  args_skipped: 0                # arguments rejected by the sanitization rules,
                                 # BOTH sites (invoker + researcher pre-step)
  suspect_stripped: 0            # stripped blocks from BOTH strip sites (each
                                 # also filed as a corrupted-input finding under
                                 # grounding, never under detection_signals)
brain:                           # only when cepa.local.md configures a brain:
  provider: ob1                  # key (opt-in) — see the cepa:brain skill
  status: fresh                  # fresh | degraded — <verb> failed: <code> |
                                 # unavailable — <reason>
  role: consumer                 # consumer | producer | both
  queries: 1                     # recall calls this run (budget 1)
  written: 0                     # memory atoms written (producer)
  suppressed_writebacks: 0       # atoms skipped (422 / oversize / non-participant)
                                 # — recorded, never silent
  scrubbed: 0                    # PHI patterns redacted before egress
                                 # (brain_phi_scrub repos)
  args_skipped: 0                # recall-query candidates rejected by sanitization
  suspect_stripped: 0            # stripped recall blocks (SUSPECT-BRAIN) — each
                                 # a corrupted-input finding under brain, NEVER
                                 # detection_signals
  pre_step: ok                   # researcher recall pre-step status line verbatim
agents_failed:                   # reviewers/personas that errored mid-run —
  - agent: security-lens         # a failed reviewer is a named coverage gap,
    reason: "subagent error"     # never a clean pass
dropped_below_anchor: 0          # plan-review: findings dropped at anchor 0/25
validation_drops:                # plan-review: malformed findings dropped at
  - agent: coherence             # synthesis step 1, counted per persona —
    count: 0                     # an uncounted drop is a silently lost finding
suspect_comments: 0              # resolve-pr: stripped imperatives/claims from
                                 # PR comment text (each also filed as a
                                 # corrupted-input finding)
fetch_fallback: none             # resolve-pr: none | "taken — <reason>" — a
                                 # degraded gh-view/REST fetch must never look
                                 # like a full one
dropped_wrappers: 0              # resolve-pr: wrapper-classified bot comments
                                 # dropped at triage (audit trail, not noise)
```

`scope:` examples: `feature/billing-phase-7` (code review),
`plan:docs/plans/<file>` (plan review), `pr-feedback:#42` (resolve-pr),
`weekly:2026-07-26` (debt tier — `/cepa:review cadence:weekly`).

**`scope:` is the file-kind discriminator.** A consumer that loads ONE
findings file selects on this field: `/cepa:lfg` gates on a `plan:` prefix,
and `/cepa:triage` excludes `weekly:` (those findings are drained by
`/cepa:sweep`, never triaged). Adding a new prefix means auditing every
single-file-selecting consumer, not just the producer.

Rules:
- `conditional_dispatch` lists ALL conditional-tier agents each run, fired or
  not, with the one-line signal evaluation — "didn't fire" must be
  distinguishable from "fired and found nothing" and from "excluded by
  config". Fired conditional agents also appear in the `agents:` list.
- `deploy_verdict.verdict` is `not-evaluated` (with the skip rule as
  `basis`) when deployment-verifier was skipped — a missing verdict is
  never silent.
- `grounding` emission scope, in repos whose `cepa.local.md` configures
  a `grounding:` key: every `/cepa:review` findings file carries the
  block, on every path (fresh, stale, degraded, unavailable) — there an
  absent block is a recording defect. An lfg-invoked plan-review
  findings file carries it when lfg's Step 2 ran the grounding check
  (lfg folds those facts in). Producers that never run grounding
  (resolve-pr, standalone plan-review) omit it — omission by a
  non-grounding producer is normal, not a defect. Command phases that
  ground but write no findings file record strips/failures in the
  run's residual shard per the `cepa:grounding` skill's durable-sink rule.
  In repos with no `grounding:` key the block is absent by definition —
  existing files stay valid, no migration.
- `brain` emission scope mirrors `grounding`, in repos whose `cepa.local.md`
  configures a `brain:` key (opt-in): any findings file a participating run
  writes carries the block on every path (fresh/degraded/unavailable) — an
  absent block there is a recording defect; producers that never touch the
  brain omit it; phases with no findings file (compound interactive,
  task/lfg research) record brain strips/suppressions/scrubs in the
  run's residual shard per the `cepa:brain` skill's durable-sink rule. No
  `brain:` key → block absent by definition, existing files stay valid.
- When the verdict is NO-GO or GO WITH CONDITIONS, the full verdict block
  including the rollback plan is ALSO written into the file body as a
  `## Deploy Verdict` section, and the basis/conditions are additionally
  emitted as a P1 (NO-GO) or P2 (conditions) finding so severity-based
  gates (triage, lfg) act on it.

## Querying Findings

To find all pending P1 findings across all review files:
1. Read all `todos/review-*.md` files
2. Parse YAML frontmatter for quick summary counts
3. For individual findings, parse the `### N` sections and check `status` and `severity` fields

## Rules

- One file per review run — never append findings to an existing file
- Finding numbers are sequential within a file, starting at 1
- Skipped findings are removed entirely from the file during human-driven
  triage (not just marked). Autonomous runs never delete — they mark
  `deferred` and file to the residual sinks — except the sanctioned
  /cepa:resolve-pr verdict skips (replied/not-addressing/declined), which
  stay `skipped` and RETAINED with their evidence, and are never filed to
  the residual sinks (they are answered, not deferred)
- The frontmatter `summary` is what consumers **read** — it is a derived cache,
  not the source of truth. The findings in the body are. When the two disagree
  the block is wrong, and it is the block that gets corrected. (This line
  previously read "the source of truth for counts", which is what licensed the
  drift: a cache declared authoritative is a cache nobody re-derives. Six files
  had drifted before anyone compared them to their own bodies.)
- Keep finding titles under 80 characters
- Code snippets in Problem/Fix sections use fenced code blocks with language tags
