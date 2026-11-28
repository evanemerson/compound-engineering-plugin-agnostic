---
date: 2026-11-27T21:33:11
scope: pr:150
branch: docs/matrix/shard-flip-and-block-select-rules
agents:
  - learnings-researcher
  - security-sentinel
  - architecture-reviewer
  - silent-failure-hunter
  - previous-comments-reviewer
summary:
  total: 14
  p1: 0
  p2: 5
  p3: 9
  pending: 0
  ready: 0
  skipped: 2
  applied: 9
  deferred: 3
  completed: 0
learnings_research: "ok — briefing from docs/solutions/ in the main checkout (read-only), CLAUDE.md"
detection_signals:
  corpus: consulted
  signals: 5
  source_docs: 5
  backfill_candidates: 0
  suspect_bullets: 0
brain: "skipped — worker review; brain pre-flight not run"
agents_skipped:
  - python-reviewer: "not rostered in cepa.local.md (no Python app)"
  - performance-oracle: "not rostered in cepa.local.md"
  - data-integrity-guardian: "not rostered in cepa.local.md"
  - schema-drift-detector: "not rostered in cepa.local.md"
  - frontend-reviewer: "not rostered in cepa.local.md"
  - deployment-verifier: "not rostered; nothing deploys from this repo"
conditional_dispatch:
  adversarial-reviewer: {dispatched: false, reason: "signal absent: about 190 changed lines, no risky paths"}
  reliability-reviewer: {dispatched: false, reason: "signal absent: no task-queue, webhook or transaction code"}
  previous-comments-reviewer: {dispatched: true, signal: "todos/review-*.md exist; the PR closes punch-list L51 and L56"}
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier is not rostered; nothing deploys from this repo"
agent_worktrees: "none — no dispatch ran isolated"
---

# Review Findings — 2026-11-27 21:33

## Findings

### 1
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 90
- action_class: mechanical
- file: scripts/probe-shard-lag.py
- lines: finding_status
- title: Findings files with a bare `status:` line were skipped silently

**Problem:**
The parser read only `- status:`; 35 of 133 findings files write `status:`
with no list marker, so leg F skipped them with no output.

**Fix:**
Applied: the pattern is `^(?:- )?status:`, and a file with no parseable
finding prints a `?` note. Corpus diff on the same tree: no row lost.

### 2
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 90
- action_class: mechanical
- file: scripts/probe-shard-lag.py
- lines: punch_status
- title: 13 of 103 punch-list items had no status read

**Problem:**
The regex wanted a 4-space `status:` on the line after a one-line title. 8
items use 3 spaces and 5 titles wrap, so leg L never checked them.

**Fix:**
Applied: each item is read as one chunk, its first indented `status:` line
taken, and a count mismatch prints a note. Now 103 of 103; the change gained
one real lag row (the L7 line), flipped on this branch.

### 3
- status: applied
- severity: P2
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 90
- action_class: mechanical
- file: memory/tasks.d/2026-11-01-fix-roles-rename-rebind-hardening.md
- lines: 14
- title: The L56 source line stayed open while this PR records its rule

**Problem:**
The PR broke the rule it adds: the proposed-rule line stayed `- [ ]`.

**Fix:**
Applied: flipped to `[x]` with a note naming the CLAUDE.md rule and the new
shard.

### 4
- status: deferred
- severity: P2
- agent: architecture-reviewer
- category: Ownership
- confidence: 80
- action_class: judgment
- file: CLAUDE.md
- lines: "Flip the shard line" section
- title: The shard-flip rule may belong in cepa:autonomy §5

**Problem:**
The rule binds every repo's closures, but repo CLAUDE.md reaches only this
repo.

**Fix:**
Deferred: promotion to §5 is plugin content and a version bump; the
operator's call. Filed in the branch shard.

### 5
- status: skipped
- severity: P2
- agent: architecture-reviewer
- category: Count drift
- confidence: 85
- action_class: mechanical
- file: CLAUDE.md
- lines: "Flip the shard line" section
- title: CLAUDE.md states the probe's candidate and lag counts

**Problem:**
The counts also live in the shard and will drift.

**Fix:**
Skipped: coord@main's brief asked for the command and the count beside the
rule. The count is dated and names its SHA and probe, so it reads as a
measurement, not a current total.

### 6
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 85
- action_class: mechanical
- file: todos/review-2026-10-30-192000.md
- lines: finding 16
- title: Finding 16 stayed deferred while this PR applies its fix

**Problem:**
The finding this PR implements was left `deferred`.

**Fix:**
Applied: `applied`, counters moved, resolution note added. Its tracking line
in `2026-10-30-fix-roles-rule7-probe-fixes.md` (found by the probe once the
finding flipped) is flipped too.

### 7
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 70
- action_class: judgment
- file: memory/tasks.d/2026-11-27-docs-matrix-shard-flip-and-block-select-rules.md
- lines: "L56 — instances"
- title: CLAUDE.md said the shard owns instances it did not hold

**Problem:**
Instances 1-3 (#116) lived only in the rename-rebind shard line.

**Fix:**
Applied: copied into a new "L56 — instances" section, with their probe.

### 8
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 60
- action_class: judgment
- file: memory/tasks.d/
- lines: (4 lines)
- title: The measured lag lines were filed, not flipped

**Problem:**
The PR documented known lag without closing it.

**Fix:**
Applied: all 4 lag lines (L7, L18, L45, L66) flipped with a closing note.

### 9
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 85
- action_class: mechanical
- file: scripts/probe-shard-lag.py
- lines: finding_status
- title: A missing findings file was skipped silently

**Problem:**
`except OSError: return {}` made "file missing" look like "no lag".

**Fix:**
Applied: a missing file prints a `?` note.

### 10
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Error handling
- confidence: 80
- action_class: mechanical
- file: scripts/probe-shard-lag.py
- lines: punch_status
- title: An unreadable punch list crashed the probe

**Problem:**
The docstring claimed exit 0 always, but a missing punch list raised.

**Fix:**
Applied: it prints a note and leg L checks nothing; exit stays 0.

### 11
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 75
- action_class: judgment
- file: scripts/probe-shard-lag.py
- lines: main
- title: Two skips still print no note

**Problem:**
A `Canonical findings:` line in another spelling, and a line naming two
findings files, are skipped with no note.

**Fix:**
Deferred to the branch shard: print a `?` note for each.

### 12
- status: deferred
- severity: P3
- agent: architecture-reviewer
- category: Ownership
- confidence: 65
- action_class: judgment
- file: CLAUDE.md
- lines: "A leg that runs a fenced block" section
- title: The block-select rule should move to the checker header once checked

**Problem:**
Checker headers own what they flag; the rule has no checker yet.

**Fix:**
Deferred with the mechanical-check residual (after #149).

### 13
- status: skipped
- severity: P3
- agent: architecture-reviewer
- category: Citation
- confidence: 70
- action_class: mechanical
- file: memory/tasks.d/2026-11-27-docs-matrix-shard-flip-and-block-select-rules.md
- lines: 5-7
- title: Solution-doc paths are gitignored, unreadable in a fresh clone

**Problem:**
The shard cites `docs/solutions/` files that only the lane holds.

**Fix:**
Skipped: `docs/` is gitignored by repo convention, and the shard says so; the
shard itself holds the evidence a reader needs.

### 14
- status: applied
- severity: P3
- agent: security-sentinel
- category: Path handling
- confidence: 20
- action_class: mechanical
- file: scripts/probe-shard-lag.py
- lines: CANON
- title: The Canonical-findings capture allowed any path text

**Problem:**
`[^`]+` let a shard line steer the read outside `todos/` (read-only, output
fixed-format).

**Fix:**
Applied: the capture is `review-[a-z0-9-]+`.

---

**Summary:** 14 findings (0 P1, 5 P2, 9 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
