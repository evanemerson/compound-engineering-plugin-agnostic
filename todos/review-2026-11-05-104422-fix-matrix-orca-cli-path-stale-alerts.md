---
date: 2026-11-05T16:30:00
scope: pr:135
branch: fix/matrix/orca-cli-path-stale-alerts
agents:
  - adversarial-reviewer
  - security-sentinel
  - previous-comments-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
  - comment-analyzer
agents_skipped:
  - agent: python-reviewer
    reason: "no cepa.local.md roster; the diff's Python is inline in bash and read by the adversarial and silent-failure agents"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff of about 960 changed lines"
  - agent: reliability-reviewer
    dispatched: false
    reason: "no queue, webhook or transaction code; the git timeouts went to the adversarial reviewer"
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
learnings_research: "skipped — docs/solutions/ is absent in this checkout (docs/ is gitignored)"
summary:
  total: 14
  p1: 0
  p2: 5
  p3: 9
  pending: 0
  ready: 0
  skipped: 0
  applied: 9
  deferred: 5
  completed: 0
---

# Review Findings — PR #135

## Findings

### 1
status: applied
severity: P2
agent: adversarial-reviewer
category: Reliability
confidence: 95
action_class: judgment
file: plugins/cepa/scripts/orca-health.sh
title: A hung worker stayed hidden after long: was acked

**Problem:** An agent hung inside a turn keeps its timer redrawing, so terminal output read as life and stale: never fired. long: has a key with no time, so its ack ended the last alert. The script on main still alerted on the same input.

**Fix:** Terminal output no longer counts once the dispatch reaches the long: bound, so stale: returns. The header limits say so. Cases and two mutants pin the boundary.

### 2
status: applied
severity: P2
agent: silent-failure-hunter, adversarial-reviewer, previous-comments-reviewer
category: Silent failure
confidence: 90
action_class: corroborated
file: plugins/cepa/scripts/orca-health.sh
title: The stale alert claimed reads that did not happen

**Problem:** The text named the commit as checked when the git read failed or was skipped, and could print a life age as the heartbeat age.

**Fix:** The alert prints each signal's own state: heartbeat, terminal output and commit, each with its age, `unread`, or why it was not counted.

### 3
status: applied
severity: P2
agent: pr-test-analyzer
category: Tests
confidence: 75
action_class: mechanical
file: scripts/check-orca-cli-path-controls.sh
title: check-off-linux pinned only red, and nothing isolated the OS guard

**Problem:** A site that crashed would pass the control, and the off-Linux half had no kill of its own.

**Fix:** check-inverted pins the exact set, and check-on-every-os kills only the off-Linux cases.

### 4
status: applied
severity: P2
agent: pr-test-analyzer
category: Tests
confidence: 60
action_class: mechanical
file: scripts/check-orca-cli-path.sh
title: The SITES probe matched one spelling only

**Problem:** A new script writing `orca-dev | orca-ide)` was invisible, the shape this repo's absence-claim rule warns about.

**Fix:** The probe is a regex over both orders and spaces, and its control plants the reordered spelling.

### 5
status: applied
severity: P2
agent: pr-test-analyzer
category: Tests
confidence: 65
action_class: mechanical
file: scripts/check-orca-nudge.sh
title: The wsl$ path form had no case

**Problem:** A mutant dropping the `$` form from WSL_PATH would survive.

**Fix:** A case and health-life-no-wsl-dollar cover it.

### 6
status: applied
severity: P3
agent: adversarial-reviewer
category: Correctness
confidence: 90
action_class: mechanical
file: plugins/cepa/scripts/orca-health.sh
title: An unknown handle matched a missing handle

**Problem:** None equalled None, so a terminal with no handle cleared the alert for a worker with no handle.

**Fix:** life() requires a string handle. Case and mutant added.

### 7
status: applied
severity: P3
agent: adversarial-reviewer
category: Security
confidence: 95
action_class: mechanical
file: plugins/cepa/scripts/orca-health.sh
title: The Linux guard failed open when uname failed

**Problem:** This predates the PR. An empty uname made bare orca pass, and §12a's unknown picked `orca` too, which breaks the rule that the screen reader never runs. Same line at all nine sites.

**Fix:** A failed uname reads as Linux at every site. Cases and a mutant per site added.

### 8
status: applied
severity: P3
agent: pr-test-analyzer
category: Tests
confidence: 60
action_class: mechanical
file: scripts/check-orca-nudge.sh
title: Output and a commit together, and bare orca off Linux, had no case

**Problem:** A mutant keeping only the commit time would survive, and the off-Linux bare case was unpinned.

**Fix:** Cases added, with health-life-commit-wins.

### 9
status: applied
severity: P3
agent: comment-analyzer, adversarial-reviewer, security-sentinel
category: Docs
confidence: 55
action_class: corroborated
file: plugins/cepa/scripts/orca-health.sh
title: Wording of the LIFE text and its limits

**Problem:** The text said the reads run only for a worker that would alert, implied check --wait prints nothing, and left out forged commit dates. orca-nudge.sh's header and check-orca-nudge.sh's leg list lagged.

**Fix:** All reworded; the workflow got its blank line.

### 10
status: deferred
severity: P3
agent: adversarial-reviewer
category: Reliability
confidence: 90
action_class: judgment
file: plugins/cepa/scripts/orca-health.sh
title: A failed read after an ack can move the stale key back

**Problem:** The key follows the newest life read, so one silence can cost an extra question. No alert is lost.

**Fix:** Stated as a limit in the header. A fix needs a per-dispatch ack rule: operator's call if it shows up.

### 11
status: deferred
severity: P3
agent: silent-failure-hunter
category: Reliability
confidence: 60
action_class: judgment
file: plugins/cepa/scripts/orca-health.sh
title: worktree_refs caches a failed read for the run, and a failed git read leaves no note

**Problem:** One failed `git worktree list` skips commit reads for that run. The alert stays and now prints `commit unread`.

**Fix:** Left as is: the state is visible in the alert.

### 12
status: deferred
severity: P3
agent: pr-test-analyzer
category: Tests
confidence: 55
action_class: judgment
file: scripts/check-orca-cli-path.sh
title: Skill extraction raises a traceback, not a MISS

**Problem:** If the skill text changes shape the gate fails with a traceback. It is red, never a silent pass.

**Fix:** Left as is.

### 13
status: deferred
severity: P3
agent: security-sentinel, silent-failure-hunter
category: Security
confidence: 60
action_class: judgment
file: plugins/cepa/scripts/orca-health.sh
title: The path test allows .. segments, reads then runs, and one refusal covers an unreadable file

**Problem:** All are inside §12a's stated same-user limit: setting ORCA_CLI_COMMAND already runs code as this user.

**Fix:** Left as is.

### 14
status: deferred
severity: P3
agent: adversarial-reviewer
category: Reliability
confidence: 70
action_class: judgment
file: plugins/cepa/scripts/orca-health.sh
title: ack is refused when the launcher file is gone

**Problem:** The cli check runs before ack, which never runs the cli. The same stale value also refuses the full health run, so the operator sees the refusal.

**Fix:** Left as is.

---

**Summary:** 14 findings (0 P1, 5 P2, 9 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
