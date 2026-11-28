---
date: 2026-11-27T20:21:33
scope: pr:148
branch: fix/matrix/rebind-null-holder
agents:
  - adversarial-reviewer
  - previous-comments-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
  - comment-analyzer
summary:
  total: 12
  p1: 0
  p2: 2
  p3: 10
  pending: 0
  ready: 0
  skipped: 1
  applied: 8
  deferred: 3
  completed: 0
learnings_research: "skipped — no docs/solutions/ corpus in this checkout; CLAUDE.md read directly"
detection_signals:
  corpus: not-consulted
  signals: 0
  source_docs: 0
  backfill_candidates: 0
  suspect_bullets: 0
agents_skipped:
  - security-sentinel: "no cepa.local.md; no auth, PHI or payment surface in the diff"
  - performance-oracle: "no cepa.local.md; shell script with a bounded call count"
  - python-reviewer: "no cepa.local.md; Python is embedded test and reader code only"
  - data-integrity-guardian: "no migrations or data stores in the diff"
  - architecture-reviewer: "no cepa.local.md; one script's internal branch"
  - schema-drift-detector: "no models, migrations, serializers, forms or admin"
  - frontend-reviewer: "no templates, JS/CSS or frontend components"
  - deployment-verifier: "no config, dependencies, Docker, env or migration files"
conditional_dispatch:
  adversarial-reviewer: {dispatched: true, signal: "diff about 330 changed lines"}
  reliability-reviewer: {dispatched: false, reason: "signal absent: no task-queue, webhook or transaction code"}
  previous-comments-reviewer: {dispatched: true, signal: "todos/review-*.md exist; punch-list entries touch the diff"}
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped by its roster rule (no config, dependency, env or migration files)"
config_note: "cepa.local.md is missing; headless review inferred the stack (bash + embedded python3)"
---

# Review Findings — 2026-11-27 20:21

## Findings

### 1
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Fail-closed
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/scripts/orca-rebind.sh
- lines: 392-395
- title: run-current's term_ holder is dropped when run-show reads null

**Problem:**
With `run:` and `confirm:`, run-current could name the Run held by a `term_`
handle while run-show read null; the confirmed null path then skipped every
liveness read and could take a Run that a live terminal held.

**Fix:**
Applied: when run-current names the same Run with a `term_` holder and
run-show reads null, the script asks ("the two reads disagree"). Test:
`REBIND run-current holder and a null run-show disagree asks`; mutant
`rebind-null-disagree-off`.

### 2
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Messages
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/scripts/orca-rebind.sh
- lines: 536-570
- title: the `-` sentinel shows in user-facing text

**Problem:**
The recheck ask and the final `failed` line printed `run_x - 2`.

**Fix:**
Applied: both render `-` as `(no recorded holder)`.

### 3
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Messages
- confidence: 50
- action_class: mechanical
- file: plugins/cepa/scripts/orca-rebind.sh
- lines: 560-565
- title: a run-use that leaves a null Run unchanged blames another session

**Problem:**
The failure said another session may have re-bound the Run and told the
operator to close a holder terminal that does not exist.

**Fix:**
Applied: its own `failed` line and ending ("check in Orca whether a chat or
bot holds <run>"). Test: `REBIND confirmed null holder that run-use left null
fails`; mutant `rebind-null-unmoved-off`.

### 4
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comments
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/scripts/orca-rebind.sh
- lines: 124
- title: a bare plugin version reads as an Orca version

**Problem:**
"Up to 1.60.4" sat beside Orca 1.4.x versions.

**Fix:**
Applied: "Up to cepa 1.60.4".

### 5
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comments
- confidence: 90
- action_class: mechanical
- file: memory/tasks.d/2026-11-27-rebind-null-holder.md
- lines: 13
- title: residual 1 cites orca-health.sh:913, the check is at 912-914

**Problem:**
The line reference was one line off.

**Fix:**
Applied: `:912-914`.

### 6
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Docs
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 2245-2250
- title: rule 2's ask list and header step 1 omit the no-run: null-holder ask

**Problem:**
The script asks when no `run:` is named and run-current shows a null holder;
SKILL.md's ask list and the header's step 1 did not say so.

**Fix:**
Applied to both.

### 7
- status: skipped
- severity: P2
- agent: pr-test-analyzer
- category: Mutation coverage
- confidence: 20
- action_class: judgment
- file: plugins/cepa/scripts/orca-rebind.sh
- lines: 392
- title: no mutant loosens the null-holder confirm gate to `-z confirm`

**Problem:**
The analyzer proposed a test with `confirm: run_other` beside a null holder.

**Fix:**
Skipped: field parsing refuses a `confirm:` that differs from `run:` before
any Orca call (`REBINDREF confirm of another Run`), so `confirm` is either
empty or equal to `run` at line 392. A `[ -z "$cepa_rb_confirm" ]` mutant is
equivalent and no test can kill it.

### 8
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Tests
- confidence: 75
- action_class: mechanical
- file: scripts/check-orca-nudge.sh
- lines: 2620-2630
- title: no test pins that a malformed holder stays an unknown shape

**Problem:**
Only `term_x; id` was tested; a missing key, `""` or a literal `"-"` could be
read as holder unknown by a looser reader.

**Fix:**
Applied: three run-show cases (no key, empty, `-`), each exit 3; mutant
`rebind-null-falsy`.

### 9
- status: applied
- severity: P3
- agent: pr-test-analyzer
- category: Tests
- confidence: 60
- action_class: mechanical
- file: scripts/check-orca-nudge.sh
- lines: 2630-2660
- title: null-holder recheck, re-read and run-current-mismatch cases untested

**Problem:**
No case covered a generation-only change on the recheck, a null re-read after
run-use, or a confirmed null holder while run-current reports another Run.

**Fix:**
Applied: four cases for those paths.

### 10
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Tests
- confidence: 50
- action_class: judgment
- file: scripts/check-orca-nudge.sh
- title: the RULE2BLOCK leg runs the SKILL.md block only with term_ holders

**Problem:**
No null-holder case goes through the extracted SKILL.md block.

**Fix:**
Deferred: residual 6 in `memory/tasks.d/2026-11-27-rebind-null-holder.md`.

### 11
- status: deferred
- severity: P3
- agent: previous-comments-reviewer
- category: Liveness
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/scripts/orca-rebind.sh
- lines: 400-530
- title: a confirmed null-holder Run is taken with no liveness proof

**Problem:**
A live chat or bot owner is taken on `confirm:` alone (also
silent-failure-hunter). Inherent to a null holder; stated in the header.

**Fix:**
Deferred: residual 4 (a bot liveness read, L103 C4).

### 12
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Measurement
- confidence: 55
- action_class: judgment
- file: plugins/cepa/scripts/orca-rebind.sh
- lines: 119-150
- title: removedWork semantics and null-Run run-use generation are unmeasured

**Problem:**
Both were assumed; neither was measured on a live Orca.

**Fix:**
Header now states both as unmeasured. Measurement deferred: residual 5.

---

**Summary:** 12 findings (0 P1, 2 P2, 10 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
