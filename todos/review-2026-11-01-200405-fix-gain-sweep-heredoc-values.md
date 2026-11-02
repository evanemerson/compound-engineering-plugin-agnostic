---
date: 2026-11-01T20:04:05
scope: pr:#121
branch: fix/gain/sweep-heredoc-values
agents:
  - security-sentinel
  - adversarial-reviewer
  - previous-comments-reviewer
  - comment-analyzer
config: "no cepa.local.md in this worktree — inferred roster; scope PR #121 head fe3bd4d, diff origin/main...fe3bd4d"
learnings_research: "skipped — docs/solutions/ is absent in this worktree (docs/ is gitignored)"
agents_skipped:
  - agent: learnings-researcher
    reason: "docs/solutions/ is absent in this worktree"
  - agent: performance-oracle
    reason: "no query, ORM or frontend code"
  - agent: python-reviewer
    reason: "no Python changed"
  - agent: data-integrity-guardian
    reason: "no migrations or data stores"
  - agent: schema-drift-detector
    reason: "no models or migrations"
  - agent: frontend-reviewer
    reason: "no templates, JS or CSS"
  - agent: deployment-verifier
    reason: "nothing deploys from this repo"
  - agent: architecture-reviewer
    reason: "one command block rewritten in place; no module boundary changes"
  - agent: silent-failure-hunter
    reason: "inferred roster; adversarial-reviewer traced every SKIP and failure path"
  - agent: pr-test-analyzer
    reason: "no test files; the author's hostile-value runs are in the PR body"
  - agent: type-design-analyzer
    reason: "no types added"
  - agent: code-simplifier
    reason: "inferred roster"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "shell block that handles untrusted repo data (injection fix)"
  - agent: reliability-reviewer
    dispatched: false
    reason: "signal absent — no queue, webhook, transaction or network code"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; the PR closes part of review-2026-10-31-230000 finding 5"
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
  total: 7
  p1: 0
  p2: 1
  p3: 6
  pending: 0
  ready: 0
  skipped: 0
  applied: 6
  deferred: 1
  completed: 0
---

# Review Findings — 2026-11-01 20:04 — PR #121 (L50, sweep.md heredoc values)

### 1
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: correctness
- confidence: 70
- action_class: judgment
- file: plugins/cepa/commands/sweep.md
- lines: the CEPA_BRANCH heredoc in the merged-branch block
- title: An indented paste never closes the heredoc, so no block in the paste runs

**Problem:**
The heredoc ends only on a line that is exactly `CEPA_BRANCH`. A copy from a terminal that indents output puts spaces before it, so bash reads all later lines, later blocks included, as heredoc data. Reproduced with two blocks at a 3-space indent: only `here-document … delimited by end-of-file`, rc=0, nothing deleted. It fails closed, but the old `b='<branch>'` block ran when indented.

**Fix:**
Applied: a "Paste the block with no indentation" bullet beside the block. It states the fail-closed behavior and points to the report file a headless run writes. A heredoc-free hex encoding was rejected: it puts agent-filled text back in a quoted string.

### 2
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: bookkeeping
- confidence: 90
- action_class: corroborated
- file: memory/tasks.d/2026-10-31-refactor-roles-send-block-stdin.md
- lines: 12
- title: The narrowed residual line misdescribes the compound.md site, and its probe misses it

**Problem:**
The line said `compound.md` used `'<short-run-id>'`. The real sites are `RUN="<short-run-id>"` (251, 325, 548) and `REPO="<repo>"; DOC="<doc-path>"` (322), in double quotes. The probe `grep -n "='<"` returns no `compound.md` hit. comment-analyzer reported the same.

**Fix:**
Applied: the line names the double-quoted sites, and the probe is `grep -nE "=['\"]<" plugins/cepa/commands/*.md plugins/cepa/skills/autonomy/SKILL.md`, which shows them.

### 3
- status: applied
- severity: P3
- agent: comment-analyzer
- category: documentation
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/commands/sweep.md
- lines: first bullet after the merged-branch block
- title: "Up to this change" is time-relative wording

**Problem:**
"Up to this change" means nothing to a later reader.

**Fix:**
Applied: "Before cepa 1.49.1".

### 4
- status: applied
- severity: P3
- agent: comment-analyzer
- category: documentation
- confidence: 60
- action_class: judgment
- file: plugins/cepa/commands/sweep.md
- lines: the `--verify --quiet` bullet
- title: The `|| true` on the rev-parse line is not explained

**Problem:**
A maintainer could remove `|| true` as redundant. Without it, an absent branch ends a `set -e` shell before the SKIP.

**Fix:**
Applied: one sentence in the `--verify --quiet` bullet says why it stays.

### 5
- status: applied
- severity: P3
- agent: comment-analyzer
- category: documentation
- confidence: 55
- action_class: corroborated
- file: plugins/cepa/commands/sweep.md
- lines: "State the run date in the block" paragraph
- title: "(above)" points at a comment that no longer exists

**Problem:**
The `# Snapshot taken <run-date>` comment is gone. The date is now the `taken:` field, and the block prints it only on the tip-mismatch SKIP. previous-comments-reviewer reported the same cue as weaker.

**Fix:**
Applied: "(the `taken:` field)". The operator-facing cue stays as it is. The date is in the block the operator pastes.

### 6
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: bookkeeping
- confidence: 60
- action_class: mechanical
- file: todos/review-2026-10-31-230000.md
- lines: finding 5 `lines:` field
- title: Finding 5 still lists the closed sweep.md:510 site as open

**Problem:**
`lines: 510; autonomy §11b; compound.md` still named the fixed site.

**Fix:**
Applied: `lines: autonomy §11b; compound.md (sweep.md:510 closed by L50, 1.49.1)`.

### 7
- status: deferred
- severity: P3
- agent: security-sentinel
- category: security
- confidence: 60
- action_class: judgment
- file: plugins/cepa/commands/sweep.md
- lines: the SKIP echo lines of the merged-branch block
- title: SKIP lines print refused values raw to the terminal

**Problem:**
`$b`, `$want`, `$bad` and `$taken` are echoed unsanitized on the SKIP paths, which is where malformed values land. Escape bytes in a bad head or run-date value would reach the terminal. A real branch name cannot hold control characters, so this is defense in depth only.

**Fix:**
Deferred to `memory/tasks.d/2026-11-01-fix-gain-sweep-heredoc-values.md`: print through `printf '%q'` or strip control characters. It changes the operator-facing output, so the operator decides.

---

**Summary:** 7 findings (0 P1, 1 P2, 6 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
