---
date: 2026-11-04T07:15:46
scope: pr:134
branch: fix/matrix/orca-lane-create-timeout-rm-defects
agents:
  - security-sentinel
  - architecture-reviewer
  - silent-failure-hunter
  - adversarial-reviewer
  - reliability-reviewer
  - previous-comments-reviewer
agents_skipped: []
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff of about 990 changed lines"
  - agent: reliability-reviewer
    dispatched: true
    signal: "timeouts, retries and external calls in orca-lane.sh"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist"
agents_failed: []
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier is not rostered in this repo: nothing deploys from it"
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
  corpus: absent
learnings_research: "skipped — docs/solutions/ is absent in this checkout (docs/ is gitignored); the worker's brief says no helpers unless the task asks"
summary:
  total: 14
  p1: 0
  p2: 3
  p3: 11
  pending: 0
  ready: 0
  skipped: 0
  applied: 11
  deferred: 3
  completed: 0
---

# Review Findings — PR #134

## Findings

### 1
status: applied
severity: P2
agent: adversarial-reviewer, reliability-reviewer
category: Reliability
confidence: 75
action_class: corroborated
file: plugins/cepa/scripts/orca-lane.sh
title: rm treats no-result codes as a definite failure

**Problem:** `runtime_timeout` and `worktree_removal_in_progress` reached the failure arm while Orca was still deleting, and the new item 4 text said to restore files under a running removal.

**Fix:** Those codes, the connection-loss codes and a no-code failure go to the absence proof, as a kill does. The retry line now says to wait until Orca has stopped deleting. Cases cover a timeout, a removal in progress, and a timeout whose removal finished.

### 2
status: applied
severity: P2
agent: silent-failure-hunter
category: Silent failure
confidence: 90
action_class: mechanical
file: plugins/cepa/scripts/orca-lane.sh
title: An unreadable cepa.local.md fell back to the default branch

**Problem:** `[ -f ]` plus a failed `done <file` read as no override, against the stated no-fallback rule. A dangling link and a directory were skipped too.

**Fix:** The file is read once with its type tested first (`$(<dir)` exits 0, which a new case caught); unreadable sets cepa_ln_trunk_bad, and rm refuses.

### 3
status: applied
severity: P2
agent: architecture-reviewer
category: CI
confidence: 75
action_class: mechanical
file: .github/workflows/residual-integrity.yml
title: Controls shards near the 10-minute job bound

**Problem:** Measured on run 41832679426: 4 shards took 7m42s to 9m58s with 107 mutants, and this round adds more.

**Fix:** The controls run as 8 shards; the workflow, the plants and the cost history moved together.

### 4
status: applied
severity: P3
agent: adversarial-reviewer
category: Reliability
confidence: 80
action_class: mechanical
file: plugins/cepa/scripts/orca-lane.sh
title: create read two more no-result codes as a definite failure

**Problem:** `runtime_unavailable` and `invalid_runtime_response` mean the request was sent and the answer was lost, so a re-run could make `<lane>-2`.

**Fix:** Both go to step 2b. The header says so.

### 5
status: applied
severity: P3
agent: adversarial-reviewer
category: Correctness
confidence: 85
action_class: mechanical
file: plugins/cepa/scripts/orca-lane.sh
title: An unusable override was not unknown in the reflog step

**Problem:** The comment said no fallback, but the helper then used the default alone, and the Ending named the wrong remedy.

**Fix:** rm refuses right after the trunk read, naming the override.

### 6
status: applied
severity: P3
agent: previous-comments-reviewer
category: Correctness
confidence: 80
action_class: mechanical
file: plugins/cepa/scripts/orca-lane.sh
title: A literal <base> reached copy-paste commands

**Problem:** With no resolved trunk, the Ending lines printed `git checkout --detach origin/<base>`.

**Fix:** No command is printed then: the empty-reflog line names the step in words, and the exit-2 hint is skipped.

### 7
status: applied
severity: P3
agent: reliability-reviewer, previous-comments-reviewer
category: Correctness
confidence: 70
action_class: corroborated
file: plugins/cepa/scripts/orca-lane.sh
title: No JSON at exit 0 blamed the 180 s bound

**Problem:** Polling is right there, but the reason text was wrong.

**Fix:** A `0:` arm gives its own reason and still polls.

### 8
status: applied
severity: P3
agent: previous-comments-reviewer
category: Correctness
confidence: 60
action_class: mechanical
file: plugins/cepa/scripts/orca-lane.sh
title: A poll with no complete read said the list shows no lane

**Problem:** Zero complete reads prove nothing about the list.

**Fix:** The text then says the list could not be read.

### 9
status: applied
severity: P3
agent: security-sentinel
category: Relay
confidence: 70
action_class: mechanical
file: plugins/cepa/scripts/orca-lane.sh
title: Tracked file names reached the coordinator's line raw

**Problem:** Repo authors control those names (repo rule: relayed content is stripped).

**Fix:** Names are stripped to `[A-Za-z0-9._/-]` and capped; a case plants a name with spaces and a semicolon.

### 10
status: applied
severity: P3
agent: architecture-reviewer
category: Docs
confidence: 85
action_class: mechanical
file: plugins/cepa/scripts/orca-lane.sh
title: The trunk comment misnumbered §8's rungs

**Problem:** It called origin/HEAD and ls-remote rungs 2-3 and did not say `gh` is dropped.

**Fix:** The comment states the deviation.

### 11
status: applied
severity: P3
agent: architecture-reviewer
category: Docs
confidence: 70
action_class: mechanical
file: plugins/cepa/scripts/orca-lane-reflog.sh
title: The helper usage line claimed §8

**Problem:** The caller resolves a variant of §8.

**Fix:** The usage line cites `cepa_ln_trunk_read`.

### 12
status: deferred
severity: P3
agent: reliability-reviewer
category: Reliability
confidence: 50
action_class: judgment
file: plugins/cepa/scripts/orca-lane.sh
title: Step 2b's park can meet a later Orca step

**Problem:** A settled row does not prove Orca has finished. The park then fails closed, and a re-run resumes. The adversarial agent read that the metadata is written after the worktree exists.

**Fix:** Recorded in the header. Whether to add a settled read before parking is left open.

### 13
status: deferred
severity: P3
agent: reliability-reviewer
category: Reliability
confidence: 60
action_class: judgment
file: plugins/cepa/scripts/orca-lane.sh
title: Unbounded local git work sits outside the worst-case sums

**Problem:** rm has about 25 s of margin under the 10-minute tool timeout; `status --ignored` on a large lane is not bounded.

**Fix:** Bounding it changes refusals on big lanes, so it is left for a decision.

### 14
status: deferred
severity: P3
agent: silent-failure-hunter
category: Silent failure
confidence: 60
action_class: mechanical
file: plugins/cepa/scripts/orca-lane-reflog.sh
title: grep exit 2 reads as no match in the need filter

**Problem:** Pre-existing, not in this diff: an empty `need` takes the landed branch. In practice every lost reflog commit matches.

**Fix:** Out of this brief's scope; filed as a residual.

---

**Summary:** 14 findings (0 P1, 3 P2, 11 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
