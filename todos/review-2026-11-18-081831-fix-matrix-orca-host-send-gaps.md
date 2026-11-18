---
date: 2026-11-18T08:18:31
scope: fix/matrix/orca-host-send-gaps
branch: fix/matrix/orca-host-send-gaps
pr: 143
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
  p1: 0
  p2: 4
  p3: 8
  pending: 0
  ready: 0
  skipped: 0
  applied: 6
  deferred: 6
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
    signal: "diff is about 790 lines"
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
  corpus: not-consulted
learnings_research: "skipped — not dispatched in this worker run (no cepa.local.md; headless, stack inferred)"
---

# Review Findings — 2026-11-18 08:18 (PR #143)

No cepa.local.md in this repo: headless mode inferred the stack (bash with
embedded python, docs). No P1 from any agent.

## Findings

### 1
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Error handling
- confidence: 80
- action_class: corroborated
- file: plugins/cepa/scripts/orca-lane.sh
- lines: 1195-1235
- title: rm says "no lane has that name" when the WSL host read failed

**Problem:**
`cepa_ln_hostlane` folded every host read failure (timeout, unknown shape,
two WSL hosts) into the plain "no lane of this repo has that name" refusal,
which is false when a lane exists on the host. Reliability-reviewer reported
the same (P3).

**Fix:**
Applied: the function returns 0 with no output for "no host or no lane", and 1
for a failed, partial or unknown read; the refusal then says the host lane is
not ruled out. Cases: HOSTLANE failed / partial / two hosts; mutants
hostlane-fail-says-none, hostlane-partial-ok.

### 2
- status: applied
- severity: P3
- agent: reliability-reviewer
- category: Idempotency
- confidence: 80
- action_class: corroborated
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1185-1192
- title: chain failure text does not warn that a follow-up may already exist

**Problem:**
An exit 5 from the chain walk may follow a follow-up Orca did start; the
printed reason did not say so, and a resend starts another follow-up.
Adversarial-reviewer reported the same risk.

**Fix:**
Applied: every chain failure appends "a follow-up dispatch may already exist,
so do not resend"; §12b rule 1 says to send the next message to the printed
`dispatch:<new>`. Mutant send-chain-do-not-resend.

### 3
- status: deferred
- severity: P2
- agent: adversarial-reviewer
- category: Reliability
- confidence: 85
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1140-1170
- title: the 8-hop cap makes the 10th send to a first dispatch a false exit 5

**Problem:**
`followUpOf` names the newest dispatch, so a sender that keeps addressing the
first dispatch needs one more hop per send; the 10th send exceeds the cap and
exits 5 for a stored follow-up. Reliability-reviewer reported the same (P2).

**Fix:**
Deferred (design choice). Partly mitigated by finding 2. Options: raise the
cap within the time budget, or find an Orca read that names a terminal's
newest dispatch in one call. Residual: shard item 5 (PR #143 section).

### 4
- status: deferred
- severity: P2
- agent: adversarial-reviewer
- category: Reliability
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1292-1300
- title: stored on: send exits 0 on one sender report, with no delivery check

**Problem:**
The host prompt was observed once, on an idle worker (msg_6a0b36ef91b6). A
busy or asking host worker may not read the message, and the sender gets no
ending line or alert. Raised by security, reliability, silent-failure and
adversarial agents.

**Fix:**
Deferred: the coordinator's brief asks for exit 0 with no operator ask. A
measurement of a busy host worker, or a host state read before `not
needed`, would close it. Residual: shard item 6.

### 5
- status: deferred
- severity: P3
- agent: security-sentinel
- category: Verification
- confidence: 55
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: 975-995
- title: FOLLOWUP and CHAIN never read back the new dispatch

**Problem:**
The success line names `dispatchId` from the reply alone; no read confirms it
exists or follows `followUpOf`. Raised by security, previous-comments,
silent-failure and adversarial agents; the PR #142 review's #13.

**Fix:**
Deferred: the new dispatch's record shape on the host right after the send is
not measured, and the read adds one call to the budget. Residual: shard
item 7 (updated) and item 7 of the PR #143 section.

### 6
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Completeness
- confidence: 65
- action_class: corroborated
- file: plugins/cepa/scripts/orca-lane.sh
- lines: 836-862
- title: host lane reader ignores truncated and totalCount

**Problem:**
The `hostlane` reader did not apply the completeness rule every other read
in the script applies. pr-test-analyzer reported the same gap.

**Fix:**
Applied: truncated, totalCount and the 500 limit make the read a failure,
which now says the host lane is not ruled out (finding 1).

### 7
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 85
- action_class: mechanical
- file: scripts/check-orca-nudge.sh
- lines: 1150-1200
- title: no case pins the ctx_ shape of followUpOf and of each hop

**Problem:**
Removing either regex left every case green: a flag-shaped id would reach
`worker-show` argv.

**Fix:**
Applied: cases for a flag-shaped and a null followUpOf, and a flag-shaped hop
with a readable record, each asserting no worker-show call carries the value;
mutants send-followup-fu-shape and send-chain-hop-shape.

### 8
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 70
- action_class: judgment
- file: scripts/check-orca-nudge.sh
- lines: 1119-1200
- title: remaining chain and host-lane test gaps

**Problem:**
Unpinned: a flag-shaped or over-long `server.environmentId`, a timed-out hop
read, UNC host paths, failed `environment list` or `repo list` on the
host-lane path, the local home read's argv.

**Fix:**
Deferred to a test-only follow-up. Residual: shard item 8 (PR #143 section).

### 9
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Residual integrity
- confidence: 80
- action_class: corroborated
- file: memory/tasks.d/2026-11-17-fix-matrix-orca-wsl-host-and-retired-run.md
- lines: 8-70
- title: shard marks items closed that its own new items keep open

**Problem:**
Item 1 read CLOSED while a live re-run stayed owed; item 4 (create/name) was
untouched while the new section said L89 e closed; item 7 still waited on a
shape now measured.

**Fix:**
Applied: item 1 says fixed on report with a live re-run owed; item 4 says
partly addressed (rm only); item 7 says what remains; the new section says
L89 e for rm only.

### 10
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Documentation
- confidence: 75
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: 40-160
- title: header and doc wording fixes

**Problem:**
The exit-0 list omitted the host `not needed` reason; "This run" and "here"
had no referent; the chain counts had no probe; the stranger claim read as
measured; "1.60.0 re-measure" mixed cepa and Orca versions; the lane header
named two host reads, not three, and left them out of the budget note; the
HOSTON leg header omitted "stored for the target".

**Fix:**
Applied in orca-send.sh, orca-lane.sh, SKILL.md and check-orca-nudge.sh.

### 11
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Debuggability
- confidence: 50
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1100-1170
- title: chain failure reasons do not name the hop or the cause

**Problem:**
All read and shape failures print "could not be read" with no hop number or
dispatch id. Every such path still exits 5.

**Fix:**
Deferred: set the reason per failure point. Residual: shard item 9.

### 12
- status: deferred
- severity: P3
- agent: adversarial-reviewer
- category: Reliability
- confidence: 40
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1100-1125
- title: a host-created follow-up's home record is not measured

**Problem:**
A sender that targets `dispatch:<new>` (as §12b now advises) starts the walk
from a host-created dispatch; whether this machine has a record of it with
`server.environmentId` is not measured. A missing record exits 5 falsely
(safe direction).

**Fix:**
Deferred: measure on a live host follow-up, or retry the home read with the
one WSL host's `--environment`. Residual: shard item 10.

---

**Summary:** 12 findings (0 P1, 4 P2, 8 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
