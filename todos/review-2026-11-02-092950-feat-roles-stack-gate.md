---
date: 2026-11-02T09:29:50
scope: feature/roles/stack-gate (PR #126)
branch: feat/roles/stack-gate
agents:
  - adversarial-reviewer
  - reliability-reviewer
  - security-sentinel
  - silent-failure-hunter
summary:
  total: 29
  p1: 0
  p2: 7
  p3: 22
  pending: 0
  ready: 0
  skipped: 0
  applied: 23
  deferred: 6
  completed: 0
agents_skipped:
  - agent: python-reviewer
    rule: "no Python application code; the Python in the diff is check harness and a test stub"
  - agent: performance-oracle
    rule: "no ORM, queries or request paths in the diff"
  - agent: data-integrity-guardian
    rule: "no migrations, models or transactions in the diff"
  - agent: schema-drift-detector
    rule: "no models, migrations, serializers, forms or admin in the diff"
  - agent: frontend-reviewer
    rule: "no templates, JS/CSS or frontend components in the diff"
  - agent: architecture-reviewer
    rule: "one new standalone script beside its siblings; no module boundary changes (worker budget)"
  - agent: deployment-verifier
    rule: "no config, dependency, Docker/compose, env or migration files; a plugin script and CI job only"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff is about 880 lines"
  - agent: reliability-reviewer
    dispatched: true
    signal: "diff adds a machine-wide lock (flock) and external process calls (docker) with timeouts"
  - agent: previous-comments-reviewer
    dispatched: false
    reason: "new files only; the one prior review touching this item (todos/review-2026-11-02-085725-main.md) is a plan review whose 25 findings were applied to the design doc, which binds this build"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped by rule: no config, dependency, Docker/compose, env or migration files"
  conditions: []
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
  corpus: not-consulted
learnings_research: "skipped — worker run; learnings-researcher not dispatched (no cepa.local.md in this repo; stack inferred)"
---

# Review Findings — 2026-11-02 09:29

Review of PR #126 (punch-list L66, `plugins/cepa/scripts/stack-gate.sh`)
at head `eb0ead8`. No `cepa.local.md` exists in this repo, so the stack
(bash + Python check harness) was inferred and the roster chosen from it.
Fixes were applied in the follow-up commit on the same branch.

## Findings

### 1
- status: applied
- severity: P2
- agent: security-sentinel, adversarial-reviewer, silent-failure-hunter
- category: Input parsing
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 124-137, 174-181
- title: Docker label tab, newline or empty value shifts fields and reaches unquoted docker inspect

**Problem:**
`IFS=$'\t' read -r p w i` collapses an empty label (tab is IFS whitespace), so
the id moved into `w`. A tab in working_dir put extra words into `i`, which
reached `docker inspect $ids` unquoted (argument injection, glob). A newline
made a phantom `-wt-` row.

**Fix:**
The template prefixes every field (`i:`, `p:`, `w:`) with the id first and
working_dir last; a row whose id is not `i:` + 64 hex is dropped. ids go to
`docker inspect` as an array after `--`. Case `COUNT empty working_dir label
still counts`.

### 2
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Fail-open
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 91-120
- title: Unreadable config silently applied the defaults

**Problem:**
A conf that exists but cannot be read (mode 000, a directory) ran the loop
zero times: the operator's stricter limit was ignored with no WARN.

**Fix:**
The read returns 1; the gate refuses (`cannot read the config`) and `--count`
prints `running=unknown` with exit 1. Cases `CONFIG unreadable file refuses`,
`COUNTMODE unreadable config is unknown`.

### 3
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: Deadlock
- confidence: 65
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 228-250
- title: A nested gate for the same project waited on its parent's lock and was refused

**Problem:**
Setup gates `make up`, and `make up` is gated too: the inner gate blocked on
the lock its parent held and was refused as "lock busy" after 600 s.

**Fix:**
The outer gate exports `CEPA_STACK_GATE_HELD=<project>` to its command; an
inner gate for that project runs at once (no lock, no recount). Another
project still waits. Cases `LOCK nested gate for the same project runs`,
`LOCK nested gate for another project waits`.

### 4
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Swallowed error
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 169-207
- title: docker inspect failure hidden and idle-unknown stacks sorted last

**Problem:**
An inspect or date failure became `idle unknown` with no reason, and those
stacks sorted LAST — below the 3 options coord@main offers.

**Fix:**
Unknown-idle stacks sort first; a failed inspect appends one note. Clock
skew prints `0m`, and the -1 sentinel is gone. Cases `LIST unreadable start
time sorts first`, `LIST inspect failure is said`.

### 5
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Test fidelity
- confidence: 85
- action_class: mechanical
- file: scripts/fixtures/stack-gate-docker-stub.py
- lines: 1-80
- title: Stub more lenient than docker, so dropping --no-trunc or the label filter stayed green

**Problem:**
The stub echoed whatever id it was given, ignored unknown flags and never
applied `label=`.

**Fix:**
The stub rejects unknown ps flags (exit 64), prints 12-char ids without
`--no-trunc`, applies `label=` and OR-ed `status=` filters, models paused,
restarting, created and non-compose containers, and has
`STUB_DOCKER_FAIL=inspect`. Mutant `ids-truncated` now dies.

### 6
- status: applied
- severity: P2
- agent: reliability-reviewer, silent-failure-hunter
- category: Flaky test
- confidence: 80
- action_class: corroborated
- file: scripts/check-stack-gate.sh
- lines: 243-265, 304-311
- title: LOCK cases ordered by sleep(0.4); a slow runner gave false results

**Problem:**
The lock holders and the first start were assumed to hold the lock after
0.4 s. Under load this gave a false red, and for `COUNTMODE takes no lock` a
false green. A `TimeoutExpired` crashed the harness.

**Fix:**
The first start's command touches a sentinel; outside holders print `ready`
under flock and the harness reads it. A timed-out run becomes a MISS.

### 7
- status: applied
- severity: P2
- agent: reliability-reviewer, adversarial-reviewer
- category: Lock scope
- confidence: 80
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 20-30
- title: Lock held for the whole command, so a long build or attached command blocks every other start

**Problem:**
A cold `compose up -d --build` of 5-8 minutes, or a foreground `compose up`
or `compose run`, holds the one machine lock; the third lane's start is
refused after 600 s as "lock busy" with capacity to spare.

**Fix:**
Applied now: the header states the contract (the command must return once
the stack is started: `up -d`, `start`, `restart`; never attached), and a
waiting start prints one line. Deferred (design choice): build outside the
gate, a holder file naming who holds the lock, or a separate exit code for
"lock busy". Residual in `memory/tasks.d/2026-11-02-feat-roles-stack-gate.md`.
Applied later by L68 (fix/roles/gate-build-outside-lock): the lane-stack
skill builds outside the gate and gates only `up -d --no-build`; the gate
header says the command is the start only.

### 8
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Test coverage
- confidence: 90
- action_class: mechanical
- file: scripts/check-stack-gate.sh
- lines: 267-290
- title: No case covered the inspect failure or an unparsable start time

**Problem:**
The idle-unknown path could change with no case noticing.

**Fix:**
Two LIST cases and two mutants (`unknown-idle-last`, `inspect-failure-silent`).

### 9
- status: applied
- severity: P3
- agent: reliability-reviewer, silent-failure-hunter
- category: Diagnostics
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 229-230
- title: Every flock failure read as "lock busy"

**Problem:**
rc 64 (bad fd) or 127 (no flock) sent the operator hunting for another start.

**Fix:**
rc 1 is "lock busy"; any other code is "cannot lock — flock exited N".

### 10
- status: applied
- severity: P3
- agent: reliability-reviewer, silent-failure-hunter, adversarial-reviewer
- category: Diagnostics
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 126-131
- title: docker stderr merged into rows; a timeout gave an empty reason

**Problem:**
`2>&1` let a stderr line holding `-wt-` count as a stack; rc 124 printed
`docker ps failed: ` with nothing after it.

**Fix:**
stderr goes to a temp file used only for the message; 124/137 say "timed out
after 30s"; other codes print the rc and the first stderr line.

### 11
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Counting
- confidence: 65
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 126
- title: Paused and restarting stacks were not counted

**Problem:**
`--filter status=running` left out paused (memory kept) and crash-looping
stacks.

**Fix:**
`status=running`, `paused` and `restarting` are counted; exited and created
are not. Case `COUNT paused and restarting stacks count`, mutant
`paused-not-counted`.

### 12
- status: applied
- severity: P3
- agent: security-sentinel, silent-failure-hunter
- category: Test hook
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 78
- title: CEPA_STACK_GATE_MEMINFO honored silently in production

**Problem:**
A stray env var could pass the memory check with no sign.

**Fix:**
The gate prints a WARN on stderr whenever the path is not `/proc/meminfo`.

### 13
- status: applied
- severity: P3
- agent: security-sentinel
- category: Permissions
- confidence: 55
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 227
- title: Lock directory created with the default umask

**Problem:**
Another local user could open a 0755 directory and hold the lock.

**Fix:**
`mkdir -p -m 700`.

### 14
- status: applied
- severity: P3
- agent: adversarial-reviewer, silent-failure-hunter
- category: Contract
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 73
- title: HOME unset died with an unbound-variable error and no STACK line

**Problem:**
rc 1 outside the documented 2/3 contract.

**Fix:**
`STACK gate: usage — HOME is not set`, exit 2. Case `USAGE HOME unset`.

### 15
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Vacuous assertion
- confidence: 70
- action_class: mechanical
- file: scripts/check-stack-gate.sh
- lines: 209-211
- title: The no-`-a` assertion passed when docker was never called

**Problem:**
An absent log defaulted to `[]`.

**Fix:**
The case requires at least one logged `ps` call.

### 16
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Vacuous control
- confidence: 65
- action_class: mechanical
- file: scripts/check-stack-gate-controls.sh
- lines: 123-131
- title: A crashed check counted as a kill for None-set mutants

**Problem:**
A traceback with no summary line read as red.

**Fix:**
A run with no `check-stack-gate: N passed, M failed` line is a failed control.

### 17
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Hygiene
- confidence: 90
- action_class: mechanical
- file: scripts/check-stack-gate.sh
- lines: 62-103
- title: Temp dirs and lock holders leaked on every run

**Problem:**
`/tmp/cepa-sg-*` was never removed.

**Fix:**
An atexit hook removes every Env dir and kills the holders.

### 18
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Arithmetic injection
- confidence: 40
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 203
- title: Docker label used as an array subscript inside $(( ))

**Problem:**
On bash before 5.2 the subscript is re-expanded (not reproduced on 5.2.21).

**Fix:**
The value is copied to a plain variable before the arithmetic.

### 19
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Word splitting
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 202
- title: Unquoted for-loop over project names emptied the listing under set -u

**Problem:**
A project label with a space aborted the listing (`wd[$proj]: unbound`).

**Fix:**
A `while read` loop and `${wd[$proj]:-}`.

### 20
- status: applied
- severity: P3
- agent: reliability-reviewer
- category: Builtins
- confidence: 40
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 250
- title: A builtin in argv[0] ran inside the gate shell

**Problem:**
`"$@"` with `exec` or `exit` first would act on the gate itself.

**Fix:**
`command "$@"`.

### 21
- status: applied
- severity: P3
- agent: reliability-reviewer
- category: Signals
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 126, 181
- title: Ctrl-C ignored for up to 30 s during docker calls

**Problem:**
`timeout` puts docker in its own process group.

**Fix:**
`timeout --foreground`.

### 22
- status: applied
- severity: P3
- agent: reliability-reviewer, adversarial-reviewer
- category: Contract
- confidence: 60
- action_class: corroborated
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 24-30, 55-56
- title: --count and exit-code contract left implicit

**Problem:**
A consumer could read `running=unknown` as zero, or `n = limit` as over;
exit 2 and 3 can also be the wrapped command's own codes.

**Fix:**
The header states the alert is `n > limit`, exit 1 is its own alert, and the
`STACK gate:` line, not the exit code, says whether the gate refused.

### 23
- status: deferred
- severity: P3
- agent: reliability-reviewer
- category: Signals
- confidence: 85
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 250
- title: SIGTERM or SIGKILL to the gate leaves the start running without the lock

**Problem:**
A killed `make` orphans `compose up`; another start may count before it is up.

**Fix:**
Stated in the header. Forwarding (background + wait + trap) changes stdin for
the command, so it is left for a decision.

### 24
- status: deferred
- severity: P3
- agent: adversarial-reviewer
- category: Test coverage
- confidence: 90
- action_class: mechanical
- file: scripts/check-stack-gate.sh
- lines: 1
- title: No case tests a hung docker (dropping the timeout stays green)

**Problem:**
A change that removes `timeout` would ship green, and a hung daemon would
hold the machine lock.

**Fix:**
Needs a second test-only override for the 30 s bound and a `STUB_DOCKER_HANG`
mode; left for a follow-up rather than add another env hook here.

### 25
- status: deferred
- severity: P3
- agent: adversarial-reviewer, reliability-reviewer
- category: Lock scope
- confidence: 40
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 73
- title: Lock and config follow $HOME, but Docker is machine-wide

**Problem:**
A start under sudo or another WSL distro takes a different lock. Orca
sessions keep `HOME=/home/evan` (measured by the reviewer), so not live today.

**Fix:**
Stated in the header. A fixed machine path for the lock is a design choice.

### 26
- status: deferred
- severity: P3
- agent: reliability-reviewer
- category: Policy
- confidence: 50
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 242-247
- title: Restart of a running stack refused when the others fill the limit or memory is low

**Problem:**
A start that adds no stack can still be refused, blocking recovery.

**Fix:**
Stated in the header as fail-closed. Skipping both checks when the stack
already runs is a policy choice for the operator.

### 27
- status: deferred
- severity: P3
- agent: reliability-reviewer
- category: Lock leak
- confidence: 30
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 233
- title: docker, timeout and date run with the lock fd open

**Problem:**
A background child of docker (an ssh ControlPersist master) could hold the
lock after the gate exits.

**Fix:**
Close the fd on each call under the lock. Low confidence; left as residual.

### 28
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Diagnostics
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 55
- title: Exit codes 2 and 3 can collide with the wrapped command's codes

**Problem:**
`make` exits 2 on any error.

**Fix:**
Documented (finding 22: the STACK line is authoritative). Choosing codes no
caller uses would break the design's stated contract (Builder-check 6), so it
needs coord@main.

### 29
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Diagnostics
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 229
- title: A waiting start printed nothing, so make looked hung

**Problem:**
`flock -w 600` blocks silently.

**Fix:**
`flock -n` first; on failure one `STACK gate: waiting up to Ns …` line on
stderr. Case `LOCK a waiting start says so`.

---

**Summary:** 29 findings (0 P1, 7 P2, 22 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
