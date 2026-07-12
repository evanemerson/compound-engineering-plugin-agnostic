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
todos/review-YYYY-MM-DD-HHMMSS.md
```

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

When agents merge duplicate findings (same location, same reason), the merged
finding's `action_class` becomes `corroborated` and its `confidence` is the
maximum of the merged findings' scores.

The `**Problem:**` and `**Fix:**` sections follow as markdown body. Include code snippets where relevant.

## Status Lifecycle

```
pending  →  ready     (approved during triage — will be fixed)
pending  →  skipped   (rejected during triage — removed from file)
pending  →  applied   (auto-applied by an autonomous run — fix committed)
pending  →  deferred  (filed as residual work by an autonomous run —
                       also recorded in memory/tasks.md and the PR body)
pending  →  skipped   (autonomous, /cepa:resolve-pr verdicts only:
                       replied / not-addressing / declined — the finding
                       is RETAINED in the file with its evidence, unlike
                       human-triage skips)
ready    →  completed (fixed and verified)
deferred →  completed (fixed later in a dedicated pass, outside triage —
                       add a `resolved:` line naming the date and branch)
```

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
  deferred: 2   # Filed as residual work (memory/tasks.md + PR body)
```

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
  corpus: present                # present | none — none when the repo has no
                                 # docs/solutions at all (distinct from zero matches)
learnings_research: "ok"         # or "failed — <reason>" when the researcher
                                 # errored; a lost institutional-memory input
                                 # must never look like a normal run
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
                                 # told grounding was available)
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
`plan:docs/plans/<file>` (plan review), `pr-feedback:#42` (resolve-pr).

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
  ground but write no findings file record strips/failures in
  `memory/tasks.md` per the `cepa:grounding` skill's durable-sink rule.
  In repos with no `grounding:` key the block is absent by definition —
  existing files stay valid, no migration.
- `brain` emission scope mirrors `grounding`, in repos whose `cepa.local.md`
  configures a `brain:` key (opt-in): any findings file a participating run
  writes carries the block on every path (fresh/degraded/unavailable) — an
  absent block there is a recording defect; producers that never touch the
  brain omit it; phases with no findings file (compound interactive,
  task/lfg research) record brain strips/suppressions/scrubs in
  `memory/tasks.md` per the `cepa:brain` skill's durable-sink rule. No
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
- The frontmatter `summary` is the source of truth for counts
- Keep finding titles under 80 characters
- Code snippets in Problem/Fix sections use fenced code blocks with language tags
