---
date: 2026-11-28T01:59:53
scope: fix/formulation/dispatch-reroute-delivered
branch: main
pr: 154
agents:
  - reliability-reviewer
  - security-sentinel
  - previous-comments-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
  - comment-analyzer
summary:
  total: 9
  p1: 0
  p2: 1
  p3: 8
  pending: 0
  ready: 0
  skipped: 1
  applied: 5
  deferred: 3
  completed: 0
agents_skipped:
  - agent: python-reviewer
    rule: "no cepa.local.md in this lane; stack inferred (bash + embedded Python); the Python is a 12-line proof covered by the readers"
  - agent: architecture-reviewer
    rule: "one branch inside one script; no module boundary changed"
  - agent: performance-oracle
    rule: "no ORM/DB/frontend; one bounded CLI read added"
  - agent: data-integrity-guardian
    rule: "no migrations, models or data writes"
  - agent: schema-drift-detector
    rule: "no models, migrations, serializers, forms or admin"
  - agent: frontend-reviewer
    rule: "no templates/JS/CSS in diff"
  - agent: deployment-verifier
    rule: "no config, dependencies, Docker, env or migration files; plugin script only"
  - agent: type-design-analyzer
    rule: "no new types"
  - agent: code-simplifier
    rule: "diff is one guarded branch; simplification left to the weekly tier"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: false
    reason: "diff about 260 lines and no payments/auth/PHI/migration path"
  - agent: reliability-reviewer
    dispatched: true
    signal: "diff adds an external CLI call with a timeout and retry"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md files exist; memory/tasks.d entries touch orca-send.sh"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped: plugin script only; no deploy surface"
  conditions: []
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
  corpus: none
learnings_research: "skipped — no docs/solutions corpus in this lane"
---

# Review Findings — 2026-11-28 01:59 (PR #154)

No `cepa.local.md` in this lane: the stack was inferred from the repo.

## Findings

### 1
- status: deferred
- severity: P2
- agent: silent-failure-hunter
- category: Error handling
- confidence: 80
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1719
- title: A re-route skip writes no nudge_skipped alert

**Problem:**
The header says every nudge skip except one on the target's own row writes a
`nudge_skipped` alert. The `stored for another handle` skip writes none, and
neither do the chat and downgraded skips. This gap is older than this PR. The
PR adds one more way to reach the skip: a failed or timed-out own-Dispatch read.

**Fix:**
Deferred. orca-health.sh shows only reasons in its REASONS list, and this lane
may not edit that file now. Either add the alert and its reason together, or
change the header to say these skips write no alert. Filed in
`memory/tasks.d/2026-11-28-fix-formulation-dispatch-reroute-delivered.md`.

### 2
- status: applied
- severity: P3
- agent: security-sentinel, reliability-reviewer
- category: Input validation
- confidence: 30
- action_class: corroborated
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1696
- title: Dispatch id is not bound to a ctx_ id before it reaches the CLI

**Problem:**
The recipient regex allows `dispatch:-h`, so `worker-show --dispatch -h` could
be read as a flag. The proof still failed closed, so this is hardening.

**Fix:**
Applied: the branch now requires `dispatch:ctx_*`. A new case (an id that is
not a ctx id is a skip) and the `send-own-dispatch-any-id` mutant pin it.

### 3
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 75
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: 262-268
- title: "One bounded worker-show" omits THE VSOCK RETRY

**Problem:**
`cepa_send_orca` retries once on the vsock error, so the read can be two calls.

**Fix:**
Applied: the header and the inline comment say THE VSOCK RETRY applies.

### 4
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: 266
- title: Header cites THE OWN DISPATCH as if it were a header section

**Problem:**
THE OWN DISPATCH is an inline comment label, not a header section.

**Fix:**
Applied: the header now says "the THE OWN DISPATCH comment at the re-route skip".

### 5
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 50
- action_class: mechanical
- file: memory/tasks.d/2026-11-28-fix-formulation-dispatch-reroute-delivered.md
- lines: 13
- title: Shard cites "D2" without naming L105

**Problem:**
The punch list has more than one "D2"; the shard did not say which.

**Fix:**
Applied: the shard says "L105 item D2".

### 6
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Error handling
- confidence: 70
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1696-1719
- title: The skip line does not say why the own-Dispatch proof failed

**Problem:**
A failed read, a timeout, a status other than `dispatched` and another
terminal all print the same skip line.

**Fix:**
Deferred to the shard: print a short reason (read failed, or proof negative).

### 7
- status: deferred
- severity: P3
- agent: reliability-reviewer
- category: Race condition
- confidence: 40
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: 1696-1716
- title: Dispatch liveness is read after the store, not at store time

**Problem:**
A worker that ends between the store and the read, or a `dispatched` row whose
terminal has exited, gives "not needed" for mail that no one is prompted about.

**Fix:**
Deferred to the shard: consider also requiring `projection.liveness.verdict == live`.

### 8
- status: skipped
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 70
- action_class: judgment
- file: scripts/check-orca-nudge.sh
- lines: 950-953
- title: The failed-read and timed-out-read cases have no mutant of their own

**Problem:**
Only the broad `send-reroute-nudged` mutant kills these two cases.

**Fix:**
No change needed. A failed read leaves `own.json` empty, so every mutant of the
read gate still fails the proof and skips. That mutant is equivalent. The cases
stay as regression guards.

### 9
- status: applied
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 55
- action_class: mechanical
- file: scripts/check-orca-nudge.sh
- lines: 947
- title: No case for terminal null with a valid dispatch

**Problem:**
No case covered `result.terminal: null` beside a valid dispatch.

**Fix:**
Applied: added a `terminal null` skip case.

---

**Summary:** 9 findings (0 P1, 1 P2, 8 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
