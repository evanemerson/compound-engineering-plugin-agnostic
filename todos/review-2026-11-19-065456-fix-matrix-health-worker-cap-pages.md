---
date: 2026-11-19T06:54:56
scope: fix/matrix/health-worker-cap-pages
branch: fix/matrix/health-worker-cap-pages
pr: 146
agents:
  - adversarial-reviewer
  - reliability-reviewer
  - previous-comments-reviewer
  - python-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
summary:
  total: 10
  p1: 0
  p2: 0
  p3: 10
  pending: 0
  ready: 0
  skipped: 1
  applied: 7
  deferred: 2
  completed: 0
agents_skipped:
  - agent: security-sentinel
    rule: "no auth, PHI or secrets in diff; cursor injection covered by adversarial and python reviewers"
  - agent: performance-oracle
    rule: "no ORM, queries or hot loops in diff (bash scripts and tests)"
  - agent: data-integrity-guardian
    rule: "no migrations or data writes in diff"
  - agent: schema-drift-detector
    rule: "no models, migrations, serializers, forms or admin in diff"
  - agent: frontend-reviewer
    rule: "no templates/JS/CSS in diff"
  - agent: deployment-verifier
    rule: "no config, dependencies, Docker, env or migration files; manifests carry a version bump only"
  - agent: architecture-reviewer
    rule: "no new module boundaries; the change sits inside one existing script"
  - agent: comment-analyzer
    rule: "skipped for cost in a worker run; header text checked by the adversarial and previous-comments reviewers"
  - agent: type-design-analyzer
    rule: "no new types or models"
  - agent: code-simplifier
    rule: "skipped for cost in a worker run"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff changes the alert-or-ok decision of the coordinator health check"
  - agent: reliability-reviewer
    dispatched: true
    signal: "diff changes external CLI calls (orca-ide worker-list paging, timeouts)"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; punch-list L60 and L89 touch orca-health.sh"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped: no deploy surface in diff (plugin scripts and tests)"
  conditions: []
learnings_research: "skipped — no docs/solutions/ in this checkout (docs/ is gitignored)"
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
  corpus: "not-consulted — learnings-researcher not run; docs/ is gitignored"
---

# Review Findings — 2026-11-19 06:54 (PR #146)

No cepa.local.md in this repo: the run inferred the stack (bash with embedded
python, tests). Reviewed head 8035084. No P1 or P2. Fixes below are on the
next commit.

## Findings

### 1
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Correctness
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/scripts/orca-health.sh
- lines: 490-500
- title: a row read on two pages kept its first copy, so a new failure could wait one turn

**Problem:**
Dedupe kept the first copy of a dispatch. A row `in_progress` on page 1 that
moved to page 2 as `failed` was counted live, and the L60 alert waited one
check. Reliability and silent-failure reviewers found the same.

**Fix:**
Keep the most settled copy: failed, then another outcome, then in_progress.
Case "a row live on page 1 and failed on page 2 alerts"; mutants
health-dup-first-wins and health-dup-last-wins.

### 2
- status: applied
- severity: P3
- agent: reliability-reviewer
- category: Reliability
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- lines: 446
- title: page size relied on Orca's default

**Problem:**
The 10-page bound means 1000 rows only while Orca's default page is 100.

**Fix:**
Pass `--limit 100` (the maximum `worker-list --help` allows). Mutant
health-limit-dropped.

### 3
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Error handling
- confidence: 50
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- lines: 457-458
- title: a full page with no page object read as the last page

**Problem:**
An Orca that renamed `page` would read only page 1 and print `ok`, dropping
failed rows on later pages.

**Fix:**
A page with no `page` object is the last only when it holds under 100 rows;
a full one is unreadable. Cases for both; mutant health-nopage-full-ok.

### 4
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Error handling
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- lines: 468-470
- title: a cursor loop read as more than 10 pages

**Problem:**
An Orca that repeats a cursor made 10 calls and raised `worker-pages`, which
names the wrong cause.

**Fix:**
A cursor seen before makes the list unreadable at once. Case "a cursor seen
before is unreadable"; mutant health-cursor-loop-unchecked.

### 5
- status: applied
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 80
- action_class: corroborated
- file: scripts/check-orca-nudge.sh
- lines: 2395-2400
- title: the upper page bound was not pinned

**Problem:**
`-ge 10` changed to `-ge 11` passed every case. The python reviewer found the
same.

**Fix:**
`calls_want` on "more than 10 pages" lists exactly 10 worker-list calls;
mutant health-page-bound-long.

### 6
- status: applied
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 75
- action_class: corroborated
- file: scripts/check-orca-nudge.sh
- lines: 2378-2384
- title: the cursor leading-dash rule was not tested on its own

**Problem:**
The one bad-cursor case held both `-` first and `;`, so dropping the
leading-character rule (option injection through `--cursor`) survived. The
python reviewer found the same.

**Fix:**
Separate cases for `a;id`, `-abc` and an accepted `a-b=_9`; mutant
health-cursor-dash-first.

### 7
- status: applied
- severity: P3
- agent: python-reviewer
- category: Test coverage
- confidence: 60
- action_class: mechanical
- file: scripts/check-orca-nudge.sh
- lines: 2387
- title: a page with no hasMore was unreadable but unpinned

**Problem:**
The stricter shape check had no case either way.

**Fix:**
Case "a page with no hasMore is unreadable".

### 8
- status: deferred
- severity: P3
- agent: adversarial-reviewer
- category: Design limit
- confidence: 70
- action_class: judgment
- file: plugins/cepa/scripts/orca-health.sh
- lines: 189-194
- title: a Run past 1000 rows raises worker-pages every hour

**Problem:**
Runs are never closed. Past 1000 rows the L94 symptom returns as
`worker-pages`.

**Fix:**
Stated in the header as a limit. Filed:
memory/tasks.d/2026-11-19-fix-matrix-health-worker-cap-pages.md item 1.

### 9
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 50
- action_class: judgment
- file: scripts/check-orca-nudge.sh
- lines: 2376
- title: later-page failure shapes and the 20 worker-show reads are not pinned

**Problem:**
Only a missing page-2 file is tested; `ok: false`, a bad `workers`, and a
page-2 timeout are not. The exact 20 `worker-show` reads are not pinned
(pre-existing).

**Fix:**
Filed: memory/tasks.d/2026-11-19-fix-matrix-health-worker-cap-pages.md item 2.

### 10
- status: skipped
- severity: P3
- agent: previous-comments-reviewer
- category: Residual tracking
- confidence: 80
- action_class: mechanical
- file: memory/tasks.d/2026-10-02-punch-list.md
- lines: 2792
- title: L94 still reads status pending

**Problem:**
The punch-list entry stays open after this PR.

**Fix:**
Skipped: coord@main is the punch list's only writer and closes it at merge.

---

**Summary:** 10 findings (0 P1, 0 P2, 10 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
