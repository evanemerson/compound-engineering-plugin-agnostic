---
date: 2026-11-02T21:41:14
scope: fix/roles/orca-full-reads (PR #131)
branch: fix/roles/orca-full-reads
agents:
  - adversarial-reviewer
  - previous-comments-reviewer
  - silent-failure-hunter
  - pr-test-analyzer
summary:
  total: 11
  p1: 1
  p2: 2
  p3: 8
  pending: 0
  ready: 0
  skipped: 1
  applied: 4
  deferred: 6
  completed: 0
agents_skipped:
  - agent: security-sentinel
    rule: "no auth, PHI or payment surface: Orca CLI reads in bash plus test checkers"
  - agent: python-reviewer
    rule: "no Python application code: the Python is test tooling, covered by pr-test-analyzer"
  - agent: performance-oracle
    rule: "no queries or request paths"
  - agent: data-integrity-guardian
    rule: "no migrations or models"
  - agent: schema-drift-detector
    rule: "no models, migrations, serializers, forms or admin"
  - agent: frontend-reviewer
    rule: "no templates, JS/CSS or components"
  - agent: deployment-verifier
    rule: "nothing deploys from this repo; the change is plugin content"
  - agent: architecture-reviewer
    rule: "no module boundary change: flag and guard edits inside three existing scripts"
conditional_dispatch:
  - agent: adversarial-reviewer
    dispatched: true
    signal: "diff is about 300 changed lines and changes fail-closed alert paths"
  - agent: reliability-reviewer
    dispatched: false
    reason: "signal absent: no queue, webhook, lock, transaction or network code; adversarial-reviewer covered the Orca read paths"
  - agent: previous-comments-reviewer
    dispatched: true
    signal: "todos/review-*.md exist; the diff fixes punch-list L72"
deploy_verdict:
  verdict: not-evaluated
  basis: "deployment-verifier skipped: nothing deploys from this repo"
  conditions: []
learnings_research: "ok — no solution corpus (docs/solutions absent); briefing from CLAUDE.md, memory/tasks.d, todos"
detection_signals:
  matched_docs: 0
  docs_with_detection: 0
  signals_passed: 0
  corpus: absent
  note: "docs/solutions/ does not exist in this worktree (docs/ is gitignored)"
  sources: []
  backfill_candidates: []
  suspect_bullets: 0
cepa_local_md: "missing — the stack was inferred (bash scripts + Python test tooling)"
---

# Review Findings — 2026-11-02 21:41

## Findings

### 11
- status: applied
- severity: P1
- agent: tab37@roles (live worker_done send, after the agent review)
- category: Fail-open delivery
- confidence: 95
- action_class: mechanical
- file: plugins/cepa/scripts/orca-send.sh
- lines: 768-779
- title: orchestration send and reply print a concise view too, so every send reported "no message stored"

**Problem:**
This worker's own worker_done through orca-send.sh exited 5 ("the reply
has no result.message.id") while Orca stored it (msg_c4179f7118ad). A
measured send without `--full` prints `{"messageId", "warnings"}`, so
every send on 1.4.246 reads as failed and asks the session to paste a
duplicate.

**Fix:**
`--json --full` on the send, worker_done and reply calls (send measured
with one self-addressed message replayed under the same request id; reply
on its `--help` alone). New case `STORE send output in the 1.4.246 short
shape` and three drop-`--full` mutants.

### 1
- status: applied
- severity: P2
- agent: silent-failure-hunter
- category: Test tooling
- confidence: 80
- action_class: mechanical
- file: scripts/fixtures/orca-short-shape.py
- lines: 73-79
- title: short() returned the full record on any exception, so a broken fixture could pass vacuously

**Problem:**
`except Exception: return text` handed a script the full record whenever
`_short` raised on an ok record of a known verb. A script that dropped
`--full` would then pass its cases.

**Fix:**
Only a JSON decode error passes the text through. An ok record of a known
verb that cannot be shortened now raises, so its checker fails loudly.

### 2
- status: applied
- severity: P3
- agent: silent-failure-hunter
- category: Fail-closed
- confidence: 80
- action_class: mechanical
- file: plugins/cepa/scripts/orca-health.sh
- lines: 690-698
- title: Non-object inbox rows were dropped before the short-shape guard

**Problem:**
`rows = [x for x in rows if isinstance(x, dict)]` ran first, so a list of
strings became empty and read `ok`.

**Fix:**
The guard now treats any non-object row as unreadable, and the filter is
gone. New case `HEALTH inbox row that is not an object`; the
`health-inbox-shape-loose` mutant kills it.

### 3
- status: applied
- severity: P3
- agent: previous-comments-reviewer
- category: Consistency
- confidence: 75
- action_class: mechanical
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 2081-2086
- title: §12b rule 2 defines the named Run by a run-current read without --full

**Problem:**
handoff.md now passes `--full`, but rule 2, which owns the definition,
said nothing, so a coordinator reading run-current by hand saw no holder.

**Fix:**
Rule 2 now says once that every orchestration read whose fields a session
uses passes `--json --full` (L72), citing the scripts' headers.

### 4
- status: deferred
- severity: P2
- agent: adversarial-reviewer, pr-test-analyzer
- category: Measurement gap
- confidence: 45
- action_class: judgment
- file: plugins/cepa/skills/autonomy/SKILL.md
- lines: 2213, 2561-2568
- title: orchestration check (rules 5 and 8, nudge text) was not measured with message rows; no --full

**Problem:**
`check --help` lists `--full` ("instead of the concise view"). On an empty
batch the concise view drops `runId`, `dispatchId`, `count`,
`acknowledged`. If its message rows follow inbox's concise view, a
coordinator's `check --wait` reads a worker_done body cut to 200 chars.
No script reads `check`, so no test covers it.

**Fix:**
Measure `check --peek --json` with and without `--full` while a message
waits; if concise, add `--full` to rules 5 and 8 and to orca-nudge.sh's
nudge text (and the checker's `TEXT`). The scripts' headers now state this
was not measured.

### 5
- status: deferred
- severity: P3
- agent: adversarial-reviewer
- category: Fail-closed scope
- confidence: 35
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: 853-857
- title: One inbox row without to_handle makes every send in the window unconfirmed

**Problem:**
The guard rejects the whole 200-row window. If a full row ever omits
`to_handle`, every later send reports exit 5 until the row ages out. The
three full rows measured all carried the key.

**Fix:**
Detect the short shape positively (a row with `to`/`from` and no
`to_handle`/`from_handle`), or check only the sent id's row.

### 6
- status: deferred
- severity: P3
- agent: adversarial-reviewer
- category: Fail-closed scope
- confidence: 30
- action_class: judgment
- file: plugins/cepa/scripts/orca-health.sh
- lines: 691-698
- title: Health inbox guard requires thread_id and created_at keys that may be nullable

**Problem:**
If Orca omits a null `thread_id` instead of writing null, every health run
alerts `orca-unreadable:inbox` and skips all question checks.

**Fix:**
Same positive detection as finding 5, or commit one raw full inbox row
from 1.4.246 as the fixture's evidence.

### 7
- status: deferred
- severity: P3
- agent: silent-failure-hunter
- category: Error wording
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: 851-852
- title: An inbox re-read with ok:false reads as "not stored", not "unconfirmed"

**Problem:**
Pre-existing: `rows = [] if ok is not True`, so the send reports "not in
the inbox" and the session may paste a duplicate. The `STORE inbox not ok`
case pins today's wording.

**Fix:**
Exit 2 (unconfirmed) when `ok` is not true, and move the case.

### 8
- status: deferred
- severity: P3
- agent: adversarial-reviewer, silent-failure-hunter
- category: Compatibility
- confidence: 60
- action_class: judgment
- file: plugins/cepa/scripts/orca-send.sh
- lines: 215-232
- title: An Orca that rejects --full fails every send, rebind and health read

**Problem:**
Unmeasured: no Orca older than 1.4.246 was at hand. If one rejects
`--full`, the failure is closed but reads as "no message stored".

**Fix:**
Name an unknown-flag error in the failure text, once an older Orca can be
measured.

### 9
- status: deferred
- severity: P3
- agent: pr-test-analyzer
- category: Test fidelity
- confidence: 50
- action_class: mechanical
- file: scripts/fixtures/orca-short-shape.py
- lines: 47-60
- title: Short transform omits some measured short-only fields (agent, workspace, host, scope, warnings)

**Problem:**
No script reads them, so no case depends on them today; a future reader
of a short reply would see a less faithful stub.

**Fix:**
Emit the measured short keys for worker-list and worker-show; add one
case per single missing key (`thread_id`) in the health guard.

### 10
- status: skipped
- severity: P3
- agent: previous-comments-reviewer
- category: Tracking
- confidence: 90
- action_class: judgment
- file: memory/tasks.d/2026-10-02-punch-list.md
- lines: 2095
- title: L72 is still pending in the punch list

**Problem:**
The punch list still shows L72 pending, and L63 waits on it.

**Fix:**
Not this worker's write: coord@main is the punch list's only writer. It
closes L72 after merge.

---

**Summary:** 10 findings (0 P1, 2 P2, 8 P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
