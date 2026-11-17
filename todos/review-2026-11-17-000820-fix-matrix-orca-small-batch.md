---
date: 2026-11-17T00:08:20
scope: pr:139
branch: fix/matrix/orca-small-batch
agents:
  - security-sentinel
  - reliability-reviewer
  - architecture-reviewer
  - previous-comments-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
agents_skipped:
  - agent: python-reviewer
    reason: "no cepa.local.md roster; the diff's Python is inline test harness code, read by pr-test-analyzer"
  - agent: performance-oracle
    reason: "no cepa.local.md roster; shell scripts and docs only, no query or hot path"
  - agent: data-integrity-guardian
    reason: "no models, migrations or transactions in the diff"
  - agent: schema-drift-detector
    reason: "no models, migrations, serializers, forms or admin in the diff"
  - agent: frontend-reviewer
    reason: "no templates, JS/CSS or frontend components in the diff"
  - agent: deployment-verifier
    reason: "no config, dependency, Docker, env or migration files; nothing deploys from this repo"
  - agent: comment-analyzer
    reason: "header-comment accuracy was in the architecture-reviewer brief"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: false
    reason: "about 170 changed lines of code, no payments, auth, PHI or migration paths; the path-join and relay surfaces went to security-sentinel"
  - agent: reliability-reviewer
    dispatched: true
    signal: "alert writes and nudge failure paths after an external Orca call"
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
  skipped: 1
  applied: 13
  deferred: 0
  completed: 0
---

# Review Findings — PR #139

## Findings

### 1
status: applied
severity: P2
agent: reliability-reviewer, silent-failure-hunter
category: Reliability
confidence: 75
action_class: corroborated
file: plugins/cepa/scripts/orca-send.sh
lines: 1160-1172
title: L65 alerted on only four exact nudge reasons

**Problem:** The `case` listed four Orca-call literals. A nudge that skipped on unreadable Orca output (`an Orca call did not return "ok": true`, not JSON, unexpected shape), a missing tool, or a failed clock or sleep left a stored but unread message with no alert.

**Fix:** The `case` now stays silent only for a skip on the target's own row (`the target is …`, no agent row, two rows, state unknown) and alerts on every other `Orca nudge skipped:` or `Orca nudge failed:` line. orca-health.sh REASONS gained every such reason. New gate case `HEALTH every nudge_skipped reason is shown` reads orca-nudge.sh's literals; mutants alert-nudge-target-row-alerts, alert-nudge-failed-silent.

### 2
status: applied
severity: P2
agent: reliability-reviewer, silent-failure-hunter
category: Reliability
confidence: 70
action_class: corroborated
file: plugins/cepa/scripts/orca-send.sh
lines: 1137-1195
title: A missing, dead or silent orca-nudge.sh wrote no alert

**Problem:** The wrapper's own paths (`orca-nudge.sh not found`, `would not start`, `exited N and printed nothing`) exit 1 with the ending line only. If the session drops that line, nothing records the unread message.

**Fix:** Each path writes a `nudge_skipped` alert with its fixed reason, listed in REASONS. Cases `NUDGEFILE … writes an alert` (three); mutants nudgefile-missing-silent, nudgefile-nostart-silent, nudgefile-empty-silent, health-nudgefile-reasons-gone.

### 3
status: applied
severity: P2
agent: pr-test-analyzer
category: Test coverage
confidence: 80
action_class: mechanical
file: scripts/check-orca-nudge.sh
lines: 1546-1552
title: The send-not-ok nudge path had no send-side case

**Problem:** `terminal send did not return "ok": true` was checked only by a hand-built HEALTH alert file; dropping it from orca-send.sh left every check green.

**Fix:** Added `ALERT nudge lost to a send that is not ok writes one file` and `… an Orca reply that is not ok …`; the alert-not-on-nudge-loss mutant now expects both.

### 4
status: applied
severity: P2
agent: pr-test-analyzer
category: Test coverage
confidence: 70
action_class: mechanical
file: scripts/check-orca-outbox.sh
lines: 384-415
title: L87's path guards were unpinned

**Problem:** No case planted `repo=..`/`worktree=..`, so a mutant dropping the `.`/`..` exclusion survived.

**Fix:** The PRUNE case plants a file with `..` headers and a marker where `acked/..` would lead, and asserts it still alerts. Mutant prune-ack-dotdot.

### 5
status: applied
severity: P2
agent: architecture-reviewer
category: Documentation
confidence: 75
action_class: mechanical
file: plugins/cepa/skills/autonomy/SKILL.md
lines: 2049-2050
title: The L80 control was restated in two skills instead of cited

**Problem:** Rule 2 and lane-stack item 5 both spelled out the Orca control path; H1 in orca-lane.sh owns it. A renamed control would leave two stale copies.

**Fix:** Both skills now cite H1 ("the Orca control that block names"). The runtime messages keep the text inline.

### 6
status: applied
severity: P3
agent: reliability-reviewer, silent-failure-hunter
category: Reliability
confidence: 80
action_class: corroborated
file: plugins/cepa/scripts/orca-send.sh
lines: 512-530
title: An ack of the newest outbox file did not cover older files

**Problem:** orca-health.sh keys the count alert by its newest file, so one ack covers every older file in it. The prune matched only the exact name, so the older files still alerted twice.

**Fix:** `cepa_send_obox_acked` accepts any marker `outbox:<sub>:<m>` with `m` sorting at or after the file's name. Mutant prune-ack-exact-only.

### 7
status: applied
severity: P3
agent: pr-test-analyzer
category: Test coverage
confidence: 65
action_class: mechanical
file: scripts/check-orca-outbox.sh
lines: 384-415
title: A marker under a worktree the file does not name was never planted

**Problem:** A mutant globbing `acked/*/` survived.

**Fix:** The case plants a marker under `acked/stranger/` and asserts that file still alerts. Mutant prune-ack-any-worktree; prune-ack-any-sub now mutates the glob and the strip together.

### 8
status: applied
severity: P3
agent: pr-test-analyzer
category: Test coverage
confidence: 60
action_class: mechanical
file: scripts/check-orca-nudge.sh
lines: 1552
title: No case for a busy target writing no alert

**Problem:** Only a `waiting` row was tested.

**Fix:** Added `ALERT busy target skip writes none` (a `working` row to the 120-second bound).

### 9
status: applied
severity: P3
agent: architecture-reviewer
category: Documentation
confidence: 60
action_class: mechanical
file: plugins/cepa/scripts/orca-lane.sh
lines: 932, 1011, 1208
title: The control path was worded differently at the unknown-shape sites

**Problem:** Three advisory lines said "this repo's hooks" or omitted "Advanced".

**Fix:** All say "Settings > Repositories > this repo > Worktree Hooks > Advanced".

### 10
status: applied
severity: P3
agent: pr-test-analyzer
category: Test coverage
confidence: 75
action_class: mechanical
file: scripts/check-orca-lane.sh
lines: 1140
title: The L80 refusal text was unpinned

**Problem:** The h4 case checked only "in Orca, open Settings".

**Fix:** It now also requires the Command source text; mutant shadow-fix-unnamed. The L83 wording stays unpinned: it is operator prose with a cited owner.

### 11
status: applied
severity: P3
agent: architecture-reviewer
category: Documentation
confidence: 40
action_class: mechanical
file: plugins/cepa/scripts/orca-health.sh
lines: 674
title: The nudge_skipped text said "skipped" for send failures

**Problem:** Cosmetic: a failed `terminal send` is not a skip.

**Fix:** The text is now "was stored, but not nudged".

### 12
status: applied
severity: P3
agent: silent-failure-hunter
category: Error handling
confidence: 60
action_class: mechanical
file: plugins/cepa/scripts/orca-send.sh
lines: 538-545
title: A prune alert that was not recorded lost its reason

**Problem:** `cepa_send_alert_for` tested only the "recorded" prefix, so the session saw a generic line.

**Fix:** It prints the writer's own `Orca alert not recorded: …` line before returning 1. The second half (an `rm` that fails after the alert) is accepted: that file alerts again next run, which is visible, not silent.

### 13
status: applied
severity: P3
agent: reliability-reviewer
category: Reliability
confidence: 60
action_class: mechanical
file: plugins/cepa/scripts/orca-send.sh
lines: 512-518
title: A main-checkout ack also silences a lane's prune alert

**Problem:** The prune checks acked/<repo=> as well as acked/<worktree=>.

**Fix:** Kept by design (the main coordinator saw the same message) and stated in the helper's comment.

### 14
status: skipped
severity: P3
agent: reliability-reviewer
category: Reliability
confidence: 50
action_class: judgment
file: plugins/cepa/scripts/orca-nudge.sh
lines: 150
title: The vsock send-retry guard re-reads stale state

**Problem:** Claimed that `cepa_nudge_read` only re-parses the old ps.json.

**Fix:** Skipped: the claim is wrong. `cepa_nudge_read` re-runs `worktree ps --agent-wait` through `cepa_nudge_orca` before it parses. Not in this diff either.

---

**Summary:** 14 findings (0 P1, 5 P2, 9 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
