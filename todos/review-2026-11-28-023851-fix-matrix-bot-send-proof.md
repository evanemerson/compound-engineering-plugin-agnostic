---
date: 2026-11-28T02:38:51
scope: fix/matrix/bot-send-proof
branch: fix/matrix/bot-send-proof
pr: 155
agents:
  - learnings-researcher
  - adversarial-reviewer
  - previous-comments-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
  - comment-analyzer
summary:
  total: 17
  p1: 0
  p2: 5
  p3: 12
  pending: 0
  ready: 0
  skipped: 0
  applied: 12
  deferred: 5
  completed: 0
agents_skipped:
  - agent: security-sentinel
    rule: "no auth, PHI or secrets in diff; injection paths covered by the adversarial reviewer"
  - agent: performance-oracle
    rule: "no ORM, queries or hot loops in diff (bash scripts and tests)"
  - agent: python-reviewer
    rule: "embedded python is small parse blocks; read by the adversarial and silent-failure reviewers"
  - agent: data-integrity-guardian
    rule: "no migrations or data writes in diff"
  - agent: schema-drift-detector
    rule: "no models, migrations, serializers, forms or admin in diff"
  - agent: frontend-reviewer
    rule: "no templates/JS/CSS in diff"
  - agent: deployment-verifier
    rule: "no config, dependencies, Docker, env or migration files; manifests carry a version bump only"
  - agent: architecture-reviewer
    rule: "no new module boundaries; the change sits inside existing scripts"
  - agent: type-design-analyzer
    rule: "no new types or models"
  - agent: code-simplifier
    rule: "skipped for cost in a worker run"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff changes how a send is proven stored (692-line diff)"
  - agent: reliability-reviewer
    dispatched: false
    reason: "skipped for cost: the one new external call (run-show) was traced by the adversarial and silent-failure reviewers"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; PR #149's findings and shard touch orca-send.sh"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped: no deploy surface in diff (plugin scripts and tests)"
  conditions: []
learnings_research: "ran in parallel with the reviewers, so its briefing reached none of them; read afterwards: its 2 Detection docs match nothing in this diff"
detection_signals:
  matched_docs: 2
  docs_with_detection: 2
  signals_passed: 0
  sources:
    - docs/solutions/logic-errors/a-leg-that-runs-a-fenced-block-selects-it-by-a-line-no-mutant-edits.md
    - docs/solutions/logic-errors/a-shard-line-is-flipped-in-the-commit-that-closes-its-item.md
  backfill_candidates: []
  suspect_bullets: 0
  corpus: "consulted after dispatch, not relayed; no mutant here edits a SKILL.md block, and the PR closes no punch-list item"
---

# Review Findings — 2026-11-28 02:38 (PR #155)

No cepa.local.md in this repo, so the run inferred the stack (bash with
embedded python, plus tests). Reviewed head 30a462b. No P1. Finding 1 is
handled as critical (a silent message loss on the read-back path). The
applied fixes are in the commit that adds this file.

## Findings

### 1
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: Correctness
- confidence: 95
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: cepa_send_readback and the read-back case
- title: a Run row found by the read-back counted as stored, though it may be an identical send to another bot

**Problem:**
When the send call fails, the read-back finds the row by sender, body, type
and subject. A `run:` row for a `bot:` target then passed the bot-Run proof:
botRequest is on every bot send, a null coordinator holds for any bot's Run,
and the Home-chat check reads the target bot, not the Run. An identical send
to bot b, then a failed send to bot a, reported `stored` for a with rc 0 and
moved its outbox copy to delivered. Reproduced with a stub.

**Fix:**
A `run:` row read back for a `bot:` target is `not proven stored`, never
stored. Cases: "BOTRUN a Run row read back is not proven", "… with no
recipient …", "BOTRUN a read-back of another bot's Run row is not stored as
this bot's". Mutant: botrun-readback-counted.

### 2
- status: applied
- severity: P2
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 95
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: THE BOT ADDRESS
- title: THE BOT ADDRESS still said a bot send counts only for an orca_session_id: recipient

**Problem:**
The paragraph above A BOT'S RUN contradicted the new `run:` proof.

**Fix:**
It now names the chat proof for `orca_session_id:` and points to A BOT'S RUN
for `run:`.

### 3
- status: applied
- severity: P2
- agent: comment-analyzer
- category: Absence claim
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: A BOT'S RUN
- title: the header probe could not be pasted and did not print the counts beside it

**Problem:**
The probe was wrapped mid-expression across comment lines, and it printed
neither the Run's row count nor the rows without botRequest.

**Fix:**
The probe is now a heredoc over a saved inbox file. It prints the total, the
Run's rows and those with botRequest, and the botRequest rows by recipient.
Run as copied from the header, it printed 471, 17, 12 and the 8 chat rows,
which the header states; the chat ids were checked against `bot chats --all`
of orca-lab-bot, fleet and helm-bot.

### 4
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 85
- action_class: mechanical
- file: scripts/check-orca-nudge.sh
- lines: BOTRUN leg
- title: no case where the Home flag and the open flag sit on different chats

**Problem:**
A mutant that checks `any(home) and any(open)` separately survived.

**Fix:**
Case "BOTRUN a closed Home chat beside an open other chat is not proven";
mutant botrun-home-split.

### 5
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Stated gap
- confidence: 80
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: A BOT'S RUN
- title: run-show and the Home-chat check do not tie the Run to the target bot

**Problem:**
Checks 2 and 3 hold for any bot's Run; only Orca's routing ties the Run to
the bot.

**Fix:**
The header now says checks 2 and 3 are sanity checks, not proof of the
recipient, and that the tie is the send reply's msg id and `to_handle`. With
finding 1, no path counts a Run row without that reply.

### 6
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Message accuracy
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/orca-send.sh
- lines: bot-Run leg, run-show parse
- title: a run-show of another Run was reported as a Run with a terminal coordinator

**Problem:**
One exit code covered both an id mismatch and a coordinator. Also found by
silent-failure-hunter and pr-test-analyzer.

**Fix:**
Exit 3 and its own reason ("answered for another Run"); mutant
botrun-other-run-as-coord.

### 7
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Message accuracy
- confidence: 80
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: bot_reply_not_yours hint
- title: the bot-reply hint was not limited to a reply

**Problem:**
Any type refused with that code would print reply advice.

**Fix:**
Gated on `type: reply`. Case "BOT the bot-reply code on a send that is not a
reply adds no hint"; mutant bot-reply-hint-any-type.

### 8
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: TIME BUDGET
- title: the bot send time bound said about 175 s for 5 reads of 34 s

**Problem:**
5 × 34 s is 170 s, and only a `coord:` send reads the bot list.

**Fix:**
About 170 s for a `coord:` send that resolves to a bot, about 136 s for a
direct `bot:` send.

### 9
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Absence claim
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: A BOT'S RUN
- title: the 1.61.0 false-fail claim had no source

**Problem:**
No alert or outbox id was cited.

**Fix:**
Cites coord@main's report, alert 1795840460-hEHPRYn7 and the outbox file.

### 10
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 80
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: A BOT'S RUN
- title: "a bot whose Home chat is bound to a Run gets its mail there" was stated as general fact

**Problem:**
Measured for orca-lab-bot only; the bind timing is not measured.

**Fix:**
Names orca-lab-bot and fleet, and says the bind timing is not measured, so
both forms are taken.

### 11
- status: applied
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 80
- action_class: mechanical
- file: scripts/check-orca-nudge.sh
- lines: BOTRUN leg
- title: a botRequest that is a list was not tested

**Problem:**
`isinstance(..., (dict, list))` survived.

**Fix:**
Case "BOTRUN botRequest that is a list is not proven"; mutant
botrun-botreq-list.

### 12
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 70
- action_class: judgment
- file: scripts/check-orca-nudge.sh
- lines: BOTRUN leg
- title: smaller BOTRUN gaps: truthy ok, empty coordinator, non-object payload, no run object, hint on the outbox path

**Problem:**
Each is a mutant that survives or a shape no case pins; each fails closed
today.

**Fix:**
Shard item 4 of memory/tasks.d/2026-11-28-fix-matrix-bot-send-proof.md.

### 13
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Fail-closed inertness
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: botreq() in the re-read
- title: a payload given as an object would make every bot-to-Run send unproven

**Problem:**
Orca 1.4.280 gives a JSON string; an object would fail closed.

**Fix:**
Shard item 5: re-check on each Orca upgrade; the case "a payload given as
an object … is not proven" pins today's behavior.

### 14
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Message accuracy
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: THE RE-READ
- title: a row outside the 200-row window is reported as no message stored

**Problem:**
From before this PR; the new leg inherits it.

**Fix:**
Shard item 6.

### 15
- status: deferred
- severity: P3
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 70
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: chat-ownership check
- title: the orca_session_id: bot leg still takes any open chat, not only Home (#149 item 10)

**Problem:**
The new Run leg requires the Home chat; the chat leg does not.

**Fix:**
Shard item 7.

### 16
- status: deferred
- severity: P3
- agent: previous-comments-reviewer
- category: Continuity
- confidence: 80
- action_class: judgment
- file: memory/tasks.d/2026-11-27-fix-optimization-send-bot-addressing.md
- lines: item 1
- title: #149's shard item 1 is stale now that a run: form counts

**Problem:**
That shard belongs to another worker.

**Fix:**
Shard item 8: coord@main updates it.

### 17
- status: applied
- severity: P3
- agent: comment-analyzer
- category: Comment accuracy
- confidence: 80
- action_class: mechanical
- file: memory/tasks.d/2026-11-28-fix-matrix-bot-send-proof.md
- lines: item 1
- title: the shard's stated gap did not name the field the proof uses

**Problem:**
Item 1 listed the fields read and found lacking, not `payload.botRequest`.

**Fix:**
Item 1 now says it uses `payload.botRequest`, which marks mail to a bot but
not which bot, and that a read-back Run row is never counted.

---

**Summary:** 17 findings (0 P1, 5 P2, 12 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
