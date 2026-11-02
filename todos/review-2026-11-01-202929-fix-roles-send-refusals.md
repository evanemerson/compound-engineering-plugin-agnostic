---
date: 2026-11-01T20:29:29
scope: pr:#122
branch: fix/roles/send-refusals
agents:
  - security-sentinel
  - adversarial-reviewer
  - previous-comments-reviewer
  - pr-test-analyzer
config: "no cepa.local.md — inferred roster for a bash + embedded-python plugin diff (head 1d67b82)"
learnings_research: "skipped — docs/solutions/ is absent in this worktree (docs/ is gitignored)"
agents_skipped:
  - agent: performance-oracle
    reason: "no query, ORM or frontend code"
  - agent: python-reviewer
    reason: "inline JSON readers only; none changed"
  - agent: data-integrity-guardian
    reason: "no migrations or data stores"
  - agent: schema-drift-detector
    reason: "no models or migrations"
  - agent: frontend-reviewer
    reason: "no templates, JS or CSS"
  - agent: deployment-verifier
    reason: "nothing deploys from this repo"
  - agent: architecture-reviewer
    reason: "no module boundary changed; rule 1 text read by previous-comments-reviewer"
  - agent: silent-failure-hunter
    reason: "inferred roster; adversarial-reviewer traced every exit path"
  - agent: comment-analyzer
    reason: "inferred roster"
  - agent: type-design-analyzer
    reason: "no types added"
  - agent: code-simplifier
    reason: "inferred roster"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "a guard on a mutating Orca call (send, nudge) changed"
  - agent: reliability-reviewer
    dispatched: false
    reason: "no queue, webhook or transaction code; the send's retry path is unchanged"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; the PR closes review-2026-10-31-233000 #10"
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
  total: 6
  p1: 0
  p2: 0
  p3: 6
  pending: 0
  ready: 0
  skipped: 1
  applied: 3
  deferred: 2
  completed: 0
---

# Review Findings — 2026-11-01 20:29 — PR #122 `send-refusals`

### 1
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: correctness
- confidence: 70
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: downgrade block after `Orca send stored`
- title: A downgraded send that Orca stored for another term_ handle said "not needed"

**Problem:**
The downgrade exit ran before the rerouted-recipient check. A `nudge` send to `dispatch:ctx_x` that Orca stored for a different `term_` handle printed `Orca nudge not needed … sent as no-nudge` and exited 0, though that mailbox gets no prompt and no nudge. Reproduced with a stub by the reviewer.

**Fix:**
Applied: when the downgraded send is stored for a `term_` handle other than the target, the script prints `Orca nudge skipped: Orca stored it for <h>, not the target` and the `tell <h>` ending, and exits 1. Pinned by `STORE downgraded send rerouted to a term_ handle` and the `nudge-downgrade-reroute-hidden` control.

### 2
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: correctness
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: message-file existence check
- title: A file in an unsearchable directory got the "removed once read" reason

**Problem:**
`[ -e ]` and `[ -L ]` are both false on EACCES, so a file in a mode-000 directory was refused as a file a run had removed. A first-run typo got the same unhedged reason.

**Fix:**
Applied: an unsearchable or absent directory is refused first with the existing `the message file's directory could not be resolved`, and the file is kept. The missing-file reason now ends `(or the path is wrong)`; `orca-health.sh` REASONS and §12b rule 1 match. Pinned by `FILE in an unsearchable directory` (+ keeps the file) and the `file-dir-unsearchable-unchecked` control.

### 3
- status: applied
- severity: P3
- agent: pr-test-analyzer
- category: test-coverage
- confidence: 75
- action_class: mechanical
- file: scripts/check-orca-nudge.sh
- lines: STORE downgrade cases
- title: Nothing pinned that the downgrade line follows a proven store

**Problem:**
A mutant that moved the downgrade echo above the store verification would survive: an unstored `nudge` to `run:` would print "not needed" and exit 0.

**Fix:**
Applied: `STORE downgraded send that stored nothing` and `STORE downgraded send missing from the inbox` assert exit 5 and no downgrade line.

### 4
- status: deferred
- severity: P3
- agent: previous-comments-reviewer
- category: maintainability
- confidence: 75
- action_class: judgment
- file: plugins/cepa/scripts/orca-health.sh
- lines: REASONS, pre-1.51.0 group
- title: A new "kept for one release" entry has no tracked removal

**Problem:**
`only a term_ handle is nudged` is kept for one release with no removal item: the same drift review-2026-10-31-233000 #10 reported.

**Fix:**
Deferred to `memory/tasks.d/2026-11-01-fix-roles-send-refusals.md`: drop the pre-1.51.0 group in the next minor after 1.51.0 (fits L53's orca-health batch).

### 5
- status: deferred
- severity: P3
- agent: previous-comments-reviewer
- category: maintainability
- confidence: 60
- action_class: judgment
- file: memory/tasks.d/2026-10-02-punch-list.md
- lines: L47
- title: L47 and two older shard lines still read open

**Problem:**
L47 reads `status: pending`. Two shard lines on the pre-1.43.0/1.44.0 groups stay unchecked: `memory/tasks.d/2026-10-31-fix-integrity-send-heredoc-delimiter.md` line 8 and `memory/tasks.d/2026-10-31-refactor-roles-send-block-stdin.md` line 15. Finding #10 is now marked applied in this PR.

**Fix:**
Deferred to coord@main, the punch list's only writer: close L47 and those two shard lines after the merge.

### 6
- status: skipped
- severity: P3
- agent: pr-test-analyzer
- category: test-coverage
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: downgrade
- title: The two halves of the downgrade are redundant

**Problem:**
`cepa_send_mode=no-nudge` and the downgrade block's exit each prevent a nudge alone, so removing one is an equivalent mutant.

**Fix:**
Skipped: defence in depth by design; the compound mutant is killed by `nudge-downgrade-silent`, as the reviewer noted.

---

**Summary:** 6 findings (0 P1, 0 P2, 6 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
