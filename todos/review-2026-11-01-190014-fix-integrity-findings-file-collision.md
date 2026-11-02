---
date: 2026-11-01T19:00:14
scope: pr:#119
branch: fix/integrity/findings-file-collision
agents:
  - adversarial-reviewer
  - architecture-reviewer
  - previous-comments-reviewer
  - silent-failure-hunter
config: "no cepa.local.md in this repo — inferred roster (bash script, markdown commands/skills, shell controls); scope origin/main...ac314de"
learnings_research: "skipped — not dispatched this run (worker kept the roster to four readers); the L54 source and punch-list entries were read directly, pre-step: skipped — grounding not configured"
agents_skipped:
  - agent: security-sentinel
    reason: "the one new input (branch/--scope into a path) was traced by adversarial-reviewer; no auth, PHI or payments"
  - agent: performance-oracle
    reason: "no query, ORM or frontend code"
  - agent: data-integrity-guardian
    reason: "no migrations or data stores"
  - agent: schema-drift-detector
    reason: "no models, migrations, serializers, forms or admin"
  - agent: frontend-reviewer
    reason: "no templates, JS or CSS"
  - agent: python-reviewer
    reason: "no Python changed"
  - agent: deployment-verifier
    reason: "nothing deploys from this repo"
  - agent: pr-test-analyzer
    reason: "inferred roster; control coverage was checked by silent-failure-hunter and adversarial-reviewer, and by hand mutants"
  - agent: comment-analyzer
    reason: "inferred roster; architecture-reviewer read the doc claims"
  - agent: type-design-analyzer
    reason: "no types or models added"
  - agent: code-simplifier
    reason: "inferred roster; small script"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff 478 lines; a repo-derived value (branch name) composed into a write path"
  - agent: reliability-reviewer
    dispatched: false
    reason: "no queue, webhook, network or transaction code"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; the diff closes punch-list L54"
agents_failed: []
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped — nothing deploys from this repo"
  conditions: []
detection_signals:
  passed: 0
  source_docs: 0
  backfill_candidates: 0
  suspect_bullets: 0
  corpus: not-consulted
summary:
  total: 8
  p1: 0
  p2: 0
  p3: 8
  pending: 0
  ready: 0
  skipped: 1
  applied: 6
  deferred: 1
  completed: 0
---

# Review Findings — 2026-11-01 (PR #119, L54 findings-file collision)

This file's path was reserved by the PR's own `findings-path.sh`.

## Findings

### 1
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Correctness
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/scripts/findings-path.sh
- lines: 44
- title: --help printed the `set -u` line after the header

**Problem:**
`sed -n '2,37p'` ran past the header, which ends at line 35.

**Fix:**
Applied: the range is `2,35p`.

### 2
- status: deferred
- severity: P3
- agent: architecture-reviewer
- category: Architecture
- confidence: 70
- action_class: judgment
- file: plugins/cepa/commands/sweep.md
- lines: 475
- title: sweep's headless report keeps a second-stamped, hand-composed name

**Problem:**
`todos/sweep-YYYY-MM-DD-HHMMSS.md` is the same shared-sink class as L54, outside this PR's `review` and `review-weekly` kinds.

**Fix:**
Deferred: filed in memory/tasks.d/2026-11-01-fix-integrity-findings-file-collision.md (add `--kind sweep`, after checking every `sweep-*` reader).

### 3
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Error Handling
- confidence: 90
- action_class: judgment
- file: plugins/cepa/scripts/findings-path.sh
- lines: 64
- title: an empty --scope silently fell back to the checkout's branch

**Problem:**
A weekly run whose trunk resolved to '' got a name from the current branch, with rc 0.

**Fix:**
Applied: a `--scope` that is given but empty exits 2. Control `path-emptyscope`; its mutant goes red.

### 4
- status: applied
- severity: P3
- agent: silent-failure-hunter, adversarial-reviewer
- category: Correctness
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/findings-path.sh
- lines: 81-87
- title: noclobber "reserved" a symlink to /dev/null, and the create error was dropped

**Problem:**
bash noclobber gives O_EXCL only for an absent or regular target. A planted symlink to /dev/null returned rc 0 as "an empty file this run owns". `2>/dev/null` dropped the cause of a failed create.

**Fix:**
Applied: any symlink, or non-regular entry, at the name exits 2 before the create; after the create the path must be a plain empty file; the create's error text is kept in the "cannot create" message. `path-symlink` now plants both a dangling and a /dev/null link; its mutant goes red.

### 5
- status: applied
- severity: P3
- agent: silent-failure-hunter, adversarial-reviewer
- category: Testing
- confidence: 85
- action_class: corroborated
- file: scripts/check-findings-file-controls.sh
- lines: wire-path, path-readers
- title: wire-path missed a bare weekly name, and path-readers claimed more than it tests

**Problem:**
The bare-name regex matched only three lead phrases and never `review-weekly-`. The `path-readers` reg text claimed every reader glob; it tests the repo checker's walk.

**Fix:**
Applied: the bare-name leg matches any `todos/review(-weekly)?-YYYY-MM-DD-HHMMSS.md` token in a writer; the `path-readers` reg text names the repo checker's walk.

### 6
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Security
- confidence: 95
- action_class: mechanical
- file: plugins/cepa/scripts/findings-path.sh
- lines: 57
- title: a newline in --scope survived slug() and split the printed path

**Problem:**
`sed` is line-based, so `--scope $'a\n-b-\n.c'` created a file with newlines in its name and printed three lines. §5's slug output is `[A-Za-z0-9_-]` only.

**Fix:**
Applied: `tr '\n\r' '--'` runs before the sed. `path-slug` plants that value; with the `tr` removed it goes red.

### 7
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Documentation
- confidence: 85
- action_class: judgment
- file: plugins/cepa/skills/file-todos/SKILL.md
- lines: Filename Convention, last paragraph
- title: "a sort by name is a sort by time" is false within one second

**Problem:**
`-` sorts before `.`, so `…-x-2.md` sorts before `…-x.md`; triage's "most recent by filename date" can pick the earlier of two same-second files.

**Fix:**
Applied: the spec and the script header now say a name sort orders by second only, and that a reader finding one run's file uses the printed path. Triage's tie-break is filed in the run's residual shard.

### 8
- status: skipped
- severity: P3
- agent: previous-comments-reviewer
- category: Process
- confidence: 90
- action_class: mechanical
- file: memory/tasks.d/2026-10-02-punch-list.md
- lines: 1621
- title: L54 still reads status pending

**Problem:**
Informational: the punch-list item stays open until merge.

**Fix:**
Skipped: coord@main is the only writer of the punch list and closes L54 after merge.

---

**Summary:** 8 findings (0 P1, 0 P2, 8 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
