---
date: 2026-11-27T20:59:20
scope: fix/optimization/send-bot-addressing
branch: fix/optimization/send-bot-addressing
pr: 149
agents:
  - adversarial-reviewer
  - reliability-reviewer
  - previous-comments-reviewer
  - python-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
summary:
  total: 18
  p1: 0
  p2: 10
  p3: 8
  pending: 0
  ready: 0
  skipped: 1
  applied: 11
  deferred: 6
  completed: 0
agents_skipped:
  - agent: security-sentinel
    rule: "no auth, PHI or secrets in diff; injection paths covered by adversarial and python reviewers"
  - agent: performance-oracle
    rule: "no ORM, queries or hot loops in diff (bash scripts and tests)"
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
  - agent: comment-analyzer
    rule: "skipped for cost in a worker run; header text checked by the adversarial and previous-comments reviewers"
  - agent: type-design-analyzer
    rule: "no new types or models"
  - agent: code-simplifier
    rule: "skipped for cost in a worker run"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff changes how a send is proven stored (600+ changed lines)"
  - agent: reliability-reviewer
    dispatched: true
    signal: "diff adds external CLI calls (orca bot list, bot chats)"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; punch-list L97, L98, L103 touch orca-send.sh"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped: no deploy surface in diff (plugin scripts and tests)"
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

# Review Findings — 2026-11-27 20:59 (PR #149)

No cepa.local.md in this repo, so the run inferred the stack (bash with
embedded python, plus tests). Reviewed head 81d5107. No P1. The applied fixes
are in commit f181417 (rebased on origin/main 36cf8ed).

## Findings

### 1
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: Correctness
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/scripts/orca-send.sh
- lines: cepa_send_readback
- title: the reply read-back matched on the thread root, so an earlier reply to another message read as this one

**Problem:**
The read-back accepted a reply row whose `thread_id` was the target's root.
Take this session's earlier reply, with the same body, to ANOTHER message of
the thread, inside the 120 s window. It passed every filter, so a reply whose
call timed out and stored nothing was reported stored, and named the wrong
recipient. silent-failure-hunter (P3-5) found the same.

**Fix:**
The read-back matches a reply on the target's own id only, as before this
change. Case "READBACK reply is not read back on the question's root". Header,
THE REPLY THREAD.

### 2
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: Correctness
- confidence: 60
- action_class: corroborated
- file: plugins/cepa/scripts/orca-send.sh
- lines: reply nudge branch
- title: a reply stored for orca_session_id was reported delivered on an unmeasured wake

**Problem:**
The script printed "a mailbox Orca delivers" and exited 0. Nobody has measured
whether Orca wakes a chat that has no Run. previous-comments-reviewer (3)
found the same.

**Fix:**
The script now prints `Orca nudge skipped: … whether Orca wakes it is not
measured` and `tell <chat> to check its Orca inbox`, and exits 1. Case
"CHATREPLY reply stored for a chat is not claimed delivered"; mutant
chat-reply-claimed.

### 3
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Reliability
- confidence: 50
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: verdict() bot branch
- title: a bot reply with no to_handle went straight to unproven and skipped the read-back

**Problem:**
The reply's `to_handle` for a bot was not measured. A reply with none exited 5
with no read-back, so the message stayed pending, a bot has no drain, and a
resend would duplicate it.

**Fix:**
FAIL-class, so the read-back runs, keeping its `orca_session_id:` row filter
and the chats proof. Cases "BOT with no recipient is read back from its chat"
and "… and no row is not stored"; mutant bot-no-recipient-unproven; the reason
was added to orca-health.sh REASONS.

### 4
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Correctness
- confidence: 75
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: THE BOT FIRST resolver
- title: two bots named <repo>-bot read as no bot, silently

**Problem:**
`n == 1` gave the same answer, NONE, for 0 and for 2 or more bots. So an
ambiguous coordinator fell through to the terminal resolver.

**Fix:**
The resolver now prints AMBIG, and the send goes pending with an
`outbox_ambiguous` alert. The reason was added to REASONS. Case "two bots of
the same name are ambiguous"; mutant bot-two-is-one.

### 5
- status: applied
- severity: P2
- agent: reliability-reviewer
- category: Reliability
- confidence: 60
- action_class: corroborated
- file: plugins/cepa/scripts/orca-send.sh
- lines: THE BOT FIRST resolver
- title: a paused bot took coord: sends that nobody would read

**Problem:**
The resolver counted every row named `<repo>-bot`, including a paused one.
python-reviewer (1) and pr-test-analyzer (2) found the same.

**Fix:**
A row with `paused: true` does not count, so the send falls through to the
terminal resolver. Case "a paused bot is not the coordinator"; mutant
bot-paused-counts.

### 6
- status: deferred
- severity: P2
- agent: reliability-reviewer
- category: Reliability
- confidence: 70
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: THE BOT FIRST resolver, `*)` arm
- title: an unreadable bot list falls back to the terminal coord@main

**Problem:**
A timed-out or `ok:false` bot list goes to the terminal coord@main. When a bot
coordinator also exists, the route can flip between two sends.
silent-failure-hunter (P2-1) and python-reviewer (2) found the same.

**Fix:**
Not applied. The fallback keeps working with an Orca that has no `bot` command,
and C6 still needs terminal coordinators. The options for coord@main are in
residual 6.

### 7
- status: deferred
- severity: P2
- agent: adversarial-reviewer
- category: Design
- confidence: 50
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: THE BOT FIRST, delivered move
- title: a <repo>-bot wins over a live terminal coord@main, and its delivery is filed as drained

**Problem:**
A stale pilot bot named `<repo>-bot` takes `coord:` mail from a live terminal
coordinator. Its outbox copy is `.drained`, so no drain shows it again.
previous-comments-reviewer (5) found the same.

**Fix:**
Not applied. This is L103 C2 as written: the bot is the coordinator when it
exists. The header now says so. The choice belongs to coord@main (residual 7).

### 8
- status: deferred
- severity: P2
- agent: reliability-reviewer
- category: Reliability
- confidence: 65
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: bot chats proof
- title: a stored bot send whose chats read fails stays pending, so a resend may duplicate it

**Problem:**
The inbox row proves a store for an `orca_session_id:`. When only `bot chats`
fails, the script exits 5 and keeps the file pending.

**Fix:**
Not applied. Exit 5 keeps the proof rule: the chats read is the part that
binds the row to the bot. Residual 8.

### 9
- status: applied
- severity: P2
- agent: reliability-reviewer
- category: Documentation
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: TIME BUDGET
- title: the header's time budget left out the two new reads

**Problem:**
The header did not count `bot list` or `bot chats`.

**Fix:**
Both reads are now in the budget: a bot send takes about 140 s.

### 10
- status: applied
- severity: P2
- agent: previous-comments-reviewer
- category: Process
- confidence: 90
- action_class: mechanical
- file: plugins/cepa/.claude-plugin/plugin.json
- lines: 4
- title: the manifests conflicted with main (1.60.5)

**Problem:**
main moved to 1.60.5 (#147), so the PR showed CONFLICTING.

**Fix:**
Rebased onto origin/main 36cf8ed. Both manifests are at 1.61.0.

### 11
- status: applied
- severity: P3
- agent: python-reviewer
- category: Correctness
- confidence: 45
- action_class: corroborated
- file: plugins/cepa/scripts/orca-send.sh
- lines: re-read exit code
- title: an unproven thread hid a misaddressed reply

**Problem:**
Exit 4 came before 3, so a reply that Orca addressed back to this session read
as unproven. pr-test-analyzer (6) found the same.

**Fix:**
The order is now `1 if not found else 3 if mine else 4`. Case "REPLYTHREAD
reply addressed to this session wins over the thread"; mutant
reply-mine-after-thread.

### 12
- status: applied
- severity: P3
- agent: python-reviewer
- category: Correctness
- confidence: 40
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: verdict() tail
- title: an orca_session_id recipient was accepted for a term_, run: or dispatch: send

**Problem:**
Widening ADDR also let a plain send that was stored for a chat count as the
target's.

**Fix:**
An `orca_session_id:` recipient now counts only for a reply or a `bot:` target.
Case "CHATREPLY a term_ send stored for a chat is not proven"; mutant
chat-recipient-any-type.

### 13
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Documentation
- confidence: 55
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: THE REPLY THREAD
- title: the L97 counts did not state the probe behind them

**Problem:**
The 400/348/14 counts were given without the field-scan command that produced
them (CLAUDE.md absence-claim rule).

**Fix:**
The header now states the scan one-liner.

### 14
- status: deferred
- severity: P3
- agent: python-reviewer
- category: Reliability
- confidence: 50
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: bot chats proof
- title: the chats proof needs closed to be the value false

**Problem:**
An open chat with no `closed` key reads as not open. previous-comments-reviewer
(4) and silent-failure-hunter (P3-1) found the same.

**Fix:**
Kept. The rule fails closed, and the measured rows all carry the key. orca-lab
re-measures after C1 (residual 1).

### 15
- status: deferred
- severity: P3
- agent: previous-comments-reviewer
- category: Observability
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: cepa_send_alert
- title: a chat sender's alert says sender=unknown

**Problem:**
The alert writer and orca-health.sh know only `term_…|unknown`. All the other
reviewers found the same.

**Fix:**
Not applied, because both readers would have to change. Residual 3 (L103 C4).

### 16
- status: applied
- severity: P3
- agent: pr-test-analyzer
- category: Testing
- confidence: 80
- action_class: mechanical
- file: scripts/check-orca-outbox.sh
- lines: RESOLVE bot cases
- title: the coord: bot path never saw an unproven chat; the bot-name boundaries were untested

**Problem:**
The outbox stub always answered an open Home chat. No case checked a paused
bot, two bots of one name, or a 105-character name.

**Fix:**
Added cases "a bot send to a closed chat stays pending" (stub mode
botchats_closed), "a paused bot …", "two bots … are ambiguous" and "BOT a name
of 105 characters is accepted". The remaining gaps (a bot list with
`ok:false`, an escalation to a bot, a quoted bot name) are in residual 9.

### 17
- status: skipped
- severity: P3
- agent: pr-test-analyzer
- category: Testing
- confidence: 85
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: cepa_send_root parse
- title: the root-field parse guard is unreachable through real inputs

**Problem:**
`verdict()` writes a third field only for a reply that has a msg_ id, so the
guard's `fail` never fires.

**Fix:**
Kept as a defensive check on the python-to-bash boundary. No change.

### 18
- status: deferred
- severity: P3
- agent: reliability-reviewer
- category: Reliability
- confidence: 55
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: bot chats proof; bot list read
- title: the chats proof takes any open chat, not the Home chat; bot list is read unpaged

**Problem:**
A send with no `--chat` lands in Home, but the proof accepts any open chat of
the bot. `bot list` has no paging, and if a long list were ever truncated it
would read as NONE.

**Fix:**
Not applied, because neither case was seen (the list had no paging field).
Residual 10.

---

**Summary:** 18 findings (0 P1, 10 P2, 8 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
