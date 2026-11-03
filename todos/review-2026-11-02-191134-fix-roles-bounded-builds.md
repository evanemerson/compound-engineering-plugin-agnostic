---
date: 2026-11-02T19:11:34
scope: fix/roles/bounded-builds (PR #129)
branch: fix/roles/bounded-builds
agents:
  - learnings-researcher
  - architecture-reviewer
  - adversarial-reviewer
  - reliability-reviewer
  - previous-comments-reviewer
  - silent-failure-hunter
summary:
  total: 19
  p1: 0
  p2: 7
  p3: 12
  pending: 0
  ready: 0
  skipped: 0
  applied: 15
  deferred: 4
  completed: 0
agents_skipped:
  - agent: security-sentinel
    rule: "folded into architecture-reviewer's security pass (argv, config never sourced, lock file, output cleaning): a shell gate with no auth, PHI or payment surface"
  - agent: python-reviewer
    rule: "no Python application code: the Python is test harness and a docker stub"
  - agent: performance-oracle
    rule: "no queries or request paths"
  - agent: data-integrity-guardian
    rule: "no migrations or models"
  - agent: schema-drift-detector
    rule: "no models, migrations, serializers, forms or admin"
  - agent: frontend-reviewer
    rule: "no templates, JS/CSS or components"
  - agent: deployment-verifier
    rule: "nothing deploys from this repo; the change is plugin content"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff is 895 lines and adds a machine-wide lock"
  - agent: reliability-reviewer
    dispatched: true
    signal: "diff adds a flock build lock and docker calls with timeouts"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; the diff closes item 1 of memory/tasks.d/2026-11-02-fix-roles-gate-build-outside-lock.md"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped: nothing deploys from this repo"
  conditions: []
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  corpus: absent
  note: "docs/solutions/ does not exist in this worktree (docs/ is gitignored; probe: ls docs/solutions -> No such file or directory)"
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
cepa_local_md: "missing — headless mode inferred the stack (bash + Python test harness)"
---

# Review Findings — 2026-11-02 19:11

## Findings

### 1
- status: applied
- severity: P2
- agent: adversarial-reviewer, reliability-reviewer
- category: Correctness
- confidence: 80
- action_class: corroborated
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 360-410
- title: A failed or partial rebuild is hidden by the next plain `make up`

**Problem:**
The skip tests only that each tag exists. A `--rebuild` that fails after it
tags some images leaves a mix of new and old tags. The next plain `make up`
finds all tags and skips, so the stack starts on mixed images with no
warning.

**Fix:**
The gate writes `~/.config/cepa/build-failed.<project>` before every build
and removes it only when the build exits 0. While it exists, `--build` never
skips. Tested: "BUILD a failed build is built again, a success clears it",
"BUILD a killed build leaves its marker", with two mutants.

### 2
- status: applied
- severity: P2
- agent: reliability-reviewer, adversarial-reviewer, architecture-reviewer, silent-failure-hunter
- category: Concurrency
- confidence: 75
- action_class: corroborated
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 400-408
- title: A gate killed mid-build frees the build lock while its build still runs

**Problem:**
The build child had the lock descriptor closed, so only the gate held the
lock. A SIGTERM or SIGKILL to the gate (a tool timeout, a closed tab) freed
the lock while `compose build` kept running, and the next queued build ran
beside it.

**Fix:**
The build now inherits the descriptor, so the lock lasts as long as the
build. The cost (a process the build leaves running holds the lock too) is
stated in the header. Tested: "BUILD lock outlives a gate killed mid-build",
mutant `build-lock-not-inherited`.

### 3
- status: applied
- severity: P2
- agent: silent-failure-hunter, adversarial-reviewer
- category: Test coverage
- confidence: 90
- action_class: corroborated
- file: scripts/check-stack-gate.sh
- title: The plain-reference guard on image names has no test or mutant

**Problem:**
No case listed an image name that fails the regex, so loosening it or
turning its `return 1` into `continue` stayed green.

**Fix:**
Case "BUILD a name that is not a plain reference builds" lists `-x`, `a b`
and `/web:` (all present in the stub store), asserts a build, and asserts
`docker image inspect` was never called. Mutant `build-plain-ref-skipped`.

### 4
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Test coverage
- confidence: 90
- action_class: mechanical
- file: scripts/check-stack-gate.sh
- title: Build-mode refusal branches have no test

**Problem:**
No case covered an unreadable config, a failed mkdir or open of the lock
file, or a flock exit other than 1 in build mode.

**Fix:**
Added "BUILD unreadable config refuses" (skipped as root) with mutant
`build-conf-ignored`. The mkdir, open and other-flock-exit branches are the
same shape as the start mode's and stay untested: filed as finding 18.

### 5
- status: applied
- severity: P2
- agent: architecture-reviewer
- category: Contract
- confidence: 80
- action_class: mechanical
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 164-170
- title: The skill's Output and Exit bullets did not cover the build mode

**Problem:**
The bullets named only `STACK gate:` lines and the start command's exit.

**Fix:**
Each bullet now says the build mode prints `STACK build: …` lines and that
its exit codes are the header's (cited, not restated).

### 6
- status: applied
- severity: P3
- agent: reliability-reviewer
- category: Efficiency
- confidence: 75
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- title: A build that waited for the same project's build rebuilds anyway

**Problem:**
Setup and a `make up` of one lane both probed before the lock, both found
the images missing, and the second ran a full cache-hit build holding the
machine-wide lock.

**Fix:**
A `--build` that waited re-checks the images once it holds the lock and
skips when they now exist. Tested: "BUILD a waiter skips once the same
project was built", mutant `build-waiter-no-recheck`.

### 7
- status: applied
- severity: P3
- agent: reliability-reviewer
- category: Documentation
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- title: The 3600 s sizing assumed FIFO, but flock does not wake waiters in order

**Problem:**
The header implied the last of six lanes waits for five builds.

**Fix:**
The header states that flock is not fair, that `lock busy` is retryable,
and that the wait limit is a sizing, not a promise.

### 8
- status: applied
- severity: P3
- agent: adversarial-reviewer, architecture-reviewer, silent-failure-hunter, previous-comments-reviewer
- category: Documentation
- confidence: 85
- action_class: corroborated
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 42-47
- title: The header and nesting comment still offered `stack-gate.sh p -- make up`

**Problem:**
`make up` now calls `--build`, which refuses inside a gated command, so the
documented nesting fails. SKILL.md Setup step 4 gave the old reason ("its
build would run under this lock").

**Fix:**
The header's Nesting text and the nesting comment name a start-only target
and say `make up` refuses there. Step 4 now says the build step refuses
inside a gated command.

### 9
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Operator contract
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/skills/lane-stack/SKILL.md
- title: The worker step matched only `STACK gate: refused`, and a build wait outlasts a tool timeout

**Problem:**
A build refusal or failure prints `STACK build: …`, which the worker step
did not name, and a foreground `make up` can be killed by the tool while it
waits.

**Fix:**
The worker step names `STACK build: refused` and `STACK build: failed`, says
to run `make up` in the background or with a long timeout, and says the next
`make up` after a failed build builds again. The gate contract says the same.

### 10
- status: applied
- severity: P3
- agent: adversarial-reviewer, architecture-reviewer
- category: Makefile semantics
- confidence: 80
- action_class: corroborated
- file: plugins/cepa/skills/lane-stack/SKILL.md
- title: `$(if $(BUILD),…)` rebuilt on `BUILD=0` and on any inherited BUILD

**Problem:**
Any non-empty BUILD turned every `make up` into `--rebuild`, and the check's
`make()` passed the caller's BUILD and MAKEFLAGS through.

**Fix:**
The block uses `$(filter 1,$(BUILD))`; the skill says only `1` rebuilds and a
repo that already uses `BUILD` renames the switch. `make()` drops BUILD,
MAKEFLAGS, MAKELEVEL and CEPA_STACK_GATE_HELD. Case "MAKE BUILD=0 does not
rebuild", mutant `make-build-any-value`.

### 11
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Operator contract
- confidence: 55
- action_class: mechanical
- file: plugins/cepa/skills/lane-stack/SKILL.md
- title: First-prompt step 5 "Rebuild old lanes" no longer rebuilds images

**Problem:**
A lane re-created under its old name keeps its project and images, so setup
skips the build.

**Fix:**
Step 5 says so and tells the lane's first worker to run `make up BUILD=1`
when the base changed what an image installs.

### 12
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Correctness
- confidence: 50
- action_class: mechanical
- file: plugins/cepa/skills/lane-stack/SKILL.md
- title: Two compose files that build one service name share a tag, and the skip trusts it

**Problem:**
`<project>-web` does not encode the compose file, so a test-stage image from
another file can satisfy the dev skip.

**Fix:**
The Builds bullet adds the precondition: one compose file builds a given
service per project.

### 13
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 55
- action_class: mechanical
- file: plugins/cepa/skills/lane-stack/SKILL.md
- title: The skip weakens prior finding #4 (fixed `image:` tags)

**Problem:**
With a fixed `image:` on a built service, the skip trusts another lane's
image.

**Fix:**
The Builds bullet says the skip relies on Setup step 2's preconditions,
which include "no fixed `image:`".

### 14
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Restatement
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/skills/lane-stack/SKILL.md
- title: The Builds bullet restated what the gate header owns

**Problem:**
The bullet restated the waiting line, the lock details and the refusal
inside a gate.

**Fix:**
Those now cite the header ("How it locks, waits and marks a failed build is
the gate header's"). The call shape, the skip and the BUILD=1 rule stay,
since the checker pins them as the caller's contract.

### 15
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Diagnostics
- confidence: 75
- action_class: mechanical
- file: plugins/cepa/scripts/stack-gate.sh
- title: An inspect failure was reported as a missing image

**Problem:**
A daemon outage or a timeout read as "at least one image is missing".

**Fix:**
The reason now says "is missing, or docker image inspect failed". The probe's
stderr is still not shown: filed with finding 18.

### 16
- status: deferred
- severity: P2
- agent: adversarial-reviewer, silent-failure-hunter
- category: Correctness
- confidence: 80
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- title: The skip accepts a stale image after base drift

**Problem:**
A worker whose own diff touches no build input runs plain `make up` after
another lane's requirements change merged to the base. The skip finds the old
tag and the stack runs old dependencies. The worker cannot know when its
lane's images were built.

**Fix:**
Make the skip depend on build inputs: a per-project stamp (hash of the
resolved compose build sections, Dockerfiles and lock files) written after a
build exits 0, or a `build.labels` hash compared through `image inspect`.
This widens the operator's choice C (skip when images exist), so it is the
operator's decision. Filed as residual.

### 17
- status: deferred
- severity: P2
- agent: reliability-reviewer, silent-failure-hunter
- category: Reliability
- confidence: 80
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- title: A build has no time limit, so a hung build holds the machine-wide lock

**Problem:**
Every docker call in the probe has a 60 s timeout; the build does not. A
wedged daemon or registry stall holds the lock, and every other lane is
refused after `build_wait_seconds`. Now that the lock follows the build
(finding 2), a hang lasts until the build is stopped.

**Fix:**
A `build_timeout_seconds` key with a generous default (for example 2700 s)
around the build. The value is a policy choice. Stated in the header as
"Stated, not handled"; filed as residual.

### 18
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Diagnostics
- confidence: 70
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- title: Probe stderr, mkdir stderr and non-contention flock errors are hidden or mislabeled

**Problem:**
`config --images` and `image inspect` stderr are dropped, `mkdir` stderr is
dropped, and any `flock -n` failure prints "waiting". The untested branches
(mkdir, open, other flock exit) are the start mode's shape too.

**Fix:**
Capture the first stderr line through `cepa_sg_clean` into the reason, test
`flock -n` for rc 1, and add cases with a stub `flock`. Touches the start mode
as well, so filed as residual rather than widened here.

### 19
- status: deferred
- severity: P3
- agent: reliability-reviewer
- category: Diagnostics
- confidence: 40
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- title: A queued build prints one waiting line for up to an hour

**Problem:**
A caller cannot tell a hung queue from a long one.

**Fix:**
Ties to L70 item 4 (a lock-holder file). Filed as residual beside it.

---

**Summary:** 19 findings (0 P1, 7 P2, 12 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
