---
date: 2026-11-27T19:44:33
scope: fix/formulation/agent-worktree-leftovers (PR #147)
branch: fix/formulation/agent-worktree-leftovers
agents:
  - adversarial-reviewer
  - architecture-reviewer
  - previous-comments-reviewer
  - pr-test-analyzer
  - comment-analyzer
summary:
  total: 18
  p1: 0
  p2: 9
  p3: 9
  pending: 0
  ready: 0
  skipped: 0
  applied: 13
  deferred: 5
  completed: 0
agents_skipped:
  - agent: security-sentinel
    rule: "no auth, PHI or payment surface: a git cleanup block in a skill plus its checker; adversarial-reviewer covered the deletion paths"
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
  - agent: silent-failure-hunter
    rule: "fail-closed guard paths were covered by adversarial-reviewer and pr-test-analyzer"
  - agent: code-simplifier
    rule: "small diff in an established block shape; mutant anchors depend on exact text"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "the diff adds a branch-deletion path to a shipped cleanup block"
  - agent: reliability-reviewer
    dispatched: false
    reason: "signal absent: no queue, webhook, lock, transaction or network code"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; the diff touches §11b (L14, L59) and L96"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped: nothing deploys from this repo"
  conditions: []
learnings_research: "skipped — no docs/solutions corpus in this worktree (docs/ is gitignored); briefing taken from CLAUDE.md, memory/tasks.d and todos by previous-comments-reviewer"
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  corpus: absent
  note: "docs/solutions/ does not exist in this worktree"
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
cepa_local_md: "missing — the stack was inferred (markdown + bash, Python test tooling)"
---

# Review Findings — 2026-11-27 19:44

Reviewed head `16e54bc`. Fixes are on the branch's next commit.

## Findings

### 1
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: Data loss
- confidence: 85
- action_class: judgment
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 1417-1435
- title: the gone path deleted the only reflog that still reached a commit not on origin

**Problem:** An agent commits, resets its branch back to an origin commit, and the harness removes the worktree. The tip is then on origin, so the gone path deleted the branch and its reflog. The commit was then unreachable. The adversarial reviewer reproduced this in a throwaway repo.

**Fix:** Applied. The gone path now reads `git log -g refs/heads/<branch>` and keeps the branch when the reflog is unreadable or holds a commit no origin ref has. Fixture `harness-removed-reflog-lost` and mutant `no-gone-reflog-check` were added.

### 2
- status: applied
- severity: P2
- agent: architecture-reviewer
- category: Contract drift
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/commands/review.md
- lines: 557-560
- title: review.md said `<ids>` is "normally none", against the new §11b rule

**Problem:** A reader isolated by a project rule or a hook must have its id passed. The old wording invited an empty list, which is candidate U1(a) for the dpc-pro folders.

**Fix:** Applied. The wording is now "every dispatch of this run that ran isolated, whether cepa asked for it or a project rule or hook forced it (§11b)". No other command site words the ids (`grep -n "ids>\|agent ids"` over the other §11b sites found none).

### 3
- status: applied
- severity: P2
- agent: comment-analyzer, pr-test-analyzer, architecture-reviewer
- category: Guard gap
- confidence: 85
- action_class: corroborated
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 1419-1421
- title: the gone path skipped the "existed before this run's dispatch" snapshot check

**Problem:** §11c says the branch counts as the run's only when its worktree was absent from the snapshot. The gone path never read the snapshot.

**Fix:** Applied. A path that was in the snapshot is now `KEPT …: gone now, but existed before this run's dispatch`. Fixture `harness-removed-pre-existing` and mutant `no-gone-prior` were added.

### 4
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 85
- action_class: mechanical
- file: scripts/check-dispatch-isolation.sh
- lines: 270-278
- title: the gone path's `git branch -D failed` branch was untested

**Problem:** No stub made `git branch -D` fail.

**Fix:** Applied. Added the `branchd-fail` stub, fixture `harness-removed-delete-fails` and mutant `gone-delete-fail-reports-deleted`.

### 5
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 80
- action_class: mechanical
- file: scripts/check-dispatch-isolation.sh
- lines: 480-500
- title: report mode was tested only with a tip on origin

**Problem:** Nothing pinned that the tip check runs before the report-mode check.

**Fix:** Applied. Added fixture `harness-removed-unique-tip-report` and mutant `gone-mode-before-tip`.

### 6
- status: applied
- severity: P2
- agent: comment-analyzer
- category: Absence claim
- confidence: 80
- action_class: mechanical
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 1226-1230
- title: the §11 measured table did not state its probe

**Problem:** CLAUDE.md requires the probe beside the measurement.

**Fix:** Applied. A probe sentence now precedes the table.

### 7
- status: applied
- severity: P2
- agent: comment-analyzer
- category: Unmeasured claim
- confidence: 75
- action_class: mechanical
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 1238-1241
- title: the branch base was presented as measured

**Problem:** The session HEAD and `origin/main` were the same commit, so the probe could not tell them apart.

**Fix:** Applied. The base now cites Claude Code's worktree docs and states that the probe could not distinguish it.

### 8
- status: applied
- severity: P2
- agent: comment-analyzer
- category: Unmeasured claim
- confidence: 70
- action_class: mechanical
- file: memory/tasks.d/2026-11-27-fix-formulation-agent-worktree-leftovers.md
- lines: 33-36
- title: the 39-branch arithmetic assumed one branch per folder

**Problem:** The counts are sender-reported, and the subtraction holds only if each folder has its own branch.

**Fix:** Applied. U1 now states that condition and labels the counts.

### 9
- status: applied
- severity: P3
- agent: adversarial-reviewer, pr-test-analyzer
- category: Guard gap
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 1419
- title: a dangling symlink at the path counted as gone

**Problem:** `[ ! -e ]` is true for a dangling symlink, which broke "a path that exists is kept".

**Fix:** Applied. The test is now `[ ! -e "$wt" ] && [ ! -L "$wt" ]`. Added fixture `harness-removed-symlink` and mutant `no-gone-symlink-check`.

### 10
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Overclaim
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 1242-1245
- title: "the lock is gone once the agent returns" was stated generally

**Problem:** The claim should name the case it was seen in.

**Fix:** Applied. It now says the kept worktree from row 3 had no `locked` line after return. That was measured on that worktree before its removal.

### 11
- status: applied
- severity: P3
- agent: architecture-reviewer, adversarial-reviewer
- category: Doc accuracy
- confidence: 75
- action_class: corroborated
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 1540-1546
- title: §11c said "its reflog went with it, so the branch tip alone is checked"

**Problem:** The branch's own reflog survives harness removal (finding 1).

**Fix:** Applied. The text now says the branch's tip and its own reflog are checked, and the bullet was rewrapped.

### 12
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Style
- confidence: 80
- action_class: mechanical
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 1532-1560
- title: two over-long lines after in-place edits

**Problem:** The same class as an earlier applied finding.

**Fix:** Applied. Both lines are rewrapped. `awk 'NR>1500 && NR<1570 && length>80'` prints nothing.

### 13
- status: applied
- severity: P3
- agent: previous-comments-reviewer, architecture-reviewer, comment-analyzer
- category: Tracking
- confidence: 70
- action_class: corroborated
- file: memory/tasks.d/2026-11-27-fix-formulation-agent-worktree-leftovers.md
- lines: 21-25
- title: the old shard's "unmeasured" item was left without a pointer; U1(a) was unsourced

**Problem:** A reader of `2026-10-21-fix-roles-review-agent-worktrees.md` item 2 still saw "unmeasured", and U1(a) said "likely" with no source.

**Fix:** Applied. The new shard says that it supersedes that item, and U1(a) now cites L15's relayed record. The old shard is not edited, so this branch's edits stay in its own shard.

### 14
- status: deferred
- severity: P3
- agent: architecture-reviewer
- category: Doc pointer
- confidence: 60
- action_class: judgment
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 1246-1256
- title: the §11 intro does not say that forced isolation makes §11b depend on `<ids>`

**Problem:** That dependency is the main open failure mode, and only §11b states it.

**Fix:** Add one clause that cites §11b's `<ids>` sentence. Filed in the run's shard.

### 15
- status: deferred
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 75
- action_class: judgment
- file: scripts/check-dispatch-isolation.sh
- lines: 309-313
- title: the gone path's tip test is pinned only at a tip that equals an origin ref

**Problem:** A `--points-at` mutant would survive, because every fixture branch tip is an origin ref's own tip.

**Fix:** Add a fixture commit that is an ancestor of an origin ref but no ref's tip. Filed in the run's shard.

### 16
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 70
- action_class: judgment
- file: scripts/check-dispatch-isolation.sh
- lines: 482
- title: no unknown-mode fixture on the gone path

**Problem:** The mode is normalized earlier, so the risk is low.

**Fix:** Add `Case("harness-removed-unknown-mode", harness_removed_report, mode="delete")`. Filed in the run's shard.

### 17
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 50
- action_class: judgment
- file: scripts/check-dispatch-isolation.sh
- lines: 482
- title: no `agent-a1` / `agent-a10` prefix-collision fixture

**Problem:** The `$nl` anchors make a bug unlikely, but nothing pins it.

**Fix:** Add the fixture. Filed in the run's shard.

### 18
- status: deferred
- severity: P3
- agent: adversarial-reviewer
- category: Known limit
- confidence: 40
- action_class: judgment
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 1419-1435
- title: the snapshot holds worktrees, not branches

**Problem:** A miscopied id can name another session's branch in the moment between `git worktree add -b` and its registration. §11c already says a miscopied id passes every guard. That text now names the gone path too.

**Fix:** Option: also snapshot `refs/heads/worktree-agent-*` and delete only a branch absent from it. Filed in the run's shard.

---

**Summary:** 18 findings (0 P1, 9 P2, 9 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
