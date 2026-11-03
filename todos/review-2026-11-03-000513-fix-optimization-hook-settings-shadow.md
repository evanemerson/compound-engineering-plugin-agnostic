---
date: 2026-11-03T00:05:13
scope: PR #133 (fix/optimization/hook-settings-shadow)
branch: fix/optimization/hook-settings-shadow
agents:
  - learnings-researcher
  - security-sentinel
  - architecture-reviewer
  - silent-failure-hunter
  - adversarial-reviewer
  - previous-comments-reviewer
agents_skipped: []
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff is 345 changed lines (over ~300)"
  - agent: reliability-reviewer
    dispatched: false
    reason: "no queue/webhook/transaction/scheduled-job code; the Orca CLI calls are bounded reads already covered by the READS leg"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exists; deferred findings 14 and 15 touch orca-lane.sh"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier is not on this repo's Active roster; plugin content ships by merge plus the plugin refresh"
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
brain:
  status: skipped
  reason: "worker review; the brain pre-flight was not run, so no recall"
summary:
  total: 16
  p1: 0
  p2: 3
  p3: 13
  pending: 0
  ready: 0
  skipped: 4
  applied: 12
  deferred: 0
  completed: 0
---

# Review Findings — 2026-11-03 00:05

Reviewed head `bc57163`. Fixes applied on the same branch in the follow-up commit.

## Findings

### 1
- status: applied
- severity: P2
- agent: security-sentinel, silent-failure-hunter, adversarial-reviewer
- category: Default-deny
- confidence: 85
- action_class: corroborated
- file: plugins/cepa/scripts/orca-lane.sh
- lines: ymlscript
- title: orca.yaml spellings the reader skips read as "no script"

**Problem:**
A top-level line that was not a bare `scripts:` only ended the `scripts` block. A BOM, a quoted `"scripts":` key, or an indented whole document gave `y == ""`. Under explicit `local-only` with an empty local setup, the check printed `ok`, but Orca runs no setup. All three reviewers reproduced it.

**Fix:**
Every non-comment top-level line must be a plain `key:`; anything else exits 1. A content line before any top-level key exits 1. Cases added: BOM, quoted key, indented document.

### 2
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/scripts/orca-lane.sh
- lines: cepa_ln_hookat
- title: a failed `git cat-file -e` read as "no orca.yaml"

**Problem:**
`cat-file -e` exits 1 for a missing path and for a read failure alike, so a read failure looked like an absent orca.yaml.

**Fix:**
`cepa_ln_hookat` reads absence positively: `git ls-tree` must succeed, and an entry must be a `100644 blob`. Anything else is UNKNOWN.

### 3
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Parity
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/scripts/orca-lane.sh
- lines: hook mode
- title: Python strip() and JS trim() strip different characters

**Problem:**
A local script of `\x85` became empty under Python `strip()`, so the check read "unset policy, no local script" and printed `ok`. Orca's JS `trim()` keeps it, so Orca reads it as `local-only` and runs it.

**Fix:**
Strip with the JS whitespace set (`JS_WS`). Case added.

### 4
- status: applied
- severity: P3
- agent: security-sentinel
- category: Parity
- confidence: 55
- action_class: mechanical
- file: plugins/cepa/scripts/orca-lane.sh
- lines: ymlscript
- title: YAML null/bool/number plain scalars compared as strings

**Problem:**
`setup: null` or `~` means no script in YAML, but the reader treated it as the text `null`.

**Fix:**
Those plain values exit 1 (UNKNOWN). Case added for `null`.

### 5
- status: applied
- severity: P3
- agent: security-sentinel
- category: Robustness
- confidence: 40
- action_class: mechanical
- file: plugins/cepa/scripts/orca-lane.sh
- lines: ymlscript
- title: an unbounded line can make the comment regex slow

**Problem:**
`re.sub(r"\s+#.*$", …)` is quadratic on a very long whitespace run.

**Fix:**
A line over 4096 characters exits 1.

### 6
- status: applied
- severity: P3
- agent: previous-comments-reviewer, adversarial-reviewer
- category: Race
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/scripts/orca-lane.sh
- lines: create steps 0, 4, 6
- title: a base that moves during create can carry a shadow past the check, and resume skipped it

**Problem:**
Moving the park-step fetch to the top widened finding #28's window. A commit on origin between our fetch and Orca's fetch could change `scripts.setup` unseen. The run then failed with a misleading "commits not on origin" message, and the resume (which skipped the check) reported success.

**Fix:**
The park step's tolerant re-fetch is restored. New step 6 re-checks the hook against the parked lane's own `HEAD:orca.yaml`, on a fresh create and on a resume, and fails with exit 3 on a shadow. The stub's `freshbase` mode now moves origin during the create. Cases added: stale local ref, resume onto a shadow.

### 7
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Race
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/scripts/orca-lane.sh
- lines: create step 0
- title: the new fetch sat between the worktree-list read and worktree create

**Problem:**
A fetch of up to 60 s between the taken-name checks and `worktree create` widened deferred finding 15's window.

**Fix:**
Step 0 now runs before the lists are read.

### 8
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Messaging
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/scripts/orca-lane.sh
- lines: create step 0
- title: a mistyped base got network advice

**Problem:**
A fetch of a branch origin lacks failed with "check the network".

**Fix:**
On a fetch failure, `git ls-remote --exit-code` (10 s bound) tells "origin has no branch <base>" from a network fault. Case added.

### 9
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Test coverage
- confidence: 65
- action_class: mechanical
- file: scripts/check-orca-lane.sh
- lines: HOOKS leg
- title: no case for a failed step-0 fetch or a base moved between fetches

**Problem:**
The new refusal on a failed fetch, and the park step after origin moved again, had no case.

**Fix:**
Cases added: "a failed fetch refuses", "a base origin lacks refuses", and freshbase now moves origin during the create. The two fetch mutants (`create-no-step0-fetch`, `create-no-base-fetch`) each have their own kill set.

### 10
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Contract
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: §12b rule 2
- title: rule 2 does not say create and rm can refuse on a shadow

**Problem:**
"Orca's setup is the setup" read as if `create` always runs orca.yaml's setup.

**Fix:**
One sentence cites `orca-lane.sh` H1 for the refusal.

### 11
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Cite, don't restate
- confidence: 65
- action_class: mechanical
- file: plugins/cepa/skills/lane-stack/SKILL.md
- lines: contract item 5; first prompt step 2
- title: the skill restated parts of H1

**Problem:**
Item 5 repeated the policy mechanism, the refusal, the CLI command and the no-setter fact, all of which H1 owns.

**Fix:**
Item 5 names the rule and cites H1. Step 2 checks contract item 5 with `repo show` as H1 says.

### 12
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Documentation
- confidence: 55
- action_class: mechanical
- file: plugins/cepa/scripts/orca-lane.sh
- lines: header, create step 1
- title: a resume now needs the network, undocumented

**Problem:**
Step 0 runs before the resume branch, so an offline resume refuses.

**Fix:**
The header now says a resume still runs step 0.

### 13
- status: skipped
- severity: P2
- agent: silent-failure-hunter
- category: Default-deny
- confidence: 40
- action_class: judgment
- file: plugins/cepa/scripts/orca-lane.sh
- lines: hook mode
- title: a repo row without hookSettings refuses every create and rm

**Problem:**
The `hook` mode exits 1 when `hookSettings` or its `scripts` map is absent.

**Fix:**
No change. All 16 rows of `orca-ide repo list --json` read on 2026-11-03 carry `hookSettings.scripts`; the header now states that measurement. Defaulting an absent field would turn an unknown shape into a pass.

### 14
- status: skipped
- severity: P3
- agent: silent-failure-hunter
- category: Parity
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/orca-lane.sh
- lines: ymlscript
- title: YAML that Orca rejects as a whole is accepted

**Problem:**
`setup: - x` reads as a value; Orca would void the file.

**Fix:**
No change: a stated limit. The check only compares under `local-only` or `run-both`, where Orca runs the local script whatever orca.yaml holds, and refuses whenever the two differ.

### 15
- status: skipped
- severity: P3
- agent: previous-comments-reviewer
- category: Test coverage
- confidence: 50
- action_class: judgment
- file: scripts/check-orca-lane.sh
- lines: RM leg
- title: deferred finding 14 (rule-4 case) not folded in

**Problem:**
Opportunity only: the RM area is adjacent.

**Fix:**
No change. It stays deferred and tracked in `todos/review-2026-11-01-202639-fix-integrity-lane-followups.md`; out of this item's scope.

### 16
- status: skipped
- severity: P3
- agent: previous-comments-reviewer
- category: Tracking
- confidence: 60
- action_class: judgment
- file: memory/tasks.d/2026-10-02-punch-list.md
- lines: L76
- title: L76 still reads pending

**Problem:**
The diff does not update L76.

**Fix:**
No change. Only coord@main writes the punch list; the Handoff block reports the result.

---

**Summary:** 16 findings (0 P1, 3 P2, 13 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
