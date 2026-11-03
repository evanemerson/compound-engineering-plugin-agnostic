---
date: 2026-11-02T18:11:31
scope: fix/roles/gate-build-outside-lock (PR #128)
branch: fix/roles/gate-build-outside-lock
agents:
  - security-sentinel
  - architecture-reviewer
  - silent-failure-hunter
  - adversarial-reviewer
  - reliability-reviewer
  - previous-comments-reviewer
summary:
  total: 14
  p1: 0
  p2: 7
  p3: 7
  pending: 0
  ready: 0
  skipped: 0
  applied: 14
  deferred: 0
  completed: 0
agents_skipped:
  - agent: python-reviewer
    rule: "not rostered in cepa.local.md: no Python application code"
  - agent: performance-oracle
    rule: "not rostered in cepa.local.md: no queries or request paths"
  - agent: data-integrity-guardian
    rule: "not rostered in cepa.local.md: no migrations or models"
  - agent: schema-drift-detector
    rule: "not rostered in cepa.local.md: no models, migrations, serializers, forms or admin"
  - agent: frontend-reviewer
    rule: "not rostered in cepa.local.md: no templates, JS/CSS or components"
  - agent: deployment-verifier
    rule: "not rostered in cepa.local.md: nothing deploys from this repo"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff is 384 lines and changes a machine-wide lock contract"
  - agent: reliability-reviewer
    dispatched: true
    signal: "diff changes what runs under the stack gate's flock"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; the diff flips finding #7 of todos/review-2026-11-02-092950-feat-roles-stack-gate.md and strikes shard item 1"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier not rostered: nothing deploys from this repo"
  conditions: []
detection_signals:
  matched_docs: 4
  docs_with_detection: 4
  signals_passed: 16
  sources:
    - docs/solutions/logic-errors/an-assertion-must-name-the-edit-that-reddens-it.md
    - docs/solutions/logic-errors/a-control-suite-proves-only-the-branch-it-exercises.md
    - docs/solutions/logic-errors/each-fix-reintroduced-the-defect-class-one-layer-down.md
    - docs/solutions/logic-errors/a-doc-claiming-a-mechanism-must-state-how-that-mechanism-runs.md
  backfill_candidates: []
  suspect_bullets: 0
brain:
  status: available
  pre_step: "skipped — registry exit 3 (no manifest); recall not run"
  suspect_stripped: 0
---

# Review Findings — 2026-11-02 18:11

Review of PR #128 (punch-list L68) at head `de6dfad`. Roster from the main
checkout's `cepa.local.md` (security-sentinel, architecture-reviewer,
silent-failure-hunter) plus all three conditional agents. Fixes are applied
in the follow-up commit on the same branch. Design choices the review raised
are filed as residuals in
`memory/tasks.d/2026-11-02-fix-roles-gate-build-outside-lock.md`.

## Findings

### 1
- status: applied
- severity: P2
- agent: security-sentinel, architecture-reviewer, silent-failure-hunter, adversarial-reviewer
- category: Build inputs
- confidence: 75
- action_class: corroborated
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 167-185
- title: Setup builds before the lane's `.env` exists

**Problem:**
Step 2 builds before step 4 writes `.env`. A compose file that takes build
args or an image name from `.env` builds wrong or names an image the
`--no-build` start cannot find.

**Fix:**
Step 2 now states the precondition: the build reads nothing from the lane's
`.env`; every build arg and image name comes from the committed compose file
and the project name. The coord@main first prompt's step 2 lists it as a gap.

### 2
- status: applied
- severity: P2
- agent: architecture-reviewer
- category: Cite once
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 136-143
- title: Start-only rule and its rationale restated in the skill and the gate header

**Problem:**
The skill restated the gate header's lock rationale, with the 5-8 min and
600 s figures, which drift apart.

**Fix:**
The gate header keeps the rationale. The skill bullet keeps the contract
(the needle sentence) and cites the header; the `make up` pointer is trimmed.

### 3
- status: applied
- severity: P2
- agent: adversarial-reviewer, security-sentinel
- category: Resource ceilings
- confidence: 75
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 136-143
- title: Builds now run outside the stack count and the RAM floor

**Problem:**
Builds of several lanes run at once, with no count and no MemAvailable
check, and a refused lane keeps its built images. Property 8 called the RAM
floor the real boundary.

**Fix:**
Stated in the gate bullet, property 8 and the gate header. Bounding builds
(a build semaphore or a RAM check before the build) is a design choice,
filed as residual 1.

### 4
- status: applied
- severity: P2
- agent: reliability-reviewer, adversarial-reviewer
- category: Image identity
- confidence: 60
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 167-185
- title: A fixed `image:` tag lets one lane start another lane's build

**Problem:**
With build and start split, lane B can retag `app:dev` between lane A's
build and A's gated start, so A runs B's code.

**Fix:**
Step 2 makes property 10 a precondition (no fixed `image:` on a built
service); the coord@main first prompt's step 2 lists it as a gap.

### 5
- status: applied
- severity: P2
- agent: reliability-reviewer
- category: Lock scope
- confidence: 85
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 178-185
- title: Setup still holds the lock through its migrations

**Problem:**
The gated setup init runs migrations under the lock, which contradicts
"start only" and can still push a late lane toward lock_wait_seconds.

**Fix:**
Step 4 and the gate header now name setup as the one gated command that is
not the start only. Moving migrations after the gate is a design choice,
filed as residual 2.

### 6
- status: applied
- severity: P2
- agent: reliability-reviewer
- category: Lock scope
- confidence: 75
- action_class: judgment
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 24-40
- title: `up -d --no-build` still pulls and waits on health under the lock

**Problem:**
`--no-build` still pulls a missing pull-only image and waits on
`depends_on` health conditions, so the hold is not bounded by the rule.

**Fix:**
The gate header says what still runs under the lock. Pre-pulling outside
the gate is filed as residual 3.

### 7
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Diagnosis
- confidence: 40
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 202-207
- title: A `No such image` start has no stated cause or recovery

**Problem:**
When the build names an image the start does not want, the operator sees
compose's `No such image`, not a `STACK` line.

**Fix:**
The `make up` text and setup step 2 say what it means and what to do.

### 8
- status: applied
- severity: P3
- agent: reliability-reviewer, architecture-reviewer, previous-comments-reviewer
- category: Hygiene
- confidence: 95
- action_class: corroborated
- file: plugins/cepa/scripts/stack-gate.sh
- lines: 34
- title: Header line merged past the wrap width

**Problem:**
The edit joined the SIGTERM sentence onto the previous line.

**Fix:**
Re-wrapped.

### 9
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Counters
- confidence: 95
- action_class: mechanical
- file: todos/review-2026-11-02-092950-feat-roles-stack-gate.md
- lines: 11-21
- title: Summary counters not updated after #7 flipped to applied

**Problem:**
The summary still said applied 22, deferred 7.

**Fix:**
Set applied 23, deferred 6.

### 10
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Residual tracking
- confidence: 70
- action_class: judgment
- file: memory/tasks.d/2026-11-02-feat-roles-stack-gate.md
- lines: 4
- title: Striking item 1 dropped its two other open choices

**Problem:**
Item 1 also listed a holder file and a lock-busy exit code; "Fixed by L68"
lost both.

**Fix:**
The strike line now says the exit code stays with item 7 and the holder
file is filed as residual 4.

### 11
- status: applied
- severity: P3
- agent: reliability-reviewer, previous-comments-reviewer
- category: Lock scope
- confidence: 55
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 178-185
- title: A nested `make up` would build under the outer lock

**Problem:**
A gated setup init that called `make up` would run its build inside the
outer gate's lock (same-project nesting runs at once).

**Fix:**
Step 4 says the init starts with `compose up -d --no-build`, never
`make up`, and why.

### 12
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Vacuous case
- confidence: 55
- action_class: mechanical
- file: scripts/check-lane-stack.sh
- lines: 200-210
- title: Three refusal cases pass when make crashes early

**Problem:**
`rc != 0 and nothing(r)` also holds for a Makefile syntax error.

**Fix:**
Each case now also asserts its refusal message (`has no -wt-`,
`checkout identity unknown`).

### 13
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Cost
- confidence: 60
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 202-207
- title: Every `make up` runs a build

**Problem:**
A worker runs `make up` before exec targets; after a source edit the build
rebuilds layers below the copy, outside any bound.

**Fix:**
The `make up` text states the cost (a cache hit when warm). Building only
when the image is missing is part of residual 1.

### 14
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Coverage
- confidence: 70
- action_class: mechanical
- file: scripts/check-lane-stack.sh
- lines: 36-45
- title: No leg checks the Setup order or its build preconditions

**Problem:**
The Setup order and preconditions, where findings 1 and 4 live, are prose
only.

**Fix:**
Recorded in the checker's STATED LIMITS.

---

**Summary:** 14 findings (0 P1, 7 P2, 7 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
