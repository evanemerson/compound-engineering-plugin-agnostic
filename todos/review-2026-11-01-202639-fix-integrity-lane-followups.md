---
date: 2026-11-01T20:26:39
scope: pr:123
branch: fix/integrity/lane-followups
agents:
  - security-sentinel
  - architecture-reviewer
  - silent-failure-hunter
  - adversarial-reviewer
  - reliability-reviewer
  - previous-comments-reviewer
config: "cepa.local.md read from the main checkout (gitignored, absent in this worktree)"
learnings_research: "skipped — docs/solutions/ is absent in this worktree (docs/ is gitignored)"
agents_skipped:
  - agent: performance-oracle
    reason: "not rostered in cepa.local.md"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "about 1400 diff lines; rm relaxes a deletion guard"
  - agent: reliability-reviewer
    dispatched: true
    signal: "new bounded gh and git fetch calls; create resume after partial failure"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; the PR closes six deferred findings of todos/review-2026-11-01-181000.md"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier not rostered; nothing deploys from this repo"
detection_signals:
  count: 0
  source_docs: 0
  backfill_candidates: 0
  suspect_bullets: 0
  corpus: not-consulted
brain:
  status: skipped
  reason: "researcher skipped; no recall run"
dropped_below_anchor: 0
validation_drops: 0
summary:
  total: 15
  p1: 1
  p2: 5
  p3: 9
  applied: 13
  deferred: 2
  pending: 0
---

# Review — PR #123 (L58 lane follow-ups)

Six agents on head 1d38ad2. One P1, raised by five of the six agents, and
reproduced by the adversarial reviewer. All fixes are in the follow-up commit.
After that commit, both real lanes still pass: integrity 49/49 and roles
100/100. The checker passes 122/122 and the controls 60/60. The two deferred
items are in `memory/tasks.d/2026-11-01-fix-integrity-lane-followups.md`.

### 1
status: applied
severity: P1
agent: adversarial-reviewer, security-sentinel, silent-failure-hunter, reliability-reviewer, previous-comments-reviewer
category: Data loss
confidence: 95
action_class: corroborated
file: plugins/cepa/scripts/orca-lane-reflog.sh
lines: the vouch rule (the python date test)
title: A merged PR vouched for a commit that was never in it

**Problem:** A commit counted as landed when the branch that held it had a MERGED PR with mergedAt at or after the commit's date. That does not show the PR contained the commit. Reproduced: push, commit locally, the PR merges from the pushed head, park, and the helper exits 0. rm would then delete the only pointer to the unpushed commit. Branch-name reuse, clock skew, a backdated committer date, a detached `checkout --detach <b>`, and a ff-merge onto old commits all pass the same way.

**Fix:** Applied. Vouch only when the commit is an ancestor of the PR's final `headRefOid`, or an equal patch in it, where the PR is MERGED, same-repo, and into the default branch. The date test is gone. Branch attribution now only selects which PRs to ask about. Control: `RM unpushed commit the PR head lacks`, mutant `helper-ancestor-unchecked`.

### 2
status: applied
severity: P2
agent: adversarial-reviewer, security-sentinel
category: Data loss
confidence: 85
action_class: corroborated
file: plugins/cepa/scripts/orca-lane-reflog.sh
lines: patch_in
title: The patch-identity test passed a merge commit's own content

**Problem:** `git cherry` never lists merge commits. A merge whose parents had all landed passed as an equal patch, even when it added content. Reproduced.

**Fix:** Applied. `patch_in` refuses a range that holds a merge commit. Control: `RM merge commit whose parent landed`, mutant `helper-merge-guard-off`.

### 3
status: applied
severity: P2
agent: silent-failure-hunter
category: Silent failure
confidence: 85
action_class: mechanical
file: plugins/cepa/scripts/orca-lane.sh
lines: rm, the helper call
title: rm took helper exit 0 as landed without its output

**Problem:** A truncated or stub helper exits 0 with no output, and rm went ahead.

**Fix:** Applied. Only exit 0 with a `landed: ` line passes; anything else is the unknown refusal. Control: `RM helper exits 0 without a landed line`, mutant `rm-landed-line-unchecked`.

### 4
status: applied
severity: P2
agent: architecture-reviewer
category: Architecture
confidence: 85
action_class: mechanical
file: plugins/cepa/skills/autonomy/SKILL.md
lines: §12b rule 2, removal and create paragraphs
title: Rule 2 restated the guards and tests the script headers own

**Problem:** Rule 2 listed rm's guard set, the helper's vouching test, and the resume condition. Each one is owned by a header, so it would go stale silently.

**Fix:** Applied. Rule 2 now cites the headers. It keeps only the field contract it owns.

### 5
status: applied
severity: P2
agent: architecture-reviewer
category: Architecture
confidence: 75
action_class: mechanical
file: plugins/cepa/scripts/orca-lane.sh
lines: rm step 3 comment and header
title: "The same test as §11b" was false once the helper extended it

**Problem:** The rm comment and rule 2 called the reflog test §11b's own, but rm now extends that test.

**Fix:** Applied. The plain test is cited as §11b's, and the extension as the helper's.

### 6
status: applied
severity: P2
agent: previous-comments-reviewer, architecture-reviewer, reliability-reviewer
category: Reliability
confidence: 75
action_class: corroborated
file: plugins/cepa/scripts/orca-lane.sh
lines: STATED LIMITS, the helper call, the rm bound
title: The rm worst case was back near the 10-minute tool timeout, and the helper was unbounded

**Problem:** This re-broke #5 of the PR #118 review. The worst case read about 595 s against 600 s, and that excluded the helper's own unbounded local work.

**Fix:** Applied. The helper call is bounded at 60 s (its gh budget is 35 s) and the rm call at 300 s. The worst case is now about 575 s of bounded calls, plus local git work (measured at 2-10 s).

### 7
status: applied
severity: P3
agent: reliability-reviewer, adversarial-reviewer, silent-failure-hunter
category: Correctness
confidence: 80
action_class: corroborated
file: plugins/cepa/scripts/orca-lane-reflog.sh
lines: the reflog reader
title: Reflog attribution misread HEAD~1, renames and detached checkouts

**Problem:** `checkout HEAD~1` (and `@{-1}`) was read as a branch and made the whole lane exit 3. A branch rename was not tracked. `checkout --detach <b>` was attributed to <b>.

**Fix:** Applied. A target that is not a branch name is treated as detached, and `Branch: renamed` is tracked. Since #1, attribution can no longer vouch on its own. Control: `RM checkout HEAD~1 in the reflog`.

### 8
status: applied
severity: P3
agent: security-sentinel, silent-failure-hunter, reliability-reviewer
category: Correctness
confidence: 60
action_class: corroborated
file: plugins/cepa/scripts/orca-lane-reflog.sh
lines: the gh pr list call
title: A stacked or fork PR with the same head name could vouch

**Problem:** `--head <b>` matches by name only. The PR's base and its repository were not checked.

**Fix:** Applied. A PR vouches only when `baseRefName` is the default branch and `isCrossRepository` is false. Controls: `RM PR into another base` and `RM fork PR`.

### 9
status: applied
severity: P3
agent: previous-comments-reviewer, security-sentinel, silent-failure-hunter
category: Security
confidence: 50
action_class: corroborated
file: plugins/cepa/scripts/orca-lane.sh
lines: rm, the orca.yaml check
title: orca.yaml was compared with the upstream, and a skip-worktree edit was invisible

**Problem:** A main checkout on a feature branch passed against an unreviewed upstream. `skip-worktree` hides an edit from `git status`.

**Fix:** Applied. The working-tree file's hash must equal `origin/<default>:orca.yaml`. The default comes from origin/HEAD, or else from `ls-remote --symref` (10 s). Control: `RM main orca.yaml edited under skip-worktree`.

### 10
status: applied
severity: P3
agent: reliability-reviewer, silent-failure-hunter
category: Silent failure
confidence: 60
action_class: corroborated
file: plugins/cepa/scripts/orca-lane.sh
lines: create, the base re-fetch and the summary line
title: A failed base re-fetch was swallowed, and the summary claimed equality

**Problem:** After a failed fetch, the ahead-count refusal did not mention the fetch. The summary said "(origin/<base>)" when the lane could be behind it.

**Fix:** Applied. The refusal names the failed fetch and says a re-run resumes. The summary says "at or behind origin/<base>".

### 11
status: applied
severity: P3
agent: architecture-reviewer
category: Documentation
confidence: 60
action_class: mechanical
file: plugins/cepa/scripts/orca-lane.sh
lines: header, exit code 1
title: The exit 1 text said Orca was not asked to write, but name writes first

**Problem:** `name` exits 1 after it has written its renames.

**Fix:** Applied. The text now says so.

### 12
status: applied
severity: P3
agent: reliability-reviewer
category: Performance
confidence: 70
action_class: mechanical
file: plugins/cepa/scripts/orca-lane-reflog.sh
lines: the need computation
title: One rev-list and one log per reflog SHA

**Problem:** The helper made O(n) subprocess calls.

**Fix:** Applied. One `rev-list` over all the reflog SHAs finds the commits to test: a reflog commit reaches a commit origin lacks exactly when it is one itself. The date read is gone with #1.

### 13
status: applied
severity: P3
agent: previous-comments-reviewer
category: Documentation
confidence: 70
action_class: mechanical
file: todos/review-2026-11-01-181000.md
lines: intro and the six Resolution lines
title: The PR #118 findings file still read as if items were open

**Problem:** The intro said the six items were deferred. Two of the Resolution lines described the first cut.

**Fix:** Applied. The intro says L58 closed them, and both Resolution lines describe what landed.

### 14
status: deferred
severity: P3
agent: silent-failure-hunter
category: Test coverage
confidence: 60
action_class: judgment
file: scripts/check-orca-lane.sh
lines: RM, reused lanes
title: No case for a mixed git cherry result or the reached-by-a-landed-commit rule

**Problem:** No case gives a range where one commit is `-` and another `+`. No case reaches rule 4 (a commit reached by a landed commit). Since #1, rules 1-3 cover what rule 4 did, so a mutant of rule 4 would survive.

**Fix:** Deferred. Add the mixed-cherry case and its mutant. Then either give rule 4 a case, or remove it if it is redundant.

### 15
status: deferred
severity: P3
agent: adversarial-reviewer
category: Reliability
confidence: 45
action_class: judgment
file: plugins/cepa/scripts/orca-lane.sh
lines: create, resume
title: Resume can step on a create still in progress

**Problem:** A second create of the same lane, run while the first is between steps 3 and 4, resumes it. The first then reports failed for a lane that is fine. Resume also runs no `worktree ps` agent check. It does no data damage: the detach goes to the same commit, and `branch -D` only runs at ahead 0.

**Fix:** Deferred. Optionally add the `worktree ps` check before a resume. One coord@main per repo makes this race rare.

---

**Summary:** 15 findings (1 P1, 5 P2, 9 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
