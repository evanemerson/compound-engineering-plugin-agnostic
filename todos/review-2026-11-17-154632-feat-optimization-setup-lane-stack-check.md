---
date: 2026-11-17T15:46:32
scope: pr:141
branch: feat/optimization/setup-lane-stack-check
agents:
  - adversarial-reviewer
  - python-reviewer
  - architecture-reviewer
  - previous-comments-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
  - comment-analyzer
agents_skipped:
  - agent: learnings-researcher
    reason: "the orchestrator searched docs/solutions itself in /cepa:task Phase 2 (two docs matched) and relayed both learnings in every brief"
  - agent: security-sentinel
    reason: "no cepa.local.md roster; no auth, PHI or secrets; the untrusted-repo-input surface went to adversarial-reviewer"
  - agent: performance-oracle
    reason: "no cepa.local.md roster; no query or hot path; hang and size bounds went to adversarial-reviewer"
  - agent: data-integrity-guardian
    reason: "no models, migrations or transactions in the diff"
  - agent: schema-drift-detector
    reason: "no models, migrations, serializers, forms or admin in the diff"
  - agent: frontend-reviewer
    reason: "no templates, JS/CSS or frontend components in the diff"
  - agent: deployment-verifier
    reason: "nothing deploys from this repo; the only config is a CI job step, reviewed by architecture-reviewer"
  - agent: type-design-analyzer
    reason: "no new types or models"
  - agent: code-simplifier
    reason: "not rostered; cost"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "about 1000 changed lines; a probe that reads untrusted repo files"
  - agent: reliability-reviewer
    dispatched: false
    reason: "no queue, webhook, transaction, lock or external-call code"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist"
agents_failed: []
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier is not rostered in this repo: nothing deploys from it"
  conditions: []
detection_signals:
  matched_docs: 2
  docs_with_detection: 2
  signals_passed: 0
  sources:
    - docs/solutions/logic-errors/a-detector-is-blind-to-content-the-repo-ships-but-never-executes.md
    - docs/solutions/logic-errors/a-heading-name-with-two-senses-needs-a-required-citation-form.md
  backfill_candidates: []
  suspect_bullets: 0
  corpus: present
learnings_research: "skipped — the orchestrator relayed the two matched docs' prevention rules, not their Detection bullets"
summary:
  total: 32
  p1: 2
  p2: 16
  p3: 14
  pending: 0
  ready: 0
  skipped: 0
  applied: 25
  deferred: 7
  completed: 0
---

# Review Findings — 2026-11-17 15:46 (PR #141, head 9ee2dd9)

Residuals go to the PR body and the worker's Handoff block, not to a
`memory/tasks.d/` shard: the task brief names those two sinks, and coord@main is
the punch list's only writer.

## Findings

### 1
- status: applied
- severity: P1
- agent: python-reviewer
- category: Makefile parser
- confidence: 95
- action_class: mechanical
- file: plugins/cepa/scripts/lane_scheme.py
- lines: 133-160
- title: A variable or rule split over continuation lines was dropped

**Problem:**
Continuation lines were joined with a newline and matched by regexes whose `.`
does not cross a newline, so `DC = docker compose \` + `-f a.yml` defined
nothing and `up: a \` + `b` lost the rule.

**Fix:**
Match on a one-line form (`flat`). Case: "compose split over continuation
lines"; mutant `continuation-not-flattened`.

### 2
- status: applied
- severity: P1
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 90
- action_class: corroborated
- file: scripts/check-lane-scheme.sh
- title: 41 of 43 probe mutants survived; a stop token anywhere passed `stop`

**Problem:**
The cases pinned one value per branch. `stop` accepted `exec web stop`; the
`f and` guard, prod/proxy anchors, missing policy, `compose.yaml`, legacy
`docker-compose`, the `start` verb and more had no case (adversarial F11 too).

**Fix:**
`stop` is now the compose verb. The check has 77 cases; the controls pin 74
mutants, every case has an exact killer (`grep -c '^ok CASE'`,
`grep -c '^ok'` on the controls).

### 3
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: False OK
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: A conditional line inside a recipe dropped the rest of the recipe

**Problem:**
`ifeq`/`endif` reset the current rule, so an ungated start after it printed no
row at all (python-reviewer and pr-test-analyzer found it too).

**Fix:**
Conditionals keep the recipe context; both branches count. Case "start inside
a conditional".

### 4
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: False OK
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: A target in two rules kept only the first rule's recipe

**Problem:**
`setdefault` kept the first rule, so `serve: build` then `serve:` + recipe lost
the recipe (python-reviewer too).

**Fix:**
Rules for one target merge as make merges them. Case "start in a second rule
for one target".

### 5
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: False OK
- confidence: 95
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: Refusal, gate and stop words in `echo -e`, `printf` or a trailing comment counted as code

**Problem:**
Only whole-line comments and plain `echo "…"` were blanked (comment-analyzer
too).

**Fix:**
Trailing comments are stripped; `echo` flags and redirects are skipped; a
refusal is judged with `printf` strings blanked. Cases for each.

### 6
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: False skip
- confidence: 85
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: The prod/proxy exemption matched substrings, `-p` names and starts with no `-f`

**Problem:**
`-p reproducer-dev`, `compose.reproduce.yml`, a no-`-f` start and a mixed
dev+prod target read INFO (pr-test-analyzer too).

**Fix:**
Judged per site; `-f` path segments only; `-p` ignored; a site with no `-f` is
a lane site. Cases for each.

### 7
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: False OK
- confidence: 95
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: `Makefile` beat `GNUmakefile`

**Problem:**
The loop kept the last hit; make reads `GNUmakefile` first (four agents).

**Fix:**
First hit in make's order. Case "GNUmakefile wins over Makefile".

### 8
- status: applied
- severity: P2
- agent: architecture-reviewer
- category: Classification
- confidence: 85
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: Compose files outside the root made a Docker repo read as non-Docker

**Problem:**
Every Docker leg was skipped and a false `archive` MISS printed (adversarial F6
too).

**Fix:**
A Makefile that runs `docker compose` also makes a Docker repo; `compose.yaml`
counts. Cases "Docker repo by a Makefile alone", "compose.yaml names a Docker
repo".

### 9
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: False MISS
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/scripts/lane_scheme.py
- title: A YAML merge key voided the file

**Problem:**
The duplicate-key loader built `<<` as a key and failed.

**Fix:**
Merge keys are skipped in the duplicate scan. Case "yaml merge key is valid".

### 10
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: Relay
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/commands/setup.md
- title: Repo strings reached the /cepa:setup agent raw, with no §7 clause

**Problem:**
A key holding a newline forged a row; an imperative key printed verbatim
(python-reviewer too).

**Fix:**
`one()` puts every repo string on one line, strips control characters and cuts
it; check 8 carries the §7 clause (strip, report as corrupted input). Case
"forged row in a key".

### 11
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Unread as absent
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/scripts/lane_scheme.py
- title: A dangling `orca.yaml` symlink read as "no orca.yaml"

**Problem:**
`os.path.exists` is False for a dangling link.

**Fix:**
`lexists`; `read()` then reports it unreadable. Case "orca.yaml a dangling
symlink".

### 12
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Unread as pass
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: `timeout`, `entry` and the closure printed OK or MISS from input never read

**Problem:**
With orca.yaml unparsed or PyYAML missing, `timeout` said OK and the closure
said MISS (comment-analyzer too). An unreadable CLAUDE.md read as empty.

**Fix:**
Those rows are INFO NOT CHECKED when their input was not read. Cases "yaml
duplicate key…", "orca.yaml a FIFO".

### 13
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Controls
- confidence: 80
- action_class: mechanical
- file: scripts/check-lane-scheme-controls.sh
- title: A crashing or BASE-breaking mutant made "every case killed" vacuous

**Problem:**
Every mutant's MISS set fed the coverage control.

**Fix:**
A mutant must parse; only exact mutants (and the pinned BASE rows of a
"contains" one) count; pins live in `scripts/check-lane-scheme-controls.want`.

### 14
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Harness
- confidence: 80
- action_class: mechanical
- file: scripts/check-lane-scheme.sh
- title: The harness hid the probe's stderr and died on a timeout

**Problem:**
A crash showed only `rc=1 MISS []`.

**Fix:**
Cases require empty stderr and print it on failure; a 30 s timeout fails that
case by name.

### 15
- status: applied
- severity: P2
- agent: python-reviewer
- category: False MISS
- confidence: 85
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: `make -j 4 target` read `4` as a target

**Problem:**
`-j`, `-l`, `-I` values were not skipped (adversarial F12 too).

**Fix:**
They are. Case "make -j 4 is not a target".

### 16
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: Hang
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/scripts/check-health.sh
- title: An alias bomb, a FIFO or exponential variables hung /cepa:setup

**Problem:**
No timeout; `str()` of aliased values; `read()` opened anything.

**Fix:**
check-health bounds the probe at 60 s (MISS on timeout); only regular files up
to 2 MiB are read; non-string values are never `str()`-ed; expansion has a
step budget. Cases "orca.yaml a FIFO", "alias bomb in archive".

### 17
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Shape
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/scripts/lane_scheme.py
- title: A non-mapping `scripts`/`worktree` or a non-string entry read as absent

**Problem:**
Wrong shapes became `{}` or stringified.

**Fix:**
`yaml-shape` MISS; non-string `archive` and `sharedDirectories` entries MISS.

### 18
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Crash
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: `2023-02-30`, deep nesting and `$(²)` crashed the probe

**Problem:**
ValueError, RecursionError and `int('²')` escaped.

**Fix:**
Caught as parse errors; `isascii()` before `isdigit()`. Cases for each.

### 19
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: False OK
- confidence: 75
- action_class: mechanical
- file: plugins/cepa/scripts/lane_scheme.py
- title: Any gate mention made a `make` callee read as run under the gate

**Problem:**
`stack-gate.sh --status || true; $(MAKE) serve` passed `serve`.

**Fix:**
Only `<gate> <project> -- make <target>` counts. Case "gate mention outside the
gate's command".

### 20
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: False MISS
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/scripts/lane_scheme.py
- title: An `up` that delegates to a gated target read as ungated

**Problem:**
`up: dev-up` printed "never names the gate".

**Fix:**
`up` follows its prerequisites and `make` calls one level. Case "make up
delegates to a gated target".

### 21
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Unread as absent
- confidence: 65
- action_class: mechanical
- file: plugins/cepa/scripts/lane_scheme.py
- title: A setup script that is not in the repo was dropped silently

**Problem:**
A named, missing `scripts/x.sh` left no trace.

**Fix:**
`INFO lane:setup-missing` for a missing repo shell script (shaped
`dir/name.sh`; container-side `manage.py` is not one). Case "setup names a
script that is missing".

### 22
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Doc accuracy
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- lines: 1-75
- title: The probe header misstated its population and limits

**Problem:**
Compose globs, Makefile order, `.bash`, the setup command, "exit 0 always", the
`--count` residual (previous-comments #2), `--foreground` alone (previous
#3) and ORCA_KEYS' provenance (architecture) were wrong or missing.

**Fix:**
Header rewritten against the code.

### 23
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Restatement
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/commands/setup.md
- title: Check 8 and the probe restated design #20's scope list

**Problem:**
A third copy of the skill's list.

**Fix:**
Both now cite the skill's "The worktree properties, updated for Orca".

### 24
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Coherence
- confidence: 80
- action_class: corroborated
- file: plugins/cepa/commands/setup.md
- title: Step 1, the report line and the double negative did not match check 8

**Problem:**
Step 1 omitted `lane:` lines; the `Lanes:` line had no out-of-scope or
first-gap state; "not a gap in a repo no coord@main runs" was hard to read
(comment-analyzer too).

**Fix:**
All three rewritten.

### 25
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Doc accuracy
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/skills/lane-stack/SKILL.md
- title: Skill status omitted L67; step 2 did not say what the probe covers; bad wraps

**Problem:**
The status paragraph stopped at 1.55.0; step 2's edit left an overlong line
(architecture and comment-analyzer too); check-lane-stack.sh's header wrapped
badly.

**Fix:**
Status names L67 (1.58.0); step 2 names what `lane:` probes and what stays by
hand; wraps fixed.

### 26
- status: deferred
- severity: P2
- agent: architecture-reviewer
- category: Scope ownership
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/lane_scheme.py
- title: The farmtender exclusion is a hardcoded repo name

**Problem:**
The skill owns the scope; the probe matches a directory name, untested.

**Fix:**
Decide between a per-repo opt-out key (cepa.local.md) and reading the skill's
table; add a case either way.

### 27
- status: deferred
- severity: P3
- agent: architecture-reviewer
- category: Restatement
- confidence: 45
- action_class: judgment
- file: plugins/cepa/scripts/lane_scheme.py
- title: Row texts cite "contract item N" / "Setup step N" with no control tying them to the skill

**Problem:**
A renumbered skill leaves stale pointers and no check fails.

**Fix:**
A case that resolves each cited number against the skill, or cite by name.

### 28
- status: deferred
- severity: P3
- agent: adversarial-reviewer
- category: Population
- confidence: 80
- action_class: judgment
- file: plugins/cepa/scripts/lane_scheme.py
- title: `podman compose` and `docker --context x compose` starts are invisible

**Problem:**
No row for them; now a stated limit.

**Fix:**
Extend COMPOSE_RE and the global-flag skip if the fleet ever uses them.

### 29
- status: deferred
- severity: P3
- agent: adversarial-reviewer
- category: Textual verdict
- confidence: 70
- action_class: judgment
- file: plugins/cepa/scripts/lane_scheme.py
- title: A refusal marker anywhere in the recipe passes the start, not only one on its path

**Problem:**
Stated limit; check 8 tells the reader to read the line.

**Fix:**
Require the refusal or gate before the compose call on the same control path.

### 30
- status: deferred
- severity: P3
- agent: previous-comments-reviewer
- category: Contract
- confidence: 55
- action_class: judgment
- file: plugins/cepa/scripts/lane_scheme.py
- title: Contract item 7 accepts `timeout --foreground` without `-k` and `</dev/null`

**Problem:**
The skill asks for both; the probe checks the first half (stated limit).

**Fix:**
Decide whether `-k` is required, then tighten `bare_timeouts`.

### 31
- status: deferred
- severity: P3
- agent: previous-comments-reviewer
- category: Prior finding
- confidence: 70
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- title: First-prompt finding 22 of shard 2026-11-02-feat-integrity-lane-stack-skill.md stays open

**Problem:**
This diff edits step 2 but not that finding (out of L67's scope).

**Fix:**
Leave to its owner.

### 32
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Diagnostics
- confidence: 55
- action_class: mechanical
- file: plugins/cepa/scripts/lane_scheme.py
- title: `repo_name` hides a git failure and old git (`--path-format`) behind the basename

**Problem:**
A farmtender lane dir with another name, or git < 2.31, is not recognized;
fails toward a false MISS.

**Fix:**
Say in the `kind` row which source named the repo.

---

**Summary:** 32 findings (2 P1, 16 P2, 14 P3) — 25 applied, 7 deferred
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
