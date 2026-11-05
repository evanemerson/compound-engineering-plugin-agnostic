---
date: 2026-11-05T12:02:06
scope: pr:136
branch: fix/optimization/setup-timeout-gate-pull-only
agents:
  - adversarial-reviewer
  - reliability-reviewer
  - architecture-reviewer
  - previous-comments-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
  - comment-analyzer
agents_skipped:
  - agent: security-sentinel
    rule: "no cepa.local.md roster; no auth, payment or PHI path in the diff"
  - agent: frontend-reviewer
    rule: "no templates/JS/CSS in diff"
  - agent: schema-drift-detector
    rule: "no models or migrations in diff"
  - agent: data-integrity-guardian
    rule: "no models or migrations in diff"
  - agent: performance-oracle
    rule: "no ORM, query or frontend path in diff"
  - agent: python-reviewer
    rule: "no cepa.local.md roster; Python is a stub and a seven-line reader, covered by the other reviewers"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff of about 670 lines"
  - agent: reliability-reviewer
    dispatched: true
    signal: "locks, timeouts and pipes in stack-gate.sh"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist"
agents_failed: []
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier is not rostered in this repo: nothing deploys from it"
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
  corpus: absent
learnings_research: "skipped — docs/solutions/ is absent in this checkout (docs/ is gitignored); the worker's brief says no helpers unless the task asks"
summary:
  total: 12
  p1: 0
  p2: 1
  p3: 11
  pending: 0
  ready: 0
  skipped: 0
  applied: 7
  deferred: 5
---

# Review Findings — 2026-11-05 12:02

No `cepa.local.md` in this repo: the stack was inferred (bash, Python, markdown).
Tracked residuals #16, #17 and #19 of the bounded-builds review were re-read and
not re-filed.

## Findings

### 1
- status: applied
- severity: P2
- agent: adversarial-reviewer, reliability-reviewer
- category: Reliability
- confidence: 75
- action_class: corroborated
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 242-262
- title: The Setup-tab wait ends when the tab appears, not when setup ends

**Problem:**
A tab can show while setup still waits on the build lock. The step had no rule for that, and `preview` is shorter than a refused line.

**Fix:**
The step now reads the whole tab with `orca-ide terminal read`, says a running tab is no result, names the end of setup, and bounds a quiet tab. A tab that closes before it is read counts as never shown.

### 2
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Regression
- confidence: 90
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 375-390
- title: A project with nothing to build queued on the build lock

**Problem:**
The first cut treated an empty built list as a build, so a pull-only project waited on the lock and could be refused. The old code skipped it.

**Fix:**
A readable project with services and no `build:` section skips with no lock. A project with no services, or an unknown read, still builds.

### 3
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Reliability
- confidence: 85
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 367-372
- title: env_file made the read fail during setup

**Problem:**
Setup reads before it writes `.env`, so `env_file: .env` failed the read and the promised skip never fired.

**Fix:**
The read passes `--no-env-resolution`. Measured on Compose 5.5.1: it reads with `.env` missing, and `env_file` values leave the JSON (`grep -c fromfile` 0 against 1).

### 4
- status: applied
- severity: P3
- agent: adversarial-reviewer, reliability-reviewer
- category: Documentation
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 126-132
- title: Item 7 did not say that --foreground bounds only the direct child

**Problem:**
A grandchild can outlive the bound, and item 7 dropped the `-k` and `</dev/null` of L78's own fix.

**Fix:**
Item 7 now states the limit and adds `-k <n>` and `</dev/null`.

### 5
- status: deferred
- severity: P3
- agent: silent-failure-hunter, previous-comments-reviewer
- category: Diagnostics
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 367-376
- title: One message covers every failed read, and both stderr streams are dropped

**Problem:**
A Compose error and a missing python3 read the same. The safe build still runs.

**Fix:**
Carry the first stderr line through `cepa_sg_clean`. Filed in the shard, with bounded-builds item 3.

### 6
- status: deferred
- severity: P3
- agent: reliability-reviewer
- category: Reliability
- confidence: 40
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 367-372
- title: A compose descendant could hold the read's pipe past the bound

**Problem:**
`--foreground` signals only the direct child. Not confirmed for `docker compose`.

**Fix:**
Measure whether compose leaves a child, then decide. Filed in the shard.

### 7
- status: deferred
- severity: P3
- agent: comment-analyzer
- category: Documentation
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 1993-1995
- title: §12b rule 2 does not cite the new wait

**Problem:**
A reader of rule 2 alone reads the tab once.

**Fix:**
Cite "Reading the `Setup` tab". Out of bounds for this worker: another session has the file open. Filed in the shard.

### 8
- status: applied
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 80
- action_class: mechanical
- file: scripts/check-lane-stack-controls.sh
- title: Three SETUP tokens had no mutant

**Problem:**
`start no worker`, `tell the operator` and `scripts.setup` could leave the case unseen.

**Fix:**
Added `tab-no-worker-gone`, `tab-operator-gone` and `tab-no-setup-check`.

### 9
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 65
- action_class: judgment
- file: scripts/check-lane-stack.sh
- title: The bare-timeout case is a loose line match

**Problem:**
It reads only yaml and make fences, and any `-T` plus `</dev/null` on a line passes.

**Fix:**
Optional: match `-T` as a word and scan more fences. Filed in the shard.

### 10
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 60
- action_class: judgment
- file: scripts/check-stack-gate-controls.sh
- title: No targeted mutant for the name and services subscripts

**Problem:**
Only the whole-branch mutant kills those cases.

**Fix:**
The proposed `.get` mutants still build by another path, so they stay green and prove nothing. Filed in the shard.

### 11
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Documentation
- confidence: 60
- action_class: mechanical
- file: scripts/check-lane-stack.sh
- lines: 50-54
- title: The SETUP header named the section, not the paragraph

**Problem:**
The code reads one paragraph, not the whole Setup section.

**Fix:**
Reworded. The stub docstring now says "no stdout" too.

### 12
- status: applied
- severity: P3
- agent: architecture-reviewer, comment-analyzer
- category: Style
- confidence: 60
- action_class: corroborated
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 257-260
- title: One line in the refused paragraph was not wrapped

**Problem:**
The edit left one long line.

**Fix:**
Re-wrapped.

---

**Summary:** 12 findings (0 P1, 1 P2, 11 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
