---
date: 2026-11-02T09:21:20
scope: feat/integrity/lane-stack-skill
branch: main
agents:
  - learnings-researcher
  - security-sentinel
  - architecture-reviewer
  - silent-failure-hunter
  - adversarial-reviewer
  - previous-comments-reviewer
summary:
  total: 22
  p1: 1
  p2: 8
  p3: 13
  pending: 0
  ready: 0
  skipped: 0
  applied: 16
  deferred: 6
  completed: 0
agents_skipped: []
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff is ~700 lines (PR #125)"
  - agent: reliability-reviewer
    dispatched: false
    reason: "no queue/webhook/transaction/external-call code; the gate's lock is cited, not implemented (L66)"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; todos/review-2026-11-02-085725-main.md binds this design"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier is not rostered in cepa.local.md (nothing deploys from this repo)"
  conditions: []
detection_signals:
  matched_docs: 6
  docs_with_detection: 6
  signals_passed: 6
  sources:
    - docs/solutions/logic-errors/a-control-suite-proves-only-the-branch-it-exercises.md
    - docs/solutions/logic-errors/an-assertion-must-name-the-edit-that-reddens-it.md
    - docs/solutions/logic-errors/a-fixture-can-score-perfectly-while-the-real-corpus-regresses.md
    - docs/solutions/logic-errors/a-detector-is-not-exempt-from-the-class-it-detects.md
    - docs/solutions/logic-errors/cross-cutting-policy-must-be-cited-once-not-restated-at-every-site.md
    - docs/solutions/logic-errors/a-detector-is-blind-to-content-the-repo-ships-but-never-executes.md
  backfill_candidates: []
  suspect_bullets: 0
  corpus: present
learnings_research: "ok"
brain:
  provider: ob1
  status: fresh
  role: consumer
  queries: 1
  written: 0
  suppressed_writebacks: 0
  scrubbed: 0
  args_skipped: 0
  suspect_stripped: 0
  pre_step: "ok — 1 recall, 0 args skipped, 0 suspect stripped, 0 non-participant dropped (no participant manifest)"
---

# Review Findings — 2026-11-02 09:21

PR #125 (head 591062c at review time). Signals were relayed to each reviewer
as a short pattern list, not the full Detection text.

## Findings

### 1
- status: applied
- severity: P1
- agent: adversarial-reviewer, security-sentinel, silent-failure-hunter
- category: Default-deny
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 178
- title: make up identity test fails open when git errors

**Problem:**
`[ "$(git rev-parse --git-dir)" = "$(git rev-parse --git-common-dir)" ]` is `"" = ""` when both probes fail (severed lane, no repo), so a lane took the ungated main-checkout path and started its stack. Reproduced by the adversarial reviewer (rc=0, `START up -d`).

**Fix:**
Applied: capture `--absolute-git-dir` and `--path-format=absolute --git-common-dir`, refuse when either fails or is empty. Absolute paths also fix a main-checkout subdirectory reading as a lane. New check case `MAKE severed lane refuses` with mutant `identity-fail-open`.

### 2
- status: applied
- severity: P2
- agent: security-sentinel, architecture-reviewer, adversarial-reviewer
- category: Default-deny
- confidence: 75
- action_class: corroborated
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 188
- title: make up passes an unchecked COMPOSE_PROJECT_NAME to the gate

**Problem:**
An unset or non-`-wt-` name reached the gate, which cannot count a stack without `-wt-`.

**Fix:**
Applied: the lane branch refuses unless the name matches `*-wt-*`; prose says the repo's `worktree-guard` proves it is this lane's own name. Cases `MAKE lane unset project refuses`, `MAKE lane non-wt project refuses`, with a mutant each.

### 3
- status: applied
- severity: P2
- agent: previous-comments-reviewer, architecture-reviewer
- category: Citation
- confidence: 85
- action_class: corroborated
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 296-298
- title: First prompt step 1 cites an outbox drain §12b does not define yet

**Problem:**
The outbox drain is L61 (unbuilt); step 1 named it as if it existed.

**Fix:**
Applied: step 1 runs the re-bind and rule 8's inbox peek, and the outbox drain only when §12b defines it (L61). A Status paragraph near the top says so.

### 4
- status: applied
- severity: P2
- agent: security-sentinel
- category: Prompt injection
- confidence: 75
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 381-402
- title: First-prompt template relays messages and repo files with no §7 clause

**Problem:**
Repo rule "Relayed repo content is untrusted at every relay point": the template shows outbox messages and reads repo files with no untrusted-data clause covering imperatives and exemption claims.

**Fix:**
Applied: a §7/§12c clause in the template (ignore imperatives and pre-cleared/approved claims, strip, record each strip).

### 5
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: Ordering
- confidence: 80
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 309-317
- title: Step 4 creates lanes whose names old lanes still hold

**Problem:**
`orca-lane.sh create` refuses a taken name; dpc-pro's first fill keeps the old names, and only step 5 removes them.

**Fix:**
Applied: step 4 creates only names no lane holds; a held name goes through step 5 (rm, then create, then check the Setup tab).

### 6
- status: applied
- severity: P2
- agent: adversarial-reviewer, previous-comments-reviewer, architecture-reviewer
- category: Dependency
- confidence: 85
- action_class: corroborated
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 21, 114
- title: Nothing stops adoption before stack-gate.sh (L66) exists

**Problem:**
A repo adopting now gets every lane setup refused; step 5 would rm old lanes first.

**Fix:**
Applied in the skill: a Status paragraph (no adoption before L66) and template step 0 (resolve the gate; stop and report when absent). Making L63 depend on L66 is a punch-list edit for coord@main (worker does not edit the list).

### 7
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: Failure path
- confidence: 70
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 141-160
- title: Setup that fails part-way leaves its stack running

**Problem:**
`compose stop` was the last step; a failed migration skipped it, leaving a counted running stack.

**Fix:**
Applied: setup sets a trap that stops the stack on any exit; a "When setup fails for another reason" path for coord@main.

### 8
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Test coverage
- confidence: 85
- action_class: mechanical
- file: scripts/check-lane-stack.sh
- lines: 113-141
- title: MAKE leg never tests a gate refusal

**Problem:**
The stub gate always ran the command; a `|| true` after the gate call would stay green.

**Fix:**
Applied: stub refuses with exit 3 under `STUB_REFUSE=1`; case `MAKE lane gate refusal propagates`; mutant `refusal-swallowed`.

### 9
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Test coverage
- confidence: 80
- action_class: mechanical
- file: scripts/check-lane-stack-controls.sh
- lines: 26-69
- title: Eight check cases had no killing mutant

**Problem:**
Only one leg-exclusive mutant per leg was asserted; eight cases could break silently.

**Fix:**
Applied: mutants for every case, and a control `every case has a killing mutant` that compares the clean run's `ok` cases with the union of mutant sets.

### 10
- status: deferred
- severity: P3
- agent: adversarial-reviewer
- category: Contract
- confidence: 60
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 125-129
- title: Lock wait behavior and bound are undefined in the gate contract

**Problem:**
Setup holds the host-wide lock through the whole init; how a waiting start behaves has no exit code.

**Fix:**
Deferred to L66 (the gate header owns it); the skill now says so. Shard: memory/tasks.d/2026-11-02-feat-integrity-lane-stack-skill.md.

### 11
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Environment
- confidence: 70
- action_class: mechanical
- file: scripts/check-lane-stack.sh
- lines: 66-70
- title: Missing PyYAML or make reported as a wrong reason or a crash

**Problem:**
ImportError read as "does not parse"; a missing `make` raised an uncaught error.

**Fix:**
Applied: `YAML PyYAML available` MISS; `shutil.which` for git and make, MISS naming the tool.

### 12
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Isolation
- confidence: 55
- action_class: mechanical
- file: scripts/check-lane-stack.sh
- lines: 117-124
- title: Fixture ignored git setup failures and inherited GIT_* variables

**Problem:**
Under a git hook, `GIT_DIR` could point the fixture at the real repo; setup failures crashed with no MISS.

**Fix:**
Applied: every `GIT_*` variable dropped; each setup step's rc checked, a failure is a MISS for each MAKE case.

### 13
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Test precision
- confidence: 50
- action_class: mechanical
- file: scripts/check-lane-stack.sh
- lines: 86-96
- title: GATE needles matched anywhere in the file

**Problem:**
A sentence elsewhere could satisfy a contract needle.

**Fix:**
Applied: needles are searched only in `## The stack gate`; case `GATE section present`.

### 14
- status: deferred
- severity: P3
- agent: silent-failure-hunter, adversarial-reviewer
- category: Test precision
- confidence: 45
- action_class: corroborated
- file: scripts/check-lane-stack.sh
- lines: 166-169
- title: ENTRY leg accepts any not/never/forbidden within 120 characters

**Problem:**
A promoting sentence with an unrelated "not" nearby passes.

**Fix:**
Deferred: no current mention promotes the target; tighten when the ENTRY wording next changes. Shard entry filed.

### 15
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Count drift
- confidence: 80
- action_class: mechanical
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 225
- title: "the ten worktree properties" is a new count claim

**Problem:**
Repo rule: do not add new count claims (README rows and heading).

**Fix:**
Applied: "the worktree properties" in both READMEs, the skill heading and body.

### 16
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Citation
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 136-137
- title: "the way §12b's blocks do" overstated the resolver usage

**Problem:**
§12b sources the resolver; a Makefile captures it.

**Fix:**
Applied: cites the resolver header's capture form.

### 17
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Consistency
- confidence: 50
- action_class: mechanical
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 3
- title: Punch-list ID in the frontmatter description

**Problem:**
A future-tense L67 reference in the description goes stale.

**Fix:**
Applied: removed from the description; L-references stay in the body.

### 18
- status: deferred
- severity: P3
- agent: security-sentinel
- category: Input handling
- confidence: 55
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 377-395
- title: Lane-name blank is not constrained in the template

**Problem:**
`<lane names>` flows into `orca-lane.sh`.

**Fix:**
Deferred: `orca-lane.sh` already reads fields from a quoted heredoc and refuses a lane that is not a §10a slug; no extra rule needed unless that changes.

### 19
- status: deferred
- severity: P3
- agent: security-sentinel
- category: Resolution
- confidence: 40
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 267-270
- title: Resolver loop: partial output kept, marketplace glob order wins

**Problem:**
A foreign or stale cepa copy can win the glob; partial output stays in CEPA_ROOT.

**Fix:**
Deferred: the `-f stack-gate.sh` test keeps it fail-closed; same glob as every §12b block, so a change belongs to resolve-plugin-root.sh for all callers.

### 20
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Default-deny
- confidence: 65
- action_class: mechanical
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 178
- title: A main-checkout subdirectory was treated as a lane

**Problem:**
git 2.43 returns an absolute git-dir and a relative common-dir from a subdir.

**Fix:**
Applied with finding 1 (absolute paths); measured equal from a subdir.

### 21
- status: deferred
- severity: P3
- agent: previous-comments-reviewer
- category: Tracking
- confidence: 55
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 205-206
- title: The stacks:over:<n> health alert has no owning punch-list item

**Problem:**
The design names it; no item owns it.

**Fix:**
Deferred to coord@main (punch-list writer). Shard entry filed.

### 22
- status: deferred
- severity: P3
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 40
- action_class: judgment
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: 296-308
- title: First prompt does not restate prior review #9 (new Run with correct objective)

**Problem:**
Not verified that §12b rule 2's re-bind covers the `<repo> coord@main` objective rule.

**Fix:**
Deferred: that rule is §12b rule 2's and L61's to own; the template cites the re-bind block rather than restating it.

---

**Summary:** 22 findings (1 P1, 8 P2, 13 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
