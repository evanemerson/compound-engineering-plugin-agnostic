---
date: 2026-11-02T22:55:16
scope: fix/matrix/check-full (PR #132)
branch: fix/matrix/check-full
agents:
  - adversarial-reviewer
  - previous-comments-reviewer
  - pr-test-analyzer
summary:
  total: 10
  p1: 0
  p2: 4
  p3: 6
  pending: 0
  ready: 0
  skipped: 2
  applied: 5
  deferred: 3
  completed: 0
agents_skipped:
  - agent: security-sentinel
    rule: "no auth, PHI or payment surface: skill prose, a fixed nudge line and test checkers"
  - agent: python-reviewer
    rule: "no Python application code: the Python is test tooling, covered by pr-test-analyzer"
  - agent: performance-oracle
    rule: "no queries or request paths"
  - agent: data-integrity-guardian
    rule: "no migrations or models"
  - agent: schema-drift-detector
    rule: "no models, migrations, serializers, forms or admin"
  - agent: frontend-reviewer
    rule: "no templates, JS/CSS or components"
  - agent: deployment-verifier
    rule: "nothing deploys from this repo; the change is plugin content"
  - agent: architecture-reviewer
    rule: "no module boundary change: flag edits in existing rules, one script line and checker legs"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff is about 440 changed lines"
  - agent: reliability-reviewer
    dispatched: false
    reason: "signal absent: no queue, webhook, lock, transaction or network code"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; the diff closes #131 finding 4"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped: nothing deploys from this repo"
  conditions: []
learnings_research: "ok — no solution corpus (docs/solutions absent); briefing from CLAUDE.md, memory/tasks.d, todos"
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  corpus: absent
  note: "docs/solutions/ does not exist in this worktree (docs/ is gitignored)"
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
cepa_local_md: "missing — the stack was inferred (bash scripts + Python test tooling)"
---

# Review Findings — 2026-11-02 22:55

## Findings

### 1
- status: applied
- severity: P2
- agent: adversarial-reviewer, pr-test-analyzer
- category: Test tooling
- confidence: 85
- action_class: corroborated
- file: scripts/check-orca-turn-endings.sh
- lines: 348-390
- title: FULL leg missed a span wrapped between `check` and its flag, and naive backtick pairing could desync

**Problem:**
`` `([^`]*\bcheck --[^`]*)` `` needs one literal space, so a hard-wrapped
`check\n     --wait` span was never read. Pairing backticks by regex also
let an earlier span shift the pairing onto prose, so a real `check --wait`
was never checked.

**Fix:**
`\bcheck\s+--`; spans paired as CommonMark pairs them (equal backtick
runs, one paragraph) outside fences, and each fenced line read whole.
Mutants `full-wrapped-site`, `full-desync` and `full-fenced-site`.

### 2
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 70
- action_class: mechanical
- file: scripts/check-orca-turn-endings-controls.sh
- lines: 419-421
- title: full-unbound-check stayed green, so the no-bound-Run `check --full` was unpinned

**Problem:**
A bare `check` span is a prose reference FULL cannot see, so dropping
`--full` from "Its plain `check --full` returns no `deliveryId`" passed.

**Fix:**
The sentence is in PEEK_HAS; the mutant now expects that PEEK MISS.

### 3
- status: deferred
- severity: P2
- agent: adversarial-reviewer
- category: Delivery loss
- confidence: 75
- action_class: judgment
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 2767-2775
- title: on 1.4.246 a bound-Run drain whose output is lost loses its batch; the stated limit said "never a loss"

**Problem:**
A `check --full` drain returns `deliveryAcknowledged: true` and marks the
batch read itself (measured). If the WSL interop error or a timeout eats
its output, the next `--ack` returns `deliveryId: null` and the messages
are gone. Only sessions with no bound Run process from their peek first.

**Fix:**
Applied: the stated limit now says the "never a loss" claim no longer
holds on 1.4.246. Deferred (rule change, coordinator's call): make every
session process from its peek first. Residual item 5 of
`memory/tasks.d/2026-11-03-fix-matrix-check-full.md`.

### 4
- status: applied
- severity: P2
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 85
- action_class: mechanical
- file: todos/review-2026-11-02-214114-fix-roles-orca-full-reads.md
- lines: 153
- title: #131 finding 4 and its residual item stayed open though this PR closes them

**Problem:**
Finding 4 was still `deferred` and item 1 of the #131 shard still open.

**Fix:**
Finding 4 `applied` (counters 5/5); item 1 struck through with the PR.
Punch-list L73 is coord@main's to close (sole writer).

### 5
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Test tooling
- confidence: 90
- action_class: mechanical
- file: scripts/check-orca-turn-endings.sh
- lines: 386
- title: FULL flagged `<cli> orchestration check --help` as a MISS

**Problem:**
The exemption compared the whole span to `check --help`.

**Fix:**
Any span whose tokens hold `--help` is exempt; control
`full-help-long-exempt`.

### 6
- status: deferred
- severity: P3
- agent: adversarial-reviewer
- category: Measurement gap
- confidence: 50
- action_class: judgment
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 2586-2596
- title: whether Orca 1.4.245 accepts `--full` on `check` is unmeasured, yet `--ack` is kept for it

**Problem:**
If 1.4.245 rejects the flag, every peek, drain and wait fails there.

**Fix:**
Measure on 1.4.245 or state one support floor. Residual item 6.

### 7
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 55
- action_class: judgment
- file: scripts/fixtures/orca-short-shape.py
- lines: 81-88
- title: the fixture's `check` verb has no checker case

**Problem:**
No script runs `check`, so no stub calls `short("check", …)`.

**Fix:**
Add a case once a script reads `check`. Residual item 7. The transform
was compared by hand with the real short output (identical).

### 8
- status: applied
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 40
- action_class: judgment
- file: scripts/check-orca-turn-endings-controls.sh
- lines: 430-432
- title: no control for a `check` command inside a fenced block

**Problem:**
Fenced lines were read only by accident of the old pairing.

**Fix:**
Control `full-fenced-site` (with finding 1's fence-aware read).

### 9
- status: skipped
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 30
- action_class: judgment
- file: scripts/check-orca-nudge-controls.sh
- lines: 60-66
- title: send-drops-full has the same expected set as send-content-spliced

**Problem:**
The two mutants share a MISS set.

**Fix:**
None: both change the exact typed TEXT, so the same cases fail for each.

### 10
- status: skipped
- severity: P3
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 50
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: 228-229
- title: script headers may still say `check` was not measured

**Problem:**
The reviewer did not verify the header wording.

**Fix:**
None: the three headers already cite rule 8 instead (`git show
7ffc48c:plugins/cepa/scripts/orca-send.sh | sed -n 228,229p`).

---

**Summary:** 10 findings (0 P1, 4 P2, 6 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
