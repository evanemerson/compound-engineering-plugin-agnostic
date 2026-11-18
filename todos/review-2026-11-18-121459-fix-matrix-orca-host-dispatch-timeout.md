---
date: 2026-11-18T12:14:59
scope: fix/matrix/orca-host-dispatch-timeout
branch: fix/matrix/orca-host-dispatch-timeout
pr: 144
agents:
  - security-sentinel
  - adversarial-reviewer
  - reliability-reviewer
  - previous-comments-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
  - comment-analyzer
summary:
  total: 12
  p1: 1
  p2: 1
  p3: 10
  pending: 0
  ready: 0
  skipped: 3
  applied: 7
  deferred: 2
  completed: 0
agents_skipped:
  - agent: performance-oracle
    rule: "no ORM, queries or hot loops in diff (bash scripts and docs)"
  - agent: python-reviewer
    rule: "only short embedded python readers; covered by security, adversarial and silent-failure agents"
  - agent: data-integrity-guardian
    rule: "no migrations or data writes in diff"
  - agent: schema-drift-detector
    rule: "no models, migrations, serializers, forms or admin in diff"
  - agent: frontend-reviewer
    rule: "no templates/JS/CSS in diff"
  - agent: deployment-verifier
    rule: "no config, dependencies, Docker, env or migration files; manifests carry a version bump only"
  - agent: architecture-reviewer
    rule: "no new module boundaries; changes sit inside existing scripts"
  - agent: type-design-analyzer
    rule: "no new types or models"
  - agent: code-simplifier
    rule: "skipped for cost in a worker run"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff is about 800 lines and changes the send-or-not decision"
  - agent: reliability-reviewer
    dispatched: true
    signal: "diff changes external CLI calls (orca-ide reads, timeouts, retries)"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; shard memory/tasks.d/2026-11-17-fix-matrix-orca-wsl-host-and-retired-run.md touches the diff"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped: no deploy surface in diff (plugin scripts and docs)"
  conditions: []
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
  corpus: "consulted — no docs/solutions/ in this checkout (docs/ is gitignored)"
---

# Review Findings — 2026-11-18 12:14 (PR #144)

No cepa.local.md in this repo: headless mode inferred the stack (bash with
embedded python, docs). Reviewed head 44ce862. Fixes below are on the next
commit.

## Findings

### 1
- status: applied
- severity: P1
- agent: adversarial-reviewer
- category: Correctness
- confidence: 80
- action_class: corroborated
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1226-1305
- title: the re-read took an earlier send's follow-up as this send's, so a lost message exited 0

**Problem:**
The first cut proved a follow-up by a 120 s `createdAt` window. Send A to
`dispatch:T` starts F1; within 120 s send B to `dispatch:T` times out and
starts nothing; the re-read finds F1 (owns the terminal, in the window,
follows T) and exits 0. B is lost while the sender is told it was stored.
Security-sentinel, silent-failure-hunter and reliability-reviewer reported the
same.

**Fix:**
Applied: the script reads the owner of the target's terminal BEFORE a plain
`dispatch:` send, and after a failed call counts the send only when the owner
changed, the new owner's `followUpOf` is the old owner, and the old owner is
the target or chains back to it. No clock is used. Cases: FRESH earlier
follow-up that still owns the terminal fails, FRESH owner that did not change
fails; mutant send-fresh-same-owner-ok.

### 2
- status: deferred
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 55
- action_class: judgment
- file: scripts/check-orca-nudge.sh
- lines: FRESH leg
- title: the 60 s bound is checked only against a term_ send

**Problem:**
Nothing checks that `run:`, `coord:` and `worker_done`-to-dispatch sends stay
at 15 s; a mutant widening the guard would survive.

**Fix:**
Deferred: add timeout-log cases for a `coord:` send and a `worker_done` send.
Residual in the branch shard.

### 3
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Error handling
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1355-1356
- title: the exit 5 reason hid which re-read step failed

**Problem:**
Every re-read failure printed one generic reason. Previous-comments-reviewer
tied this to PR #143 finding 11.

**Fix:**
Applied: the re-read prints `FAIL <reason>` per step, and the exit 5 line
carries it: `a re-read proved no follow-up (<reason>), but one may exist, so
do not resend`.

### 4
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Error handling
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/scripts/orca-lane.sh
- lines: cepa_ln_hostrepo
- title: two WSL hosts were reported as a failed repo-list read

**Problem:**
`wslenvs` exit 3 (two WSL hosts) folded into "could not be read".
Comment-analyzer reported the same against the header.

**Fix:**
Applied: `cepa_ln_hostrepo` returns 3, and the message says more than one Orca
WSL host is added. Case: HOSTREPO two WSL hosts are not ruled out; mutants
hostrepo-two-hosts-as-fail, hostrepo-two-hosts-msg-off.

### 5
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Error handling
- confidence: 40
- action_class: mechanical
- file: plugins/cepa/scripts/orca-lane.sh
- lines: hostrepo mode
- title: a host repo row of an unknown shape could lead to the repo add advice

**Problem:**
A non-object row was skipped, so a bad read could print "add this repo to
Orca", the double registration the change exists to prevent.

**Fix:**
Applied: a non-object row exits 1 ("not ruled out"). Case: HOSTREPO host repo
row of an unknown shape; mutant hostrepo-row-shape. Also added: HOSTREPO
failed environment list.

### 6
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Documentation
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1147-1152
- title: the chain comment sat above cepa_send_where

**Problem:**
Extracting `cepa_send_where` left THE FOLLOW-UP CHAIN comment orphaned.

**Fix:**
Applied: `cepa_send_where` moved before the send (the owner read needs it);
the chain comment sits above `cepa_send_chain` again.

### 7
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Documentation
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: rule 1, dispatch bullet
- title: §12b restated the 60 s bound the header owns

**Problem:**
The number was copied without the header's "chosen margin" caveat.

**Fix:**
Applied: "has a longer time bound (its header, THE FOLLOW-UP RE-READ and TIME
BUDGET)".

### 8
- status: skipped
- severity: P3
- agent: comment-analyzer
- category: Documentation
- confidence: 50
- action_class: judgment
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: rule 1, `on:` bullet
- title: the host-to-Windows sentence cites no script header

**Problem:**
The measurement lives only in §12b.

**Fix:**
Skipped: no script implements it (L93 2 is documented only), so §12b is its
one owner; the shard (item 5) says so.

### 9
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 80
- action_class: mechanical
- file: memory/tasks.d/2026-11-18-fix-matrix-orca-host-dispatch-timeout.md
- lines: new section
- title: the shard did not say which 2026-11-17 items this branch touches

**Problem:**
PR #143 items 3/5 (hop cap), 7 (new dispatch read), 8, 9, 10 and shard items
5, 6 were touched or left open without a note.

**Fix:**
Applied: section "Open items of the 2026-11-17 shard this branch touches".

### 10
- status: skipped
- severity: P3
- agent: reliability-reviewer
- category: Efficiency
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: cepa_send_owner
- title: the target's record is read twice for a host dispatch

**Problem:**
The home record and the host record of the target are both read.

**Fix:**
Skipped: they are different records. The home record of a host dispatch was
measured with `followUpOf: null` and a `server` key (PR #143); its
`assigneeHandle` is not measured, so the host record is the one that names
the terminal.

### 11
- status: skipped
- severity: P3
- agent: reliability-reviewer
- category: Error handling
- confidence: 40
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1355-1356
- title: "do not resend" also follows a local CLI failure that sent nothing

**Problem:**
A usage error also prints "one may exist, so do not resend".

**Fix:**
Skipped: an unchanged owner after a failed call may be a late take-over (shard
item 2), so the safe wording stays until orca-lab measures the take-over.

### 12
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 45
- action_class: judgment
- file: scripts/check-orca-lane.sh
- lines: HOSTREPO leg
- title: the host repo reads' 5 s bound and no-retry are not asserted

**Problem:**
Changing `0 5` to `1 15` in `cepa_ln_hostrepo` survives.

**Fix:**
Deferred: log the timeout and retry values in the lane stub. Residual in the
branch shard.

---

**Summary:** 12 findings (1 P1, 1 P2, 10 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
