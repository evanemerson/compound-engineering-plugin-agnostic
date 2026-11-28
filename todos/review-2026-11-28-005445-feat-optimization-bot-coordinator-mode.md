---
date: 2026-11-28T00:54:45
scope: feat/optimization/bot-coordinator-mode
branch: main
pr: 153
head: b7d37a9b0a4a8a5c08b3e6c930b6cc031c3b7cca
agents:
  - adversarial-reviewer
  - security-sentinel
  - previous-comments-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
summary:
  total: 18
  p1: 0
  p2: 9
  p3: 9
  pending: 0
  ready: 0
  skipped: 0
  applied: 11
  deferred: 7
  completed: 0
agents_skipped:
  - agent: performance-oracle
    rule: "no cepa.local.md roster; bash/python health scripts with no hot path beyond bounded Orca calls"
  - agent: python-reviewer
    rule: "no cepa.local.md roster; inline python is small readers, covered by adversarial and silent-failure passes"
  - agent: data-integrity-guardian
    rule: "no migrations or data stores in the diff"
  - agent: architecture-reviewer
    rule: "no cepa.local.md roster; one adapter (§12b) extended, no new module"
  - agent: schema-drift-detector
    rule: "no models, migrations, serializers, forms or admin in the diff"
  - agent: frontend-reviewer
    rule: "no templates/JS/CSS in diff"
  - agent: deployment-verifier
    rule: "no config, dependencies, Docker, env or migrations; plugin scripts only"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff is 1638 lines"
  - agent: reliability-reviewer
    dispatched: false
    reason: "no queue/webhook/transaction/external-call code"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md history exists; memory/tasks.d entries touch the diff"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped: plugin scripts only (roster skip rule)"
  conditions: []
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
  corpus: none
learnings_research: "skipped — docs/solutions is absent in this checkout (docs/ is gitignored in this repo)"
---

# Review Findings — 2026-11-28 00:54

cepa.local.md is missing in this repo; headless mode inferred the stack
(bash with inline python3, markdown). Reviewed PR #153 at b7d37a9.

## Findings

### 1
- status: applied
- severity: P2
- agent: adversarial-reviewer, security-sentinel
- category: Correctness
- confidence: 95
- action_class: corroborated
- file: plugins/cepa/scripts/orca-health.sh
- lines: 455-475
- title: An ack prints success but the alert returns when ack path and reader disagree on the repo

**Problem:**
The ack chose `acked/_shared/` or `acked/<wt>/` from `sed`'s last `repo=` line,
while the reader split lines with `splitlines()` and read unknown-shape files
only against its own markers. A planted or corrupt file (unknown shape with
`repo=unknown`, or a `\v` inside a line) took an ack that printed `ORCA ack:`
and then re-alerted every turn. Reproduced by the adversarial reviewer.

**Fix:**
Applied: every ack writes this worktree's marker, and a repo-less file's ack
also writes `_shared/`; the reader splits on `\n` only. Cases: "HEALTH an
unknown-shape repo-less file stays acked", "HEALTH repo-less ack marks _shared".

### 2
- status: applied
- severity: P2
- agent: adversarial-reviewer, silent-failure-hunter
- category: Silent failure
- confidence: 60
- action_class: corroborated
- file: plugins/cepa/scripts/orca-health.sh
- lines: 1078-1092
- title: A terminal's null-holder run-current Run read ok where main raised an alert

**Problem:**
With no Run named, a terminal whose run-current Run had a null holder got only
a note and `ORCA health: ok`; on main it was `orca-unreadable:run-current`.
Its workers went unchecked with no alert.

**Fix:**
Applied: it raises `unbound:<run>:<hour>` (ackable per hour), naming the
re-bind block. Also for a `structworker_` holder.

### 3
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- lines: 960-963
- title: Health's outbox reader accepting a chat sender had no case (surviving mutant)

**Problem:**
Reverting OHEAD's sender regex in orca-health.sh left both suites green.

**Fix:**
Applied: "BOT health reads a chat-sent outbox file" and its quoted-shape
control; mutant `outbox-chat-sender-unread`.

### 4
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- lines: 930-935
- title: Shared ack of a repo-less outbox_* alert file had no case (surviving mutant)

**Problem:**
Dropping the `_shared` read from the outbox-class branch left the suites green.

**Fix:**
Applied: "HEALTH repo-less outbox alert ack" and "HEALTH one repo-less outbox
ack clears it in another coordinator"; mutant
`health-repoless-outbox-shared-ignored`.

### 5
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- lines: 936-940
- title: The repo-less label on outbox_* alerts had no case (surviving mutant)

**Problem:**
Replacing `label` with `""` in the outbox alert left the suites green.

**Fix:**
Applied: labeled and unlabeled repo-less outbox alert cases; mutant
`health-repoless-outbox-unlabeled`.

### 6
- status: deferred
- severity: P2
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 65
- action_class: judgment
- file: plugins/cepa/scripts/orca-health.sh
- lines: 900-910
- title: The one-hour wait can hide a repo-less failed send from the coordinator that needs it

**Problem:**
A repo-less `send_failed` file that names another session is hidden from
every other coordinator for an hour. If the named session is a worker that
already ended, its coordinator sees `ok` for that hour.

**Fix:**
Judgment (L100's design choice): keep the wait only for `nudge_skipped`, or
drop it and keep only the shared ack. Filed to the branch shard (item 13).

### 7
- status: deferred
- severity: P2
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 55
- action_class: judgment
- file: plugins/cepa/scripts/orca-rebind.sh
- lines: 388-410
- title: A chat's ok for its run-current Run rests on an unmeasured run-current property

**Problem:**
If a chat's run-current can report another chat's Run, two chats both print
`ok` for one Run. Health trusts the same read.

**Fix:**
Probe 7 in the shard asks orca-lab to measure it; until then the headers
state the trust. Filed to the branch shard (item 14).

### 8
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 55
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- lines: 1155-1157
- title: A chat's question checks read ok with no sign that its inbox mailbox is unmeasured

**Problem:**
The caveat lived only in the header.

**Fix:**
Applied: a chat's summary carries "inbox read as from a terminal: which
mailbox a chat's inbox lists is not measured"; mutant
`health-chat-inbox-note-silent`.

### 9
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: Correctness
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 3080-3090
- title: A bot that passes repo: to show but not to ack writes its acks where show never reads them

**Problem:**
Rule 9 said the `repo:` line goes under `<cli>` "of each block"; the ack form
is not a separate block, so a bot could ack into `acked/unknown/`.

**Fix:**
Applied: rule 9 says the `repo:` line goes in the `ack` form too.

### 10
- status: applied
- severity: P3
- agent: security-sentinel, silent-failure-hunter
- category: Correctness
- confidence: 50
- action_class: corroborated
- file: plugins/cepa/scripts/orca-health.sh
- lines: 905
- title: A future time kept a repo-less file hidden forever

**Problem:**
`now - time < 3600` stays true for a time in the future.

**Fix:**
Applied: `0 <= now - time < 3600`; case and mutant `health-repoless-future-hidden`.

### 11
- status: applied
- severity: P3
- agent: security-sentinel, silent-failure-hunter
- category: Correctness
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/scripts/orca-health.sh
- lines: 410-416
- title: A worktree named _shared or bot@… acked into the shared or a bot's directory

**Problem:**
The worktree name set allows `_shared` and `bot@x`.

**Fix:**
Applied: such a worktree acks as `unknown`; case and mutant `health-reserved-wt-kept`.

### 12
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Correctness
- confidence: 55
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- lines: 903
- title: A repo-less file that only targets another session did not wait the hour

**Problem:**
`names_other` read only the sender and `run:` targets.

**Fix:**
Applied: a `term_`, `orca_session_id:` or `bot:` target counts; case and
mutant `health-repoless-target-unnamed`.

### 13
- status: deferred
- severity: P3
- agent: previous-comments-reviewer
- category: Documentation
- confidence: 60
- action_class: judgment
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 2915-3000
- title: The health and drain blocks have no placeholder for the bot's repo: line

**Problem:**
The `repo:` line is given only in rule 9's prose.

**Fix:**
Add an optional placeholder line to both blocks and their BLOCK legs. Filed
to the branch shard (item 15).

### 14
- status: deferred
- severity: P3
- agent: previous-comments-reviewer
- category: Documentation
- confidence: 50
- action_class: judgment
- file: memory/tasks.d/2026-10-02-punch-list.md
- lines: 3045-3048
- title: L103 C4's text describes the measured problem, which a reader may take as the expected result

**Problem:**
"shows every repo's alerts" is orca-lab's M6 observation; this PR shows only
the named repo and alerts `orca-unreadable:repo` without one.

**Fix:**
coord@main records the chosen reading when it folds C4 (the punch list is its
file). Filed to the branch shard (item 16).

### 15
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 50
- action_class: judgment
- file: plugins/cepa/scripts/orca-health.sh
- lines: 1007-1050
- title: A session with no repo skips unknown-shape outbox entries and prints a plain ok when no named file exists

**Problem:**
`see_unknown` needs `main`; a forgotten `repo:` is invisible until a named
file exists.

**Fix:**
Count them into the norepo alert, and always note "no repo bound". Filed to
the branch shard (item 17).

### 16
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Correctness
- confidence: 35
- action_class: judgment
- file: plugins/cepa/scripts/orca-health.sh
- lines: 418-432
- title: The bot-home rule depends on HOME and on the bot home not being inside a git checkout

**Problem:**
A different HOME, or a home inside a dotfiles repo, changes the derived repo.
The bot homes on this machine are not inside git (security and adversarial
reviewers checked).

**Fix:**
Note the derived repo and how in the summary. Filed to the branch shard
(item 18).

### 17
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- lines: 455-475
- title: A failed sed or mkdir in the ack path gave a wrong-scope ack with no hint

**Problem:**
`|| :` after the shared `mkdir`, and an empty `frepo` on a sed failure.

**Fix:**
Applied with finding 1: the own marker is always written, and a shared
marker that cannot be written prints `ORCA ack failed: … the shared ack
marker could not be written`.

### 18
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 60
- action_class: judgment
- file: scripts/check-orca-nudge.sh
- lines: 2300-2400
- title: Smaller case gaps in bot mode

**Problem:**
No case for: a chat's own repo-less failed send seen from a no-repo session; a
stale worker's commit read from a bot home; a bot home reached through a
symlink or a 101-character name; `term_x` beside a chat identity in health; a
shared marker that cannot be written.

**Fix:**
Add the cases with exact-set mutants. Filed to the branch shard (item 19).

---

**Summary:** 18 findings (0 P1, 9 P2, 9 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
