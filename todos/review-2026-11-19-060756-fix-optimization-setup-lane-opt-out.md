---
date: 2026-11-19T06:07:56
scope: pr:145
branch: fix/optimization/setup-lane-opt-out
agents:
  - adversarial-reviewer
  - python-reviewer
  - architecture-reviewer
  - previous-comments-reviewer
  - pr-test-analyzer
  - comment-analyzer
agents_skipped:
  - agent: learnings-researcher
    reason: "docs/ is gitignored and docs/solutions is absent in this worktree: no corpus to search"
  - agent: security-sentinel
    reason: "no cepa.local.md roster; no auth, PHI or secrets; the untrusted-input surface went to adversarial-reviewer and architecture-reviewer"
  - agent: performance-oracle
    reason: "no cepa.local.md roster; one bounded file read (MAX_BYTES)"
  - agent: data-integrity-guardian
    reason: "no models, migrations or transactions in the diff"
  - agent: schema-drift-detector
    reason: "no models, migrations, serializers, forms or admin in the diff"
  - agent: frontend-reviewer
    reason: "no templates, JS/CSS or frontend components in the diff"
  - agent: deployment-verifier
    reason: "nothing deploys from this repo; no config, dependency or CI change"
  - agent: type-design-analyzer
    reason: "no new types or models"
  - agent: silent-failure-hunter
    reason: "not rostered; the not-read paths went to adversarial-reviewer"
  - agent: code-simplifier
    reason: "not rostered; cost"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "340-line diff; a probe that reads untrusted repo files"
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
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
  corpus: absent
learnings_research: "skipped — docs/solutions is absent in this worktree (docs/ is gitignored)"
summary:
  total: 17
  p1: 0
  p2: 5
  p3: 12
  pending: 0
  ready: 0
  skipped: 0
  applied: 17
  deferred: 0
  completed: 0
---

# Review Findings — 2026-11-19 06:07 (PR #145, head 304c84f)

No `cepa.local.md` in this repo: the roster was inferred (headless). Residuals
go to the PR body and the worker's Handoff block; coord@main is the punch
list's only writer. Corrupted-input findings: 0.

## Findings

### 1
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: False opt-out
- confidence: 95
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: An example `lanes: none` (nested fence, info-string fence line, HTML comment, indented code) opted the repo out

**Problem:**
The fence tracker matched only three characters and closed on any marker line, and comments and indented code were read. A repo with an example key inside a four-backtick fence, a commented-out key, or a 4-space code line was skipped. Reproduced on temp repos; python-reviewer and pr-test-analyzer found the fence half too.

**Fix:**
Fences follow CommonMark (same character, at least the opening length, no info string on the close); `<!-- -->` spans are skipped; the key may be indented at most 3 spaces. Cases for each shape; mutants fence-short-closes, fence-info-closes, fence-char-ignored, comment-multiline-read, comment-inline-kept, optout-indented-code-read.

### 2
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: False opt-out
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: `lanes: none` beside an `orca.yaml` skipped the check and setup.md dropped the conflict

**Problem:**
A repo that later adopts lanes keeps a stale key; the probe noted the orca.yaml in row text and returned before any MISS. The suffix was also never asserted (pr-test-analyzer).

**Fix:**
With an orca.yaml the opt-out is not honored: an `INFO lane:opt-out` row says so and the repo is checked. Case "lanes: none with an orca.yaml is checked"; mutant optout-beats-orca-yaml. CONFIGURATION.md says the key is for a repo with no orca.yaml.

### 3
- status: applied
- severity: P2
- agent: architecture-reviewer
- category: Untrusted relay
- confidence: 45
- action_class: judgment
- file: plugins/cepa/commands/setup.md
- title: setup.md told the model to find the honored opt-out by row text, and rows carry repo text

**Problem:**
`INFO lane:kind saying lanes: none` was a text match; other rows quote compose file names and the key value, so crafted text could read as an exemption.

**Fix:**
The honored opt-out is its own row key, `INFO lane:opted-out`, with no repo text. setup.md check 8 matches the key and says no other row opts a repo out.

### 4
- status: applied
- severity: P2
- agent: architecture-reviewer
- category: Cross-repo claim
- confidence: 80
- action_class: corroborated
- file: plugins/cepa/skills/lane-stack/SKILL.md
- title: The skill row stated that farmtender's cepa.local.md sets `lanes: none`

**Problem:**
Nothing in this repo makes that true; previous-comments-reviewer found the same. Until farmtender adds the key, its `/cepa:setup` runs the lane check.

**Fix:**
The row now states the rule (farmtender opts out with the `lanes` key, CONFIGURATION.md). The farmtender hand-off is in the PR body for coord@main to relay.

### 5
- status: applied
- severity: P2
- agent: comment-analyzer
- category: Doc accuracy
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/scripts/lane_scheme.py
- title: The header claimed an INFO row for a key inside a fenced block; there was none

**Problem:**
The fenced case asserts no row, which contradicted the NON-POPULATION bullet.

**Fix:**
The header bullet is rewritten: it owns the read rules and says which shapes get an `INFO lane:opt-out` row; fenced and commented keys are examples and get none.

### 6
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Section scope
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: An H1 heading did not end `## Conventions`

**Problem:**
Only `##` changed the section, so a key under `# Appendix` after Conventions opted out (python-reviewer found it too).

**Fix:**
`#` and `##` headings set the section; `###` stays inside. Cases for both; mutants optout-h1-ignored, optout-h3-ends-section.

### 7
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Duplicate key
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: Two `lanes:` keys in Conventions: first wins, silently, by line order

**Problem:**
The second key went to `misplaced`, printed only when no value was set, with a wrong "outside" message (python-reviewer).

**Fix:**
Two or more keys: none is read, an INFO row names the lines, the repo is checked. Case "two keys are checked"; mutant optout-two-keys-read.

### 8
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Silent skip
- confidence: 85
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: Some `lanes:` lines were ignored with no row (numbered list, indented, unclosed fence or comment)

**Problem:**
The repo was checked, the safe direction, but the docs promise a row for a key seen and not read (python-reviewer: unclosed fence).

**Fix:**
A loose `lanes:` match outside fences gets a row; an unclosed fence or comment gets a row. Cases and mutants optout-loose-silent, fence-unclosed-silent, comment-unclosed-silent.

### 9
- status: applied
- severity: P3
- agent: python-reviewer
- category: Doc accuracy
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: `none` matched case-insensitively, undocumented and unpinned

**Problem:**
CONFIGURATION.md said `none` is the only value read; `NONE` opted out; a mutant removing `.lower()` survived (pr-test-analyzer, comment-analyzer).

**Fix:**
Kept, and documented in the header (any case; quotes, backticks and a trailing comment stripped). Case "no marker, backticks, comment, upper case"; mutant optout-case-sensitive.

### 10
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Restatement
- confidence: 60
- action_class: judgment
- file: CONFIGURATION.md
- title: CONFIGURATION.md and the probe header both stated the read rules

**Problem:**
Two copies drift. comment-analyzer asked for more detail in CONFIGURATION.md, which would widen the copy.

**Fix:**
The probe header owns the rules; CONFIGURATION.md says how to set the key and cites the header.

### 11
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Contract
- confidence: 75
- action_class: corroborated
- file: plugins/cepa/skills/lane-stack/SKILL.md
- title: L91: the skill still said "add `-k`" and the probe cited stack-gate.sh beyond what it supports

**Problem:**
stack-gate.sh's timeout calls all use `-k 2`, so they support dropping `</dev/null` only; the probe note also restated the skill (architecture-reviewer).

**Fix:**
Item 7's Why now calls `-k` and `</dev/null` advised hardening that `/cepa:setup` does not check (L91). The probe note cites the skill and no longer restates it or stack-gate.sh.

### 12
- status: applied
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 85
- action_class: mechanical
- file: scripts/check-lane-scheme-controls.sh
- title: The misplaced-key row had no mutant of its own

**Problem:**
The only case reaching it was killed by a different route.

**Fix:**
The case asserts the INFO row; optout-any-section and optout-h1-ignored kill it through the section rule. Every new mutant is pinned to the case it targets.

### 13
- status: applied
- severity: P3
- agent: pr-test-analyzer
- category: Test coupling
- confidence: 75
- action_class: judgment
- file: scripts/check-lane-scheme-controls.want
- title: Opt-out cases detected "checked" through an unrelated mutant's fixture

**Problem:**
They used a list orca.yaml, so not-a-mapping-accepted killed them.

**Fix:**
Opt-out cases delete orca.yaml and detect "checked" by the orca-yaml row; not-a-mapping-accepted is back to its own case. no-orca-yaml-checked now also kills the checked opt-out cases, which is the signal they use; a comment says so.

### 14
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Restatement
- confidence: 65
- action_class: corroborated
- file: plugins/cepa/skills/lane-stack/SKILL.md
- title: The skill row restated the opt-out mechanism

**Problem:**
CONFIGURATION.md owns it.

**Fix:**
The row names the key and cites CONFIGURATION.md.

### 15
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Doc accuracy
- confidence: 70
- action_class: mechanical
- file: scripts/check-lane-scheme.sh
- title: STATED LIMITS kept a git-common-dir clause the probe no longer needs

**Problem:**
`repo_name` is gone, so the clause described a removed limit; the line also broke mid-sentence.

**Fix:**
Reworded (the probe matches no repo name) and rewrapped.

### 16
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Formatting
- confidence: 85
- action_class: corroborated
- file: plugins/cepa/scripts/lane_scheme.py
- title: POPULATION paragraph had an over-long line

**Problem:**
Reported by four agents.

**Fix:**
Rewrapped.

### 17
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Tracking
- confidence: 90
- action_class: mechanical
- file: todos/review-2026-11-17-154632-feat-optimization-setup-lane-stack-check.md
- title: Findings #26, #30 and #32 of the PR #141 review stayed deferred

**Problem:**
This PR resolves all three (#32: `repo_name` is deleted).

**Fix:**
Set to applied with a Resolution line; counters 28 applied, 4 deferred. L90 and L91 in the punch list are coord@main's to close.

---

**Summary:** 17 findings (0 P1, 5 P2, 12 P3) — 17 applied, 0 deferred
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
