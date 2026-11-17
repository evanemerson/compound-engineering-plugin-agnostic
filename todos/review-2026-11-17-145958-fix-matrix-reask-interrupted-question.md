---
date: 2026-11-17T14:59:58
scope: PR #140 (fix/matrix/reask-interrupted-question @ deb972e)
branch: fix/matrix/reask-interrupted-question
agents:
  - architecture-reviewer
  - python-reviewer
  - previous-comments-reviewer
summary:
  total: 11
  p1: 0
  p2: 2
  p3: 9
  pending: 0
  ready: 0
  skipped: 0
  applied: 10
  deferred: 1
  completed: 0
agents_skipped:
  - agent: security-sentinel
    rule: "no auth/PHI/payment surface; markdown rule text and a text checker"
  - agent: performance-oracle
    rule: "no runtime code path; checker runs in seconds"
  - agent: data-integrity-guardian
    rule: "no migrations, models or stored data"
  - agent: schema-drift-detector
    rule: "no models, migrations, serializers, forms, or admin"
  - agent: frontend-reviewer
    rule: "no templates/JS/CSS in diff"
  - agent: deployment-verifier
    rule: "no config, deps, Docker, env, migrations, or service contracts"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: false
    reason: "diff under 300 changed lines; no risky paths"
  - agent: reliability-reviewer
    dispatched: false
    reason: "no queue/webhook/transaction/external-call code"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist (124 files)"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped: plugin text change, no deploy surface"
  conditions: []
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
  corpus: not-consulted
learnings_research: "skipped — worker run kept to the brief's scope; cepa.local.md absent (headless inference)"
---

# Review Findings — 2026-11-17 14:59

No `cepa.local.md` in this repo: headless mode inferred the stack (markdown
plugin + bash/python checkers) and continued.

## Findings

### 1
- status: applied
- severity: P2
- agent: architecture-reviewer, previous-comments-reviewer
- category: Rule consistency
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/skills/autonomy/SKILL.md
- title: Re-ask paragraph silent on full-autonomy and headless limits

**Problem:**
The re-ask was required on the first resumed turn, but the same kind says
`full` asks only at the end of a finished run and a headless run files per §5.
The paragraph did not say which wins.

**Fix:**
Added "The limits above still hold: under `full` autonomy the re-ask waits for
the end of the finished run, and a headless run files it per §5 and ends as
**Nobody**." Pinned in RULE_PHRASES with a mutant.

### 2
- status: applied
- severity: P2
- agent: architecture-reviewer
- category: Attention flag
- confidence: 55
- action_class: mechanical
- file: plugins/cepa/skills/autonomy/SKILL.md
- title: Stale NEEDS YOU flag when the operator's prompt answers

**Problem:**
The interrupted session had marked the flag; when the resume prompt answers
the question, nothing said the flag clears.

**Fix:**
Added "Either way, that turn's first-turn clear (the attention flag, below)
removes the old flag." (cites the existing first-turn clear). Pinned + mutant.

### 3
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Wording
- confidence: 45
- action_class: mechanical
- file: plugins/cepa/skills/autonomy/SKILL.md
- title: "unchanged" contradicted the Re-ask prefix

**Problem:**
"the same question, unchanged ... with `Re-ask: ` before the question text"
could be read as forbidding the prefix.

**Fix:**
Now "unchanged except for the prefix `Re-ask: ` on its text, and with the same
options".

### 4
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Scope
- confidence: 40
- action_class: mechanical
- file: plugins/cepa/commands/handoff.md
- title: Handoff item 7 missed an unanswered ask to a coordinator

**Problem:**
Only questions put to the operator were collected.

**Fix:**
Item 7 now covers questions "sent to its coordinator" and "an unanswered `ask`".

### 5
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Cite once
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/commands/handoff.md
- title: Handoff item 7 restated the interruption literal

**Problem:**
Item 7 quoted the `[Tool call interrupted: …` literal that rule 7 owns.

**Fix:**
Removed the literal; item 7 says "an interruption" and cites rule 7.

### 6
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Consistency
- confidence: 50
- action_class: mechanical
- file: plugins/cepa/commands/handoff.md
- title: Step 4 could ask the open question again

**Problem:**
Step 4 interactive mode asks open questions; item 7 carries them forward.

**Fix:**
Item 7: "Step 4 does not ask it again: it travels as a re-ask." Pinned + mutant.

### 7
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Roles
- confidence: 45
- action_class: mechanical
- file: plugins/cepa/skills/autonomy/SKILL.md
- title: A worker next session had no path for a listed open question

**Problem:**
"asked the same way on the next session's first turn" did not cover a worker,
which never calls AskUserQuestion.

**Fix:**
Added "A worker that finds one sends it to its coordinator (**A coordinator**,
below)." Pinned + mutant.

### 8
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: Controls
- confidence: 75
- action_class: mechanical
- file: scripts/check-orca-turn-endings-controls.sh
- title: Several L86 phrases had no single-phrase mutant

**Problem:**
The answered-prompt carve-out, the interruption literal, and two REASK phrases
were killed only by broad mutants or not at all.

**Fix:**
17 L86 mutants now; each new phrase has its own deletion or reword mutant with
an exact MISS set (`bash scripts/check-orca-turn-endings-controls.sh` →
185/185).

### 9
- status: applied
- severity: P3
- agent: python-reviewer
- category: Controls
- confidence: 80
- action_class: mechanical
- file: scripts/check-orca-turn-endings.sh
- title: Handoff template Re-ask line unpinned

**Problem:**
The Step 5 template line sits in a fence, so the step-scoped leg cannot read it;
reverting it kept the checker green.

**Fix:**
REASK_FENCED pins it by whole-file count (once); mutant
`reask-template-gone-handoff`.

### 10
- status: applied
- severity: P3
- agent: python-reviewer
- category: Duplication
- confidence: 70
- action_class: mechanical
- file: scripts/check-orca-turn-endings.sh
- title: REASK loop copied the REPORT loop

**Problem:**
Two identical loops with different labels.

**Fix:**
Extracted `site_once(leg, what, sites)`; MISS labels unchanged, so existing
REPORT mutants still match (185/185).

### 11
- status: deferred
- severity: P3
- agent: previous-comments-reviewer
- category: Residual tracking
- confidence: 50
- action_class: judgment
- file: memory/tasks.d/2026-10-02-punch-list.md
- title: Item 3 findings live only in the PR body

**Problem:**
The confirmed 18e5 bound and the unconfirmed constant name and dashboard
effect are recorded only in PR #140's body.

**Fix:**
coord@main (the punch list's only writer) carries the note into L86's closing
entry. Filed in the PR body and the Handoff block.

---

**Summary:** 11 findings (0 P1, 2 P2, 9 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
