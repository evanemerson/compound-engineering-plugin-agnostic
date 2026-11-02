---
date: 2026-11-02T08:35:09
scope: pr:#122
branch: fix/roles/send-refusals
agents:
  - learnings-researcher
  - architecture-reviewer
  - previous-comments-reviewer
  - pr-test-analyzer
config: "no cepa.local.md — inferred roster; scope is the merge commit 61d4e8a's own resolution changes after 598b74a (git show --cc 61d4e8a)"
agents_skipped:
  - agent: security-sentinel
    reason: "no guard changed; version text, one doc rule and control kill-sets only"
  - agent: performance-oracle
    reason: "no query, ORM or frontend code"
  - agent: python-reviewer
    reason: "control-list literals only"
  - agent: data-integrity-guardian
    reason: "no migrations or data stores"
  - agent: schema-drift-detector
    reason: "no models or migrations"
  - agent: frontend-reviewer
    reason: "no templates, JS or CSS"
  - agent: deployment-verifier
    reason: "nothing deploys from this repo"
  - agent: silent-failure-hunter
    reason: "no error path changed"
  - agent: comment-analyzer
    reason: "inferred roster; architecture-reviewer read the rule text"
  - agent: type-design-analyzer
    reason: "no types added"
  - agent: code-simplifier
    reason: "inferred roster"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: false
    reason: "under 300 PR-side changed lines; no risky path"
  - agent: reliability-reviewer
    dispatched: false
    reason: "no queue, webhook or transaction code"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; the prior #122 review file and shard were renumbered"
agents_failed: []
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped — nothing deploys from this repo"
  conditions: []
detection_signals:
  passed: 0
  source_docs: 0
  backfill_candidates: 0
  suspect_bullets: 0
  corpus: absent
summary:
  total: 3
  p1: 0
  p2: 1
  p3: 2
  pending: 0
  ready: 0
  skipped: 0
  applied: 3
  deferred: 0
  completed: 0
---

# Review Findings — 2026-11-02 08:35 — PR #122 merge tail (`61d4e8a`)

### 1
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: test-coverage
- confidence: 80
- action_class: mechanical
- file: scripts/check-orca-nudge-controls.sh
- lines: SEND_MUTANTS, before `nudge-downgrade-reroute-hidden`
- title: No control kills the two downgraded-store checks uniquely

**Problem:**
`STORE downgraded send that stored nothing` and `STORE downgraded send missing from the inbox` were killed only by generic store mutants that older checks also kill. A change that printed the downgrade line before the store was proven would leave every control green.

**Fix:**
Applied: new mutant `nudge-downgrade-before-store` makes `fail()` print the downgrade line and exit 0 for a downgraded send. Its exact kill-set is the two checks. `check-orca-nudge-controls.sh`: 255/255.

### 2
- status: applied
- severity: P3
- agent: architecture-reviewer
- category: documentation
- confidence: 60
- action_class: judgment
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: §12b rule 2, main-coordinator bullet
- title: Selector rule read as self-contradicting and carried an unsourced cross-repo claim

**Problem:**
"Never use `path:<lane>` … only an absolute Linux path resolved" did not say the success was `worktree show` only. The three-repo report had no probe beside it.

**Fix:**
Applied: the text now states the probe (`orca-ide worktree show --worktree <selector> --json`, Orca 1.4.245), says the absolute-path success was `worktree show` only, and labels the three-repo report as unverified here.

### 3
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: documentation
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- lines: comment above `only a term_ handle is nudged`
- title: Comment still said 1.49.x after the 1.51.0 renumber

**Problem:**
The comment says the group is written before 1.51.0 but names "a session still on 1.49.x". 1.50.x also emits the old reason.

**Fix:**
Applied: "1.50.x or earlier".

---

**Summary:** 3 findings (0 P1, 1 P2, 2 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
