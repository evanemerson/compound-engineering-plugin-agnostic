---
date: 2026-11-16T11:55:30
scope: pr:138
branch: fix/matrix/orca-reliability-set
agents:
  - adversarial-reviewer
  - security-sentinel
  - previous-comments-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
  - comment-analyzer
agents_skipped:
  - agent: python-reviewer
    reason: "no cepa.local.md roster; the diff's Python is inline in bash and read by the adversarial and silent-failure agents"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff of about 1,500 changed lines"
  - agent: reliability-reviewer
    dispatched: false
    reason: "no queue, webhook or transaction code; the Orca call failure paths went to the adversarial and silent-failure agents"
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
learnings_research: "skipped — docs/solutions/ is absent in this checkout (docs/ is gitignored)"
summary:
  total: 15
  p1: 0
  p2: 3
  p3: 12
  pending: 0
  ready: 0
  skipped: 1
  applied: 10
  deferred: 4
  completed: 0
---

# Review Findings — PR #138

## Findings

### 1
status: applied
severity: P2
agent: adversarial-reviewer, silent-failure-hunter, comment-analyzer
category: Reliability
confidence: 85
action_class: corroborated
file: plugins/cepa/scripts/orca-send.sh
lines: 940-960
title: The read-back took a row stored for another recipient as this send

**Problem:** The read-back matched type, subject, body, sender and time, but not the recipient. A send to B that timed out could read back an identical send to A from a minute before, print `Orca send stored … for A` and exit 0 in no-nudge mode, though nothing reached B.

**Fix:** A `term_` or `run:` target matches only a row stored for itself; a `dispatch:` target matches any dispatch (the L88 item 2 rewrite). Cases: another recipient, another Run, a term_ row for a dispatch target. Mutants: send-readback-recipient, send-readback-dispatch-any.

### 2
status: applied
severity: P2
agent: adversarial-reviewer, previous-comments-reviewer
category: Data safety
confidence: 60
action_class: judgment
file: plugins/cepa/scripts/orca-lane.sh
lines: 505-530
title: rm trusted a live-agent read that left out a WSL host on this machine

**Problem:** The omitted-host relaxation also covered `worktree ps` and `terminal list`, the live-agent gate before `rm`. A WSL host runs on this machine, so its agent can sit in the lane's directory while no local row shows it, and `rm` would delete the directory under it.

**Fix:** Those two reads are strict: any omitted host makes them not count, and the note says why. `name`, `create` and the list read keep the relaxation. So `rm` still refuses while a WSL host is added (now naming the host); the PR body says so. Cases and the mutant omitted-strict-off pin it.

### 3
status: applied
severity: P2
agent: adversarial-reviewer, silent-failure-hunter, previous-comments-reviewer
category: Reliability
confidence: 50
action_class: corroborated
file: plugins/cepa/scripts/orca-rebind.sh
lines: 300-320
title: A host's own terminal list counted without checking its own scope

**Problem:** An offline host behind the relay could answer an empty, complete-looking list that itself left hosts out; the holder then read as gone, and a live coordinator's Run could be taken.

**Fix:** A host read counts only with `hostScope.hostIds` non-empty and `omittedHostIds` empty; otherwise the re-bind asks, naming the host. Cases and the mutant rebind-host-own-scope pin it.

### 4
status: applied
severity: P3
agent: silent-failure-hunter, pr-test-analyzer
category: Silent failure
confidence: 80
action_class: corroborated
file: plugins/cepa/scripts/orca-send.sh
lines: 985-990
title: With no clock the read-back window matched any older row

**Problem:** A failed `date` set the start to 0, so the window never excluded an old identical row.

**Fix:** No clock means no read-back: the first failure stands. Case READBACK no clock; mutant send-readback-noclock.

### 5
status: applied
severity: P3
agent: adversarial-reviewer, silent-failure-hunter, pr-test-analyzer
category: Contract
confidence: 65
action_class: corroborated
file: plugins/cepa/scripts/orca-lane.sh
lines: 315-345
title: The omitted-host note printed after the Ending line

**Problem:** The EXIT trap printed the note after `Ending first line: …`, which the header says is last on exit 1 and 3.

**Fix:** kept() and failed() print the note before their Ending line; the trap prints it only if not yet printed. Two cases pin the order; mutant omitted-note-after-ending.

### 6
status: applied
severity: P3
agent: security-sentinel
category: Relay (§12c)
confidence: 60
action_class: mechanical
file: plugins/cepa/scripts/orca-health.sh
lines: 925-935
title: lastFailure prose reached the operator question

**Problem:** The character-class filter passed any sentence up to 120 characters, not a shape.

**Fix:** Shown only as a `[a-z_]` token or a sentence in LAST_FAILURES (the one Orca was measured to write); anything else prints `an unrecognised failure`. Case with planted prose.

### 7
status: applied
severity: P3
agent: security-sentinel, pr-test-analyzer
category: Logic
confidence: 50
action_class: corroborated
file: plugins/cepa/scripts/orca-health.sh
lines: 905-912
title: Any worker_done row silenced a failed-dispatch alert

**Problem:** The skip checked only the payload's dispatch id, so a `succeeded` report for a dispatch Orca settled failed hid the alert.

**Fix:** Only a `failed` worker_done for that dispatch silences it. Cases for a succeeded report and another dispatch's report; mutant health-failed-reported-any-outcome.

### 8
status: applied
severity: P3
agent: security-sentinel
category: Argv
confidence: 55
action_class: mechanical
file: plugins/cepa/scripts/orca-rebind.sh
lines: 345
title: An environment id could start with a dash and read as a flag

**Problem:** The id regex allowed a leading `-` before `--environment <id>`.

**Fix:** The first character must be a letter or digit; case and mutant rebind-env-dash.

### 9
status: applied
severity: P3
agent: comment-analyzer
category: Comments
confidence: 85
action_class: mechanical
file: plugins/cepa/scripts/orca-send.sh, plugins/cepa/scripts/orca-health.sh, plugins/cepa/scripts/orca-rebind.sh, plugins/cepa/scripts/orca-lane.sh, plugins/cepa/skills/autonomy/SKILL.md
title: Comments overstated or named things that do not exist

**Problem:** `FAILED_SHOWS` does not exist; "`ok: false` is never read back" covers any non-true `ok`; rule 1's match description was looser than the code; the re-bind did not say more than 5 hosts ask unnamed; measurements lacked their commands.

**Fix:** Each corrected; rule 1 now cites the header for the match rules instead of restating them; probes named beside the measurements.

### 10
status: applied
severity: P3
agent: previous-comments-reviewer
category: Tracking
confidence: 70
action_class: mechanical
file: memory/tasks.d/2026-11-03-fix-matrix-check-full.md
title: L73 item 5 stayed open though this PR resolves it

**Problem:** The shard still listed the lost-drain item as open P2.

**Fix:** Struck through with a pointer to L74 / PR #138. The punch-list entry is coord@main's to update.

### 11
status: deferred
severity: P3
agent: comment-analyzer
category: Docs
confidence: 70
action_class: judgment
file: plugins/cepa/skills/autonomy/SKILL.md
title: Rule 1's `on:` bullet restates details the script header owns

**Problem:** The value grammar, nudge skip and "not measured" note sit in both rule 1 and the orca-send.sh header (cite-once rule).

**Fix:** Cut the bullet to what a session does (add `on:`, expect no nudge) and cite the header. Deferred: a wording choice the coordinator can make with the next rule 1 edit.

### 12
status: skipped
severity: P3
agent: security-sentinel
category: Operations
confidence: 40
action_class: judgment
file: plugins/cepa/skills/autonomy/SKILL.md
title: Rule 8 relies on the session picking a fresh UUID

**Problem:** A reused id replays an old batch.

**Fix:** Not taken: a `$(…)` id is not in the command text, so a lost drain could not be replayed with the same id, which is the point of L74. A reuse gives duplicates, never a loss (adversarial reviewer traced it).

### 13
status: deferred
severity: P3
agent: pr-test-analyzer
category: Tests
confidence: 60
action_class: mechanical
file: scripts/check-orca-nudge.sh, scripts/check-orca-lane.sh, scripts/check-orca-turn-endings.sh
title: Uncovered branches in the new legs

**Problem:** No case for the 10-show cap on failed dispatches (and acked rows not counting toward it), the highest-sequence pick among two matching rows, `on:` with a reply, two omitted hosts with the second live, two environments matching one host, two lane reads overwriting the note, and a PEEK pin on the replay sentence.

**Fix:** Add those cases with a mutant each. Residual 9 in the shard.

### 14
status: deferred
severity: P3
agent: previous-comments-reviewer
category: Reliability
confidence: 50
action_class: judgment
file: plugins/cepa/scripts/orca-send.sh
title: The read-back cannot tell this send from an identical one to the same recipient in two minutes

**Problem:** A failed send whose twin (same type, subject, body, recipient) was stored a minute before reads as stored.

**Fix:** A pre-send inbox read to exclude existing ids would close it at one call per send. Stated as a limit in the header; residual 10.

### 15
status: deferred
severity: P3
agent: previous-comments-reviewer
category: Learning
confidence: 60
action_class: judgment
file: docs/solutions/
title: A host or scope relaxation needs a measured round trip before it fails open

**Problem:** Three relaxations in this PR rest on sender reports; review caught two that failed open.

**Fix:** Run `/cepa:compound` for it. Residual 11.

---

**Summary:** 15 findings (0 P1, 3 P2, 12 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
