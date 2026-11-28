---
date: 2026-11-27T22:03:13
scope: fix/formulation/gate-release-early
branch: main
pr: 151
agents:
  - learnings-researcher
  - adversarial-reviewer
  - reliability-reviewer
  - previous-comments-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
  - comment-analyzer
summary:
  total: 24
  p1: 0
  p2: 12
  p3: 12
  pending: 0
  ready: 0
  skipped: 0
  applied: 18
  deferred: 6
  completed: 0
agents_skipped:
  - agent: security-sentinel
    rule: "no cepa.local.md roster (headless, stack inferred): bash tooling with no auth, PHI or network surface; hostile holder-file values covered by adversarial-reviewer and pr-test-analyzer"
  - agent: performance-oracle
    rule: "no cepa.local.md roster: no queries or request paths"
  - agent: python-reviewer
    rule: "no cepa.local.md roster: Python is test harness only, read by pr-test-analyzer"
  - agent: architecture-reviewer
    rule: "no cepa.local.md roster: no module boundary change; the contract owner (gate header) is unchanged"
  - agent: data-integrity-guardian
    rule: "no cepa.local.md roster: no migrations or models"
  - agent: schema-drift-detector
    rule: "no models, migrations, serializers, forms or admin"
  - agent: frontend-reviewer
    rule: "no templates, JS/CSS or components"
  - agent: deployment-verifier
    rule: "nothing deploys from this repo; the change is plugin tooling"
  - agent: type-design-analyzer
    rule: "no new types"
  - agent: code-simplifier
    rule: "skipped for cost; diff is tests and a lock contract already reviewed by six agents"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff is about 1070 lines and changes a machine-wide lock contract"
  - agent: reliability-reviewer
    dispatched: true
    signal: "diff changes what runs under the stack gate's flock"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; residual shards touch the diff's files"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped: nothing deploys from this repo"
  conditions: []
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
  corpus: none
learnings_research: "ok"
---

# Review Findings — 2026-11-27 22:03 (PR #151)

No `cepa.local.md` in this repo: headless run, stack inferred (bash tooling,
Python test harness). Six review agents ran on head `cb48bae`. Fixes applied
on the next commit.

## Findings

### 1
- status: applied
- severity: P2
- agent: silent-failure-hunter, adversarial-reviewer
- category: Error handling
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: Setup block, lane_stop
- title: Setup exits 0 when its final compose stop fails

**Problem:**
`compose stop || echo …; exit "$rc"` kept rc 0 after a failed stop, so a
"successful" setup left the lane's stack running and counted by the gate.

**Fix:**
A failed stop sets rc 1 when rc was 0. New SETUP case (stub `STUB_DOCKER_FAIL=stop`) and control `skill-stop-failure-ok`.

### 2
- status: applied
- severity: P2
- agent: silent-failure-hunter, pr-test-analyzer
- category: Test coverage
- confidence: 85
- action_class: corroborated
- file: scripts/check-stack-gate.sh
- lines: HOLDER leg
- title: Failed holder write path had no test

**Problem:**
The header promises a WARN and a start that goes on; removing the WARN or making it fatal stayed green.

**Fix:**
Case with a read-only config directory; controls `holder-warn-silent` and `holder-write-fatal`.

### 3
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 80
- action_class: mechanical
- file: scripts/check-stack-gate.sh
- lines: HOLDER leg
- title: Hostile holder values never tested

**Problem:**
A mutant printing project, lane or start time raw survived.

**Fix:**
Case with ESC, BEL and `$(…)` in a live-pid holder file; control `holder-unclean`.

### 4
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 80
- action_class: mechanical
- file: scripts/check-stack-gate.sh
- lines: HOLDER leg
- title: Holder file with no valid pid never tested

**Problem:**
The pid regex guards the `/proc` path; deleting it survived.

**Fix:**
Cases for no pid, `pid=abc`, `pid=../self`; control `holder-any-pid`.

### 5
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 80
- action_class: mechanical
- file: scripts/check-stack-gate.sh
- lines: HOLDER leg
- title: Stale holder overwrite never tested

**Problem:**
A writer that skips an existing file survived, so a stale file could mask every later holder.

**Fix:**
Case: stale file, then a live holder is named; control `holder-no-overwrite`.

### 6
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 75
- action_class: mechanical
- file: scripts/check-stack-gate.sh
- lines: HOLDER leg
- title: Lane from the git top level never tested

**Problem:**
The tests ran outside git, so only the `$PWD` fallback ran.

**Fix:**
Case run from a subdirectory of a git repo; control `holder-lane-pwd`.

### 7
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 80
- action_class: mechanical
- file: scripts/check-stack-gate.sh
- lines: PULL leg
- title: The --ignore-buildable check had no mutant only it kills

**Problem:**
No stub help lacked only `--ignore-buildable`.

**Fix:**
`STUB_COMPOSE_OLD=buildable` case; control `pull-buildable-unchecked`.

### 8
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 80
- action_class: mechanical
- file: scripts/check-stack-gate.sh
- lines: SETUP leg
- title: Setup with a failed pull never tested

**Problem:**
`--pull … || true` in the Setup block survived.

**Fix:**
SETUP case with `STUB_PULL_RC=4`; control `skill-pull-ignored`.

### 9
- status: applied
- severity: P2
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 6-8
- title: Header said setup calls the gate before it writes anything

**Problem:**
Setup now writes `.env` and pulls before the gate.

**Fix:**
Header says setup calls it for the start only, after its build, `.env` and pull.

### 10
- status: applied
- severity: P2
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: orca.yaml example
- title: orca.yaml comment said setup initializes the stack under the lock

**Problem:**
Only the start is under the lock now.

**Fix:**
Comment rewritten to the new order.

### 11
- status: applied
- severity: P2
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: Status block
- title: Status block did not list the 1.61.0 pull mode

**Problem:**
A gate older than 1.61.0 reads `--pull` as a project name and exits 2.

**Fix:**
Status names L70 1.61.0 and the pull failure.

### 12
- status: applied
- severity: P2
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/scripts/lane_scheme.py
- lines: 724
- title: /cepa:setup message cited Setup step 3 for the gate call

**Problem:**
The gate call is step 4 after the renumbering.

**Fix:**
`(skill, Setup step 4)`; check-lane-scheme still 0 MISS.

### 13
- status: applied
- severity: P3
- agent: reliability-reviewer, previous-comments-reviewer
- category: Lock scope
- confidence: 80
- action_class: corroborated
- file: plugins/cepa/scripts/stack-gate.sh
- lines: cepa_sg_pstart, cepa_sg_write_holder
- title: Holder helpers inherited the lock fd

**Problem:**
`git`, `cat` and `date` ran with the start lock open; a helper that outlives its call would hold the lock.

**Fix:**
`cat` and `date` are bash built-ins now; `git`, `mv` and `rm` run with the fd closed, `git` under `timeout 5`.

### 14
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Error handling
- confidence: 80
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- lines: cepa_sg_holder_desc
- title: An unreadable start time was reported as a reused pid

**Problem:**
`pid_start=unknown` always differed, so a live holder read as "another process".

**Fix:**
Its own message; case and control `holder-unknown-start-reused`.

### 15
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Input handling
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- lines: cepa_sg_write_holder
- title: A newline in the lane name could add fields to the holder record

**Problem:**
The reader keeps the last value of a key, so a lane directory named with `\npid=…` relabels the holder.

**Fix:**
The lane is filtered on write; case and control `holder-write-unfiltered`.

### 16
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Test flakiness
- confidence: 70
- action_class: mechanical
- file: scripts/check-stack-gate.sh
- lines: HOLDER live case
- title: The live-holder case raced on a fixed sleep

**Problem:**
Under load the holder could return before the waiter read it.

**Fix:**
The holder waits on a release file the harness writes after its reads.

### 17
- status: applied
- severity: P3
- agent: comment-analyzer, reliability-reviewer
- category: Comment accuracy
- confidence: 80
- action_class: corroborated
- file: plugins/cepa/scripts/stack-gate.sh
- lines: header, SKILL.md, check-lane-stack.sh, residual-integrity.yml, residual shard
- title: Nine stale or loose doc lines

**Problem:**
"gated setup" wording, SIGKILL-only, "now", no pull in "When setup fails" or the worker prompt, MAKE-leg order and STATED LIMITS, CI comment source, shard date and restated numbers, pid-namespace meaning of "not running".

**Fix:**
Each line corrected in place.

### 18
- status: deferred
- severity: P3
- agent: reliability-reviewer
- category: Timeouts
- confidence: 75
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- lines: cepa_sg_pull_mode
- title: --pull has no time limit

**Problem:**
A stalled registry blocks setup with no alert (no lock held).

**Fix:**
Residual 6 in `memory/tasks.d/2026-11-27-fix-formulation-gate-release-early.md`.

### 19
- status: deferred
- severity: P3
- agent: reliability-reviewer
- category: Scope
- confidence: 65
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- lines: cepa_sg_pull_mode
- title: --pull pulls every service, setup may start a subset

**Problem:**
An unneeded image that cannot be pulled now fails setup.

**Fix:**
Residual 7.

### 20
- status: deferred
- severity: P3
- agent: adversarial-reviewer
- category: Error messages
- confidence: 70
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: Setup block
- title: A failed lane_env prints a false stop-by-hand line

**Problem:**
The trap's stop fails to load the project; rc stays right.

**Fix:**
Residual 8.

### 21
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Error messages
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- lines: cepa_sg_pull_mode
- title: A skipped pull drops the reason pull --help failed

**Problem:**
A bad file, a dead daemon and a timeout print one line.

**Fix:**
Residual 9.

### 22
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Documentation
- confidence: 60
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: The stack gate, Pull
- title: A skipped pull pulling under the lock is stated only in the header

**Problem:**
The caller is not told in the skill text.

**Fix:**
Residual 10.

### 23
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 65
- action_class: judgment
- file: scripts/check-stack-gate.sh
- lines: PULL and HOLDER legs
- title: Five smaller test gaps

**Problem:**
Stdout-only stale check, pull vs build lock, substring flags, help hang, holder removal after a failing command.

**Fix:**
Residual 11.

### 24
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Tracking
- confidence: 85
- action_class: mechanical
- file: memory/tasks.d/2026-11-02-fix-roles-bounded-builds.md
- lines: 7
- title: Old build-lock holder item still pointed at L70 item 4

**Problem:**
L70 item 4 shipped for the start lock only.

**Fix:**
Pointer to residual 1 of the new shard.

---

**Summary:** 24 findings (0 P1, 12 P2, 12 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
