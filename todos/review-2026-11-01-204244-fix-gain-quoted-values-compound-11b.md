---
date: 2026-11-01T20:42:44
scope: pr:#124
branch: fix/gain/quoted-values-compound-11b
agents:
  - security-sentinel
  - adversarial-reviewer
  - previous-comments-reviewer
  - comment-analyzer
config: "no cepa.local.md — inferred roster for a shell-quoting fix in markdown fenced blocks"
learnings_research: "skipped — docs/solutions/ is absent in this worktree (docs/ is gitignored)"
agents_skipped:
  - agent: performance-oracle
    reason: "no query, ORM or frontend code"
  - agent: python-reviewer
    reason: "inline Python only in a checker; adversarial-reviewer traced its fixtures"
  - agent: architecture-reviewer
    reason: "no module boundaries change; the shape copies PR #121"
  - agent: data-integrity-guardian
    reason: "no migrations or data stores"
  - agent: schema-drift-detector
    reason: "no models or migrations"
  - agent: frontend-reviewer
    reason: "no templates, JS or CSS"
  - agent: deployment-verifier
    reason: "nothing deploys from this repo"
  - agent: pr-test-analyzer
    reason: "adversarial-reviewer was briefed on checker fixtures and mutants"
  - agent: silent-failure-hunter
    reason: "inferred roster; fail-closed paths traced by adversarial-reviewer"
  - agent: type-design-analyzer
    reason: "no types added"
  - agent: code-simplifier
    reason: "inferred roster"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "an injection fix in blocks an agent runs"
  - agent: reliability-reviewer
    dispatched: false
    reason: "signal absent: no queue, webhook, transaction or network code"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; the PR closes finding 5 of review-2026-10-31-230000"
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
  corpus: absent
summary:
  total: 10
  p1: 0
  p2: 0
  p3: 10
  pending: 0
  ready: 0
  skipped: 0
  applied: 9
  deferred: 1
  completed: 0
---

# Review Findings — 2026-11-01 20:42 — PR #124 (L59, compound.md and §11b heredoc values)

### 1
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: test-coverage
- confidence: 90
- action_class: corroborated
- file: scripts/check-dispatch-isolation.sh
- lines: fixture list and mutant list
- title: No fixture or mutant covers the new §11b run/mode heredoc

**Problem:**
Every fixture fed a plain value into the field lines. Deleting `[ -z "$bad" ] || run=` from the cleanup, or putting back `run='<run>'`, left the checker green.

**Fix:**
Applied: fixtures `snapshot-stray-line`, `cleanup-stray-line` (a valid snapshot beside a bad cleanup block, via a new `clean_mode`) and `quoted-run` (a `'` and `touch PWNED` in `<run>`). Mutants `quoted-run-mode`, `no-bad-guard` and `no-snapshot-bad-report` (a new `snap` mutant kind). 76/76; each new mutant is killed by its own fixture.

### 2
- status: applied
- severity: P3
- agent: adversarial-reviewer, security-sentinel
- category: correctness
- confidence: 85
- action_class: corroborated
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: §11b intro paragraph and cleanup block
- title: §11b prose promised a visible signal an indented paste never gives, and the cleanup named the wrong cause

**Problem:**
An indented paste never closes `CEPA_RUN`, so the block prints nothing (rc=0), not `SNAPSHOT-FAILED`. With a bad run/mode block and a valid snapshot, the cleanup said `no pre-dispatch snapshot`. Both fail closed.

**Fix:**
Applied: the cleanup prints `CLEANUP-FAILED: a line in the run/mode block is not a field; every candidate is kept`. A new paragraph says to paste unindented, that an indented paste prints nothing and changes nothing, and that a snapshot that printed no line did not run.

### 3
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: correctness
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/commands/compound.md
- lines: the RUN, REPO and DOC case guards
- title: A placeholder literal in a guard rejects a correct value after a replace-all

**Problem:**
`case "$REPO" in ''|'<repo>'|…`: an agent that replaces every `<repo>` in the block turns that arm into the real value, and the block aborts on a correct value. Reproduced for REPO and DOC; RUN had the same shape before this PR.

**Fix:**
Applied: the `'<short-run-id>'`, `'<repo>'` and `'<doc-path>'` arms are gone. The character class (`<` is outside it) and `[ -f "$DOC" ]` still refuse an unreplaced placeholder. A comment records why.

### 4
- status: deferred
- severity: P3
- agent: security-sentinel, adversarial-reviewer
- category: security
- confidence: 80
- action_class: judgment
- file: plugins/cepa/commands/compound.md
- lines: the three CEPA_RUN heredocs; autonomy §11b's two
- title: A value line that is exactly CEPA_RUN still ends the heredoc early

**Problem:**
A value with a line break and a line `CEPA_RUN` closes the heredoc, and the lines after it run. Reproduced. Same fixed-delimiter limit as PR #121's `CEPA_BRANCH`; the values are an agent-chosen id, a repo name and a path, not relayed content. Prose states the one-line rule.

**Fix:**
Deferred: a per-run delimiter the session invents (`<<'CEPA_RUN_<hex>'`, as L41 did for `CEPA_BODY`) is an interface change across sweep.md, compound.md and §11b. Filed to memory/tasks.d/2026-11-01-fix-gain-quoted-values-compound-11b.md.

### 5
- status: applied
- severity: P3
- agent: security-sentinel
- category: correctness
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/commands/compound.md
- lines: the non-field abort message in the three blocks
- title: An empty value gets the indentation message, not the empty-field one

**Problem:**
`read` strips trailing space, so `doc: ` becomes `doc:`, which is not a field; the `''` arms are unreachable for an empty value.

**Fix:**
Applied: the message reads "not a field line, or a field left empty (paste with no indentation, one value per line)".

### 6
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: bookkeeping
- confidence: 85
- action_class: mechanical
- file: todos/review-2026-10-31-230000.md
- lines: finding 5 and its summary counters
- title: Finding 5 still read deferred and "still open"

**Problem:**
The shard line was closed but the findings file said `status: deferred`.

**Fix:**
Applied: finding 5 is `applied` with a "Fully applied … PR #124" note; counters applied 8→9, deferred 3→2.

### 7
- status: applied
- severity: P3
- agent: previous-comments-reviewer, comment-analyzer
- category: bookkeeping
- confidence: 60
- action_class: corroborated
- file: memory/tasks.d/2026-10-31-refactor-roles-send-block-stdin.md
- lines: 12
- title: The closed shard line broke the neighbours' format and kept stale line numbers

**Problem:**
It named a branch, not a PR, put the severity after the closure prose, and kept pre-L59 line numbers.

**Fix:**
Applied: `CLOSED in PR #124 (L59, 1.50.1) — P3 — <paths> — <problem>. Closed: <how>. Probe: <cmd>`, with no line numbers. Striking L59 in the punch list is coord@main's.

### 8
- status: applied
- severity: P3
- agent: comment-analyzer
- category: documentation
- confidence: 80
- action_class: mechanical
- file: plugins/cepa/commands/compound.md
- lines: the field-block comment in the mint block
- title: The comment said a line break ends the heredoc early

**Problem:**
Only a line exactly `CEPA_RUN` ends it early; a line break adds a non-field line, which stops the block.

**Fix:**
Applied: the comment states both cases separately.

### 9
- status: applied
- severity: P3
- agent: comment-analyzer
- category: documentation
- confidence: 65
- action_class: judgment
- file: plugins/cepa/commands/compound.md
- lines: the scrub block's comments
- title: The pointer comment sat far from its lines, and "everything else is re-derived" was wrong

**Problem:**
The new guards separated "Re-read the payload path…" from `PTR=`, and `repo:`/`doc:` are substituted literals, not derived from RUN.

**Fix:**
Applied: the comment moved above `PTR=`; the comment above says RUN is the one value that has to match across blocks and repo/doc are used only in this block.

### 10
- status: applied
- severity: P3
- agent: comment-analyzer
- category: documentation
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/commands/compound.md
- lines: the RUN comment in the mint block; §11b intro
- title: Two over-long lines after the rewrap

**Problem:**
Cosmetic.

**Fix:**
Applied: both rewrapped (the §11b paragraph was rewritten for finding 2).

---

**Summary:** 10 findings (0 P1, 0 P2, 10 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
