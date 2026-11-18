---
date: 2026-11-17T21:36:59
scope: PR #142
branch: fix/matrix/orca-wsl-host-and-retired-run
agents:
  - adversarial-reviewer
  - previous-comments-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
  - comment-analyzer
summary:
  total: 19
  p1: 0
  p2: 9
  p3: 10
  pending: 0
  ready: 0
  skipped: 1
  applied: 12
  deferred: 6
  completed: 0
agents_skipped:
  - agent: security-sentinel
    rule: "no cepa.local.md (headless: roster inferred); no auth/PHI/payment paths in the diff"
  - agent: performance-oracle
    rule: "no cepa.local.md (headless: roster inferred); no query or hot-path code"
  - agent: python-reviewer
    rule: "no cepa.local.md (headless: roster inferred); Python is inline readers in bash, covered by adversarial and silent-failure passes"
  - agent: data-integrity-guardian
    rule: "no migrations or data writes"
  - agent: architecture-reviewer
    rule: "no cepa.local.md (headless: roster inferred); no module boundary change"
  - agent: schema-drift-detector
    rule: "no models, migrations, serializers, forms or admin"
  - agent: frontend-reviewer
    rule: "no templates/JS/CSS in diff"
  - agent: deployment-verifier
    rule: "no config, dependency, Docker, env or migration files"
  - agent: type-design-analyzer
    rule: "no new types"
  - agent: code-simplifier
    rule: "skipped for cost in a worker run"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff over 300 changed lines (1380-line diff)"
  - agent: reliability-reviewer
    dispatched: false
    reason: "no queue/webhook/transaction code; external CLI-call failure paths covered by adversarial and silent-failure-hunter"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; memory/tasks.d shards touch the diff's files"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped: no config, dependency, Docker, env or migration files; plugin ships on merge plus the two-hop refresh"
  conditions: []
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
  corpus: not-consulted
learnings_research: "skipped — headless worker run; learnings-researcher not dispatched (cost)"
---

# Review Findings — 2026-11-17 21:36

No `cepa.local.md` in this repo: the roster was inferred (headless rule).

## Findings

### 1
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: Safety guard
- confidence: 80
- action_class: mechanical
- file: plugins/cepa/scripts/orca-rebind.sh
- lines: 335-345
- title: Retired check before the ownership ask ignored run-current, so a typo'd run: id said "create a new Run"

**Problem:**
With `run:` naming a gone Run while run-current reports another live Run, the new pre-ask `run-show` exited 2 "retired" instead of the ask that names both ids.

**Fix:**
The pre-ask retired read runs only when run-current reports no Run. Case "REBIND gone named Run while run-current reports another asks"; mutant `rebind-retired-pre-ask-any-cur`.

### 2
- status: applied
- severity: P2
- agent: adversarial-reviewer, silent-failure-hunter
- category: Send accounting
- confidence: 75
- action_class: corroborated
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1072-1100
- title: A failed dispatch: send that started a follow-up was reported "no message stored"

**Problem:**
A follow-up dispatch leaves no inbox row, so a timeout or non-zero exit after it was created read as "no message stored", inviting a rerun that starts a second follow-up.

**Fix:**
A plain `dispatch:` send that is not read back now exits 5 as `not proven stored` (worker_done unchanged). FOLLOWUP and READBACK cases updated; mutants `send-dispatch-unproven-off`, `send-dispatch-unproven-wdone`.

### 3
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Time budget
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/scripts/orca-lane.sh
- lines: 1248-1262
- title: rm worst case (599 s plus local git work) could pass the 10-minute tool timeout

**Problem:**
The two WSL host reads at 10 s + 2 s kill pushed the bounded sum to 599 s before local git work.

**Fix:**
Both host reads bounded at 5 s; header worst case 589 s.

### 4
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Fail closed
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- lines: 415-422
- title: Host-row skip would accept a server object naming local

**Problem:**
A future Orca that adds `server: {environmentId: "local"}` to every row would silence health.

**Fix:**
`environmentId != "local"` added. Case "HEALTH local server row with no projection is unreadable"; mutant `health-host-row-local`.

### 5
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- lines: 415-422
- title: No case pinned that a server row with a projection is still read

**Problem:**
Dropping `projection is None` survived every case.

**Fix:**
Case "HEALTH server row with a projection is still read"; mutant `health-host-row-projection-unchecked`.

### 6
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: 943-952
- title: No case pinned that a worker_done is never a follow-up

**Problem:**
Dropping `typ not in ("reply", "worker_done")` survived every case.

**Fix:**
Case "FOLLOWUP shape on a worker_done is not a follow-up"; mutant `send-followup-any-type`.

### 7
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 65
- action_class: mechanical
- file: plugins/cepa/scripts/orca-lane.sh
- lines: 552-565
- title: all() over omitted hosts was unpinned (any() survived)

**Problem:**
No case had a cleared WSL host beside a second omitted host.

**Fix:**
Stub mode `psomit2`; case "WSLHOST omitted WSL host beside another omitted host keeps the lane"; mutant `wsl-cleared-all-to-any`.

### 8
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/scripts/orca-rebind.sh
- lines: 64
- title: Header said the Ending line comes on exit 1 or 3; retired (exit 2) prints one too

**Problem:**
Stale exit list.

**Fix:**
"on exit 1, 2 or 3".

### 9
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 75
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: 114-125
- title: Follow-up exit-0 entry left out the no-message and type conditions and the ctx_ pattern

**Problem:**
The header listed fewer conditions than the code checks.

**Fix:**
Header lists them all, and the new unproven rule.

### 10
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/scripts/orca-rebind.sh
- lines: 68-72
- title: Retired-read placement read as contradictory

**Problem:**
"at step 3, and before step 2's ownership ask".

**Fix:**
"in step 3, and in step 2's ask branch when run-current reports no Run".

### 11
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 55
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- lines: 410
- title: Garbled code comment ("This machine Orca")

**Problem:**
An apostrophe had been dropped to fit the single-quoted python.

**Fix:**
"The local Orca projects nothing for it".

### 12
- status: applied
- severity: P2
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/orca-lane.sh
- lines: 364-370
- title: hostread note overstated what the path match proves (relaxes #138's strict rm)

**Problem:**
The note said "no agent in this lane's directory"; the read proves only that no host worktree row at the lane's path has an agent.

**Fix:**
Note and header reworded to what is proven, with the reasoning (the host Orca starts agents only in worktrees it registered, which list by path; a shell that only cd's in is the same stated limit as a plain local terminal). Kept the relaxation: it is the measured path match the operator's "Keep strict" allows. orca-lab re-measure listed as a residual.

### 13
- status: deferred
- severity: P2
- agent: silent-failure-hunter, adversarial-reviewer
- category: Send accounting
- confidence: 55
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1093-1100
- title: FOLLOWUP success path counts on the reply alone, with no re-read

**Problem:**
Every other stored send is re-read; the follow-up has no msg_ id, and a `worker-show` of a host follow-up dispatch is not measured.

**Fix:**
Once orca-lab measures `worker-show --dispatch <new>` for a host follow-up, read it before exit 0. Residual shard item 1.

### 14
- status: deferred
- severity: P2
- agent: silent-failure-hunter
- category: Fail closed
- confidence: 40
- action_class: judgment
- file: plugins/cepa/scripts/orca-rebind.sh
- lines: 336-345
- title: run_not_found is read on this machine's Orca only

**Problem:**
A Run held on a WSL host's own Orca would read as retired here.

**Fix:**
Not applied: a coordinator's Run lives in the Orca it was created on, and this script runs there. Revisit if a coordinator runs on a host.

### 15
- status: deferred
- severity: P2
- agent: silent-failure-hunter
- category: Observability
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/orca-health.sh
- lines: 415-422
- title: Skipped host dispatches raise nothing, not even a note

**Problem:**
With stablyai/orca#43869 open, no rule 8 alert covers a failed or hung host worker.

**Fix:**
A note or alert keyed on the row's `workerState`/`dispatchStatus`. Residual shard item 6.

### 16
- status: skipped
- severity: P3
- agent: silent-failure-hunter
- category: Fail closed
- confidence: 30
- action_class: judgment
- file: plugins/cepa/scripts/orca-lane.sh
- lines: 805
- title: hostagents should require the queried env id in hostScope.hostIds

**Problem:**
Suggested assertion.

**Fix:**
Not applied: measured live, a host's own read names itself `hostIds: ["local"]`, so the assertion would refuse every real read.

### 17
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 50
- action_class: mechanical
- file: plugins/cepa/scripts/orca-lane.sh
- lines: 556
- title: Smaller unpinned clauses

**Problem:**
No case pins: `strict and "local" in cov` in the hostread path; hostagents' `totalCount`, `LIMIT`, empty `hostIds` and `agents` list checks; the `wslenvs` runtimeId fallback; rebind with two WSL hosts; `startswith(me + " on ")` against `startswith(me)`.

**Fix:**
One case and one mutant each.

### 18
- status: deferred
- severity: P3
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 70
- action_class: judgment
- file: memory/tasks.d/2026-10-02-punch-list.md
- lines: L89
- title: L89 is only partly closed; the old shard items are not cross-referenced

**Problem:**
The new shard's items 1, 2, 4, 6 stay open; the 2026-11-16 shard items 1, 2, 3, 3b, 5 are not annotated.

**Fix:**
coord@main (the punch list's only writer) records L89 as partly closed and points at the new shard.

### 19
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Observability
- confidence: 40
- action_class: mechanical
- file: plugins/cepa/scripts/orca-lane.sh
- lines: 785-800
- title: An invalid runtimeId silently becomes "-"

**Problem:**
That host then stays strict with no reason given.

**Fix:**
Name it in the kept line.

---

**Summary:** 19 findings (0 P1, 9 P2, 10 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
