---
date: 2026-11-27T23:08:58
scope: test/formulation/detection-gate-controls
branch: test/formulation/detection-gate-controls
pr: 152
agents:
  - adversarial-reviewer
  - previous-comments-reviewer
  - pr-test-analyzer
  - silent-failure-hunter
  - comment-analyzer
summary:
  total: 15
  p1: 0
  p2: 1
  p3: 14
  pending: 0
  ready: 0
  skipped: 1
  applied: 12
  deferred: 2
  completed: 0
agents_skipped:
  - agent: security-sentinel
    rule: "no auth, PHI or secrets in diff (test scripts and status notes)"
  - agent: performance-oracle
    rule: "no ORM, queries or hot loops in diff"
  - agent: python-reviewer
    rule: "test harness python inside bash heredocs; covered by silent-failure-hunter and adversarial-reviewer for cost in a worker run"
  - agent: data-integrity-guardian
    rule: "no migrations or data writes in diff"
  - agent: architecture-reviewer
    rule: "no new module boundaries; the change sits inside two existing scripts"
  - agent: schema-drift-detector
    rule: "no models, migrations, serializers, forms or admin in diff"
  - agent: frontend-reviewer
    rule: "no templates/JS/CSS in diff"
  - agent: deployment-verifier
    rule: "no config, dependencies, Docker, env or migration files; test-only, no manifest bump"
  - agent: type-design-analyzer
    rule: "no new types or models"
  - agent: code-simplifier
    rule: "skipped for cost in a worker run"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff is about 370 lines and changes how controls judge a kill"
  - agent: reliability-reviewer
    dispatched: false
    reason: "signal absent: no queue, webhook, transaction or external API code"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; the diff closes findings in three of them"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped: no deploy surface in diff (test scripts and status notes)"
  conditions: []
learnings_research: "skipped — no docs/solutions/ in this checkout (docs/ is gitignored)"
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
  corpus: "not-consulted — learnings-researcher not run; docs/ is gitignored"
---

# Review Findings — 2026-11-27 23:08 (PR #152)

No cepa.local.md in this repo, so the run inferred the stack (bash with
embedded python, test-only). Reviewed head bce5839. No P1. No agent ran
isolated, so the §11b cleanup had no ids. Three agents re-ran the checker and
the controls from a `git archive` copy: every check and every control passed.

## Findings

### 1
- status: applied
- severity: P2
- agent: comment-analyzer
- category: Residuals
- confidence: 80
- action_class: corroborated
- file: memory/tasks.d/2026-11-27-test-formulation-detection-gate-controls.md
- lines: Measured on this branch
- title: the shard stated control and mutant totals with no probe

**Problem:**
The shard said "97/97 controls passed" and "the five new mutants" and listed
every leg by name. None had the command beside it, and the leg list drifts
when a leg is added. previous-comments-reviewer (3) found the same.

**Fix:**
The shard names the probe (`bash scripts/check-orca-detection-controls.sh`)
and how the per-leg driver works, and states no totals or leg list.

### 2
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Reliability
- confidence: 60
- action_class: judgment
- file: scripts/check-orca-detection-controls.sh
- lines: EXACT, mutate()
- title: EXACT turned timing noise in any case into a red control

**Problem:**
Each EXACT mutant needs a full check run that is green in every case but its
killer, including the tight time bounds. On a loaded runner one case can cross
its bound and the control goes red with nothing wrong.

**Fix:**
A MISS whose only complaint is `took Xs, bound Ys` (regex `TIMING`) is not
counted as an extra red. Stated in the header.

### 3
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Error handling
- confidence: 75
- action_class: mechanical
- file: scripts/check-orca-detection.sh
- lines: HOSTILE_DIR
- title: os.makedirs(HOSTILE_DIR) could abort the check with a traceback

**Problem:**
It sat at module level with no `exist_ok` and no try, so a failure skipped
CITES and TITLE-SURFACES with no MISS line.

**Fix:**
`try: os.makedirs(..., exist_ok=True)`; an OSError is a TITLE MISS and stops
the run, like the fixture repos.

### 4
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Error handling
- confidence: 60
- action_class: mechanical
- file: scripts/check-orca-detection.sh
- lines: plant_json
- title: plant_json wrote json.py without closing it

**Problem:**
`open(...).write(...)` relied on garbage collection to flush the file before
the block ran.

**Fix:**
`with open(...) as f: f.write(...)`.

### 5
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Error handling
- confidence: 40
- action_class: mechanical
- file: scripts/check-orca-detection-controls.sh
- lines: run()
- title: a check that crashed after the killer's MISS line counted as a kill

**Problem:**
`run()` returned only MISS lines, so a traceback after the killer's line was
invisible and EXACT passed.

**Fix:**
`run()` adds a `NO-FOOTER:` MISS when the output has no `-- N/M checks passed
--` line. It is never a hit, so every control goes red on a crashed run.

### 6
- status: applied
- severity: P3
- agent: pr-test-analyzer
- category: Testing
- confidence: 70
- action_class: corroborated
- file: scripts/check-orca-detection-controls.sh
- lines: skill-runs-rename, task-launches-named
- title: the two line-hit killer substrings named only the file

**Problem:**
`"/SKILL.md line "` and `"/commands/task.md line "` matched any SET_NAME hit
in that file. silent-failure-hunter (3) found the same.

**Fix:**
The substrings are the mutated phrases, ``Then it runs `/rename`` and
``start the worker with `claude --name tab3@wt` ``, which the checker prints
in its MISS line. No line number, so other edits to the file cannot break
them.

### 7
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comments
- confidence: 85
- action_class: mechanical
- file: scripts/check-orca-detection.sh
- lines: header, TITLE
- title: the header said the title case runs "as FIXTURES does"

**Problem:**
FIXTURES plants json.py in its own case dir, not in a worktree directory.

**Fix:**
Reworded: the title case runs from a directory inside the worktree so
`<repo>` resolves.

### 8
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comments
- confidence: 60
- action_class: mechanical
- file: scripts/check-orca-detection-controls.sh
- lines: header, run time
- title: the controls' run-time figure predated the new mutants

**Problem:**
"About 3.5 minutes on 2026-10-31" no longer described the set.

**Fix:**
The figure is marked as before L52, and the header says pipe-read-to-brace
waits out a 15 s case bound.

### 9
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comments
- confidence: 90
- action_class: mechanical
- file: scripts/check-orca-detection-controls.sh
- lines: header
- title: the spliced header paragraph had an overlong line

**Problem:**
The added EXACT text left a broken wrap. pr-test-analyzer found the same.

**Fix:**
Paragraph re-wrapped.

### 10
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Testing
- confidence: 55
- action_class: judgment
- file: scripts/check-orca-detection-controls.sh
- lines: EXACT
- title: only the L52 mutants are in EXACT

**Problem:**
Older mutants that look unique can pick up a second red case without notice.

**Fix:**
Measure them with a `--legs` mode first, then add each one that is red on its
killer only. Filed in `memory/tasks.d/2026-11-27-test-formulation-detection-gate-controls.md`.

### 11
- status: applied
- severity: P3
- agent: pr-test-analyzer
- category: Testing
- confidence: 50
- action_class: judgment
- file: memory/tasks.d/2026-11-27-test-formulation-detection-gate-controls.md
- lines: Measured on this branch
- title: pipe-read-to-brace is hand-built, so the setsid claim was too broad

**Problem:**
The shard said the setsid case catches something no other case does. A
plainer pipe is also killed by bg-child-holds-stdout.

**Fix:**
The shard says the case is unique only against this hand-built shape.

### 12
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Testing
- confidence: 40
- action_class: judgment
- file: scripts/check-orca-detection.sh
- lines: hostile-json-in-cwd
- title: the §12a json.py case runs only the PATH route

**Problem:**
Both routes share one parse line today; a split would leave the
ORCA_CLI_COMMAND route uncovered.

**Fix:**
Add an `ORCA_CLI_COMMAND` twin if the line is split. Filed in the branch shard.

### 13
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 60
- action_class: mechanical
- file: memory/tasks.d/2026-10-31-fix-integrity-session-names.md
- lines: finding 13 pointer
- title: the session-names pointer to PR #96 finding 15 did not show the json.py half done

**Problem:**
The other two shards note the half; this pointer read as fully open.

**Fix:**
One sentence added to the pointer.

### 14
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 55
- action_class: mechanical
- file: todos/review-2026-10-30-125030.md
- lines: finding 15
- title: finding 15's body did not record that the json.py half landed

**Problem:**
A reader of the todos file alone would re-raise the whole finding.

**Fix:**
A "Partial, 2026-11-27" line in the body; status stays deferred.

### 15
- status: skipped
- severity: P3
- agent: comment-analyzer
- category: Comments
- confidence: 40
- action_class: judgment
- file: memory/tasks.d/2026-10-30-feat-roles-orca-adapter.md
- lines: finding 11 resolved note
- title: "each red only on its case" is implicit for pipe-read-to-brace

**Problem:**
The note relies on EXACT for its claim.

**Fix:**
None needed: EXACT asserts it on every run. The reviewer said so too.

---

**Summary:** 15 findings (0 P1, 1 P2, 14 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
