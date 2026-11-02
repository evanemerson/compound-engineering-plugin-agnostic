---
date: 2026-11-02T09:41:19
scope: feat/gain/coord-outbox
branch: feat/gain/coord-outbox
pr: 127
agents:
  - adversarial-reviewer
  - security-sentinel
  - reliability-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
agents_skipped:
  - agent: learnings-researcher
    reason: "worker run on its own PR; the design doc's plan review (todos/review-2026-11-02-085725-main.md) already carried the learnings briefing for this design"
  - agent: python-reviewer
    reason: "no Python module in the diff; embedded Python is in shell heredocs, covered by the five readers"
  - agent: frontend-reviewer
    reason: "no templates, JS or CSS in the diff"
  - agent: schema-drift-detector
    reason: "no models, migrations, serializers, forms or admin in the diff"
  - agent: data-integrity-guardian
    reason: "no migrations or database code in the diff"
  - agent: performance-oracle
    reason: "no ORM, query or frontend code in the diff"
  - agent: architecture-reviewer
    reason: "scope set by the approved design doc and its 25-finding plan review"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "large diff (1670 lines): write-ahead outbox, resolver over Orca, relay of stored bodies"
  - agent: reliability-reviewer
    dispatched: true
    signal: "delivery semantics: outbox, external Orca calls, races between senders and drains"
  - agent: previous-comments-reviewer
    dispatched: false
    reason: "the only prior review touching this design is the plan review, all 25 applied to the design doc; its decisions were read directly as binding inputs"
deploy_verdict: not-evaluated
deploy_verdict_basis: "deployment-verifier skipped: no config, dependency, Docker or migration files"
learnings_research: "skipped — worker review of its own PR (see agents_skipped)"
detection_signals:
  count: 0
  source_docs: 0
  backfill_candidates: 0
  suspect_bullets: 0
  corpus: not-consulted
config: "no cepa.local.md in this repo; stack inferred (bash + embedded Python, Markdown skills)"
summary:
  total: 26
  p1: 3
  p2: 8
  p3: 15
  pending: 12
  ready: 0
  skipped: 0
  applied: 14
  deferred: 0
---

# Review Findings — 2026-11-02 09:41

PR #127, `feat/gain/coord-outbox` (punch-list L61). Reviewed at 271a460;
fixes applied in the commit that adds this file.

## Findings

### 1
- status: applied
- severity: P1
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 100
- action_class: mechanical
- file: scripts/check-orca-outbox-controls.sh
- title: The drain's relay guard had no mutant

**Problem:**
None of the OUTBOX mutants touched `read()`: the name pattern, the mode, size, header, field and target checks could each be deleted with the controls green. The checker planted one bad file.

**Fix:**
Applied: seven more planted shapes (size, wrong target, bad field, missing `---`, a pending name with `.to-`, a delivered file in a bad shape, a symlink), and one mutant per guard clause (guard-mode, guard-size, guard-target, guard-dashes, guard-field, guard-name-pairing). The S_ISREG test has no mutant: a symlink's lstat mode is never 600, so the mode test refuses it first (stated in the controls header).

### 2
- status: applied
- severity: P1
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 100
- action_class: mechanical
- file: plugins/cepa/scripts/orca-outbox.sh
- title: The drain printed "none" when it could not read the outbox

**Problem:**
`listing()` turned every OSError into `[]`, so a directory that was unreadable, a symlink or another owner's printed `ORCA outbox: none` and exit 0.

**Fix:**
Applied: only a missing directory is empty; anything else prints `ORCA outbox failed: …` and exits 5. Case "DRAIN an outbox directory it cannot trust fails, never none" and mutant listing-trusts-any-dir.

### 3
- status: applied
- severity: P1
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 100
- action_class: mechanical
- file: scripts/check-orca-outbox.sh
- title: No case read the target= line of an alert orca-send.sh wrote

**Problem:**
Dropping `coord:` from the alert writer's target regex, or its slug check, wrote `target=invalid` and the controls stayed green.

**Fix:**
Applied: every RESOLVE case with an alert asserts `target=coord:dpc-pro`; the TARGET cases already assert `invalid`. Mutants alert-coord-target and alert-slug-unchecked.

### 4
- status: applied
- severity: P2
- agent: security-sentinel, adversarial-reviewer
- category: Security
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/orca-outbox.sh
- title: The drain relayed bodies with only C0 controls replaced

**Problem:**
Tag characters, zero-width, bidi, C1 and U+2028/2029 passed through, and a body line could fake `ORCA outbox file:` or `Ending first line:`. The repo rule says strip, never merely label, at every relay point.

**Fix:**
Applied: the script strips mechanically before the session's own strip. Characters in categories Cc, Cf, Cs, Co, Cn, Zl, Zp (but tab) print as `?`; each body line prints after `  | `; a line with one of the script's prefixes is removed and counted on `orca: stripped N reserved-prefix line(s) in <file>`. Rule 8 says so. Mutants strip-off and unicode-c0-only.

### 5
- status: applied
- severity: P2
- agent: reliability-reviewer, adversarial-reviewer, silent-failure-hunter
- category: Reliability
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/orca-send.sh
- title: A prune alert went to the session that pruned, and the file was deleted first

**Problem:**
The `outbox_pruned` alert took the pruner's repo and worktree, so neither the sender nor the target saw it; and the file was removed before the alert was written, with the result discarded.

**Fix:**
Applied: the alert carries the file's own `repo=` and `worktree=`; the file is removed only after `Orca alert recorded`, else it is kept and a line says so. A failed clock prints `prune skipped`. Case "PRUNE an alert names the pruned file's own sender", mutant prune-pruner-owner.

### 6
- status: applied
- severity: P2
- agent: reliability-reviewer, silent-failure-hunter
- category: Reliability
- confidence: 85
- action_class: corroborated
- file: plugins/cepa/scripts/orca-outbox.sh
- title: A body that is not valid UTF-8 was skipped, and an all-skipped outbox read as none

**Problem:**
The writer saves raw bytes; the readers raised on decode and treated the file as unknown-shape, never shown, then pruned. With only skipped files the drain printed `none`.

**Fix:**
Applied: both readers decode with `errors="replace"`; with nothing shown but skipped files the drain exits 1 with `check the outbox; N file(s) … could not be shown`. Mutant none-when-skipped.

### 7
- status: applied
- severity: P2
- agent: adversarial-reviewer
- category: Reliability
- confidence: 70
- action_class: judgment
- file: plugins/cepa/scripts/orca-outbox.sh
- title: A message being sent showed as pending in the receiver's drain

**Problem:**
The file is written pending before the resolver; a live receiver draining in that window showed it, the operator acked it, and Orca then delivered it again.

**Fix:**
Applied: the drain holds back pending files under 10 minutes old and prints a count. Mutant fresh-shown. (The staging-directory variant the reviewer proposed was not taken: it adds a status.)

### 8
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 85
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- title: An outbox root that could not be read gave ORCA health ok

**Problem:**
`os.path.isdir` swallowed EACCES and a symlinked root was skipped, so health printed ok while files waited.

**Fix:**
Applied: lstat the root; only a missing one is empty, anything else raises `orca-unreadable:outbox-dir`.

### 9
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 100
- action_class: mechanical
- file: scripts/check-orca-outbox.sh
- title: The exit-6 ending line was never asserted

**Problem:**
The ending line could be deleted or changed and the check stayed green.

**Fix:**
Applied: every pending RESOLVE case asserts the exact last line. Mutant pending-ending.

### 10
- status: applied
- severity: P2
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 100
- action_class: mechanical
- file: scripts/check-orca-outbox.sh
- title: An unproven send (exit 5) had no case

**Problem:**
A mutant that marked an unproven send refused (or delivered) would lose or misfile the message unseen.

**Fix:**
Applied: case "RESOLVE an unproven send stays pending", mutant unproven-refused.

### 11
- status: applied
- severity: P3
- agent: adversarial-reviewer
- category: Correctness
- confidence: 75
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- title: A repo whose directory name is not a slug never resolved

**Problem:**
Rule 2 writes the raw directory name in the objective (`foo.bar coord@main`); senders address `coord:foo-bar`, and the resolver matched only the slug text.

**Fix:**
Applied: the resolver slugs the objective's first word. Case "RESOLVE an objective named by the raw directory matches its slug", mutant objective-raw-name.

### 12
- status: applied
- severity: P3
- agent: security-sentinel, reliability-reviewer
- category: Security
- confidence: 90
- action_class: corroborated
- file: plugins/cepa/scripts/orca-send.sh
- title: refused/ and delivered/ were made without umask 077

**Problem:**
Both subdirectories were created with the caller's umask (755 under 022). The parent is 700, so this was hygiene only.

**Fix:**
Applied: `( umask 077 && mkdir -p … )` at both sites.

### 13
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 75
- action_class: mechanical
- file: plugins/cepa/scripts/orca-outbox.sh
- title: A delivered file said "not live now" when liveness was unknown

**Problem:**
When the terminal or ps read failed, every delivered file was shown with a false claim.

**Fix:**
Applied: the line says `liveness unknown (an Orca read failed)`.

### 14
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/scripts/orca-outbox.sh
- title: A header time parsed late could crash the whole drain

**Problem:**
`gmtime(int(time))` ran in the print loop, so one bad file would block every message.

**Fix:**
Applied: the time is parsed inside `read()`; a failure is a skipped file.

### 15
- status: pending
- severity: P2
- agent: adversarial-reviewer
- category: Reliability
- confidence: 85
- action_class: judgment
- file: plugins/cepa/scripts/orca-outbox.sh
- title: A new coord@main is shown every message its predecessor already handled

**Problem:**
Plan-review #10 shows delivered files whose handle is not live. A live receiver reads them from its Orca inbox and never acks the outbox file, so after a restart the new coord@main is shown all of the last 7 days' messages, already handled. A stale `merge_ready` invites a second merge.

**Fix:**
Recommended: record the stored `msg_` id in the delivered name, and show a delivered file only when that message is unread in Orca (or Orca cannot be read). Needs a measured read of a dead handle's inbox state. Not applied: it changes #10's rule.

### 16
- status: pending
- severity: P3
- agent: security-sentinel, reliability-reviewer
- category: Reliability
- confidence: 75
- action_class: corroborated
- file: plugins/cepa/scripts/orca-outbox.sh
- title: The drain has no cap on files or bytes shown

**Problem:**
Each file may hold 28 KB; a looping or hostile sender fills the coordinator's context and the operator question.

**Fix:**
Recommended: show at most 10 files or 64 KiB per turn and print `N more not shown`.

### 17
- status: pending
- severity: P3
- agent: reliability-reviewer
- category: Reliability
- confidence: 75
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- title: The coord: path's worst-case wall time is over 10 minutes

**Problem:**
Up to 20 run-list pages plus four more calls, each 34 s with its retry: about 800 s, past the 600 s tool bound. The file stays pending, so nothing is lost, but the sender gets no line.

**Fix:**
Recommended: a total deadline (about 90 s) checked before each resolver call; past it, `pending outbox_unreadable`.

### 18
- status: pending
- severity: P3
- agent: security-sentinel
- category: Correctness
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- title: `_invalid`, `refused` and `delivered` are valid coord: repos

**Problem:**
A repo named `_invalid` collides with the invalid-target directory; one named `refused` or `delivered` collides with a status subdirectory name inside the reader's listing.

**Fix:**
Recommended: refuse those names as `<repo>`.

### 19
- status: pending
- severity: P3
- agent: reliability-reviewer, adversarial-reviewer
- category: Reliability
- confidence: 70
- action_class: corroborated
- file: plugins/cepa/scripts/orca-send.sh
- title: A `.new.*` file left by a killed sender is never pruned or reported

**Problem:**
Neither the drain, health nor the prune looks at `.new.*`, so they accumulate.

**Fix:**
Recommended: prune `.new.*` older than an hour.

### 20
- status: pending
- severity: P3
- agent: reliability-reviewer
- category: Reliability
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- title: Each pending send with an alert kind writes its own alert

**Problem:**
N ambiguous or unreadable sends make N alerts, each acked by its own key.

**Fix:**
Recommended: key resolver alerts by kind, target and UTC hour, as health keys other repeating alerts.

### 21
- status: pending
- severity: P3
- agent: reliability-reviewer
- category: Reliability
- confidence: 70
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- title: A coord: send that fails (exit 5) still says to paste the block

**Problem:**
The file stays pending and the drain owns it; pasting the block makes a second outbox file and a second send.

**Fix:**
Recommended: for a coord: target, the exit-5 ending says the message waits in the outbox and must not be re-sent.

### 22
- status: pending
- severity: P3
- agent: adversarial-reviewer
- category: Correctness
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/orca-outbox.sh
- title: Two repos whose names slug the same share one outbox

**Problem:**
`foo.bar` and `foo-bar`, or two clones named alike, drain one directory and resolve as ambiguous.

**Fix:**
Recommended: state it as a limit in the orca-send.sh header and rule 1, or add a repo identity (common-dir hash) to the header.

### 23
- status: pending
- severity: P3
- agent: security-sentinel
- category: Compliance
- confidence: 50
- action_class: judgment
- file: plugins/cepa/scripts/orca-outbox.sh
- title: Drained bodies stay on disk for 7 days; the PHI rule is prose only

**Problem:**
A mistaken send from a PHI repo leaves the body at rest (mode 600) for a week.

**Fix:**
Recommended: delete a file on ack (or keep `.drained` 24 h), and consider refusing bodies that match the repo's PHI scrub patterns.

### 24
- status: pending
- severity: P3
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 60
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- title: An outbox write that fails loses the text without saying so

**Problem:**
The message file is removed before the outbox copy exists, so an outbox-write refusal destroys the only copy; the reason says only "could not be written".

**Fix:**
Recommended: add "the message text is lost; write a new file" to that reason (and to REASONS).

### 25
- status: pending
- severity: P3
- agent: silent-failure-hunter
- category: Silent failure
- confidence: 50
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- title: A dropped `hasLivePty` field would read as "no live coord@main", with no alert

**Problem:**
If Orca renames the field, every coordinator reads as not live and sends stay pending without an alert; a failed move to refused/ also leaves a refused message pending.

**Fix:**
Recommended: when coordinators are claimed and no agent row carries `hasLivePty`, return `outbox_unreadable`; raise an alert when the refused move fails.

### 26
- status: pending
- severity: P3
- agent: pr-test-analyzer
- category: Test coverage
- confidence: 75
- action_class: mechanical
- file: scripts/check-orca-outbox.sh
- title: Smaller coverage gaps remain

**Problem:**
No mutant kills a wrong `--type` or a dropped `--retry-request` in the send argv; no case for the ack's `-f/-L/-O` guard, a pane with two agent rows, the 7-day boundary to the hour, the drain's exit-5 crash path, or a coord@main sending to itself.

**Fix:**
Recommended: add those cases and one mutant each.

---

**Summary:** 26 findings (3 P1, 8 P2, 15 P3); 14 applied, 12 pending.
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
