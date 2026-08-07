# Residuals — chore/reconcile-residual-sink

## 2026-08-06 — reconciling `memory/tasks.d/` against the tree

No review run. This was a direct audit: every open checkbox in the sink read
against the current tree rather than trusted, after two reported symptoms
turned out to be samples of one defect.

**Before: 75 open boxes. After: 51, every one verified open against the tree.**
30 boxes were removed as record error and 6 were *added* (see the inverse
defect below), netting −24. No work was done to close any of the 30 — none of
it was work anyone still had to do. Measured, not estimated:
`git stash && grep -rhc '^- \[ \]' memory/tasks.d/ | paste -sd+ | bc`.

### The two reported symptoms and what they actually were

- `grep -rn "^- \[ \] ~~"` returned **3** items whose prose was struck through
  while the box stayed open, all in
  `2026-08-01-feat-mutation-sweep-harness.md`. Each sits directly *below* its
  own `- [x] **RESOLVED <date>**` entry — the file's own convention, followed
  correctly six times and broken three. The content was right; only the byte a
  consumer parses was wrong.
- `2026-08-01-chore-plan-review-mutation-sweep.md:102` claimed the weekly sweep
  had no named observer. `.github/workflows/mutation-sweep.yml` has shipped one
  since day one (`permissions: issues: write`, plus an
  `if: failure() || cancelled()` step that opens or updates a tracking issue —
  and the `cancelled()` half exists specifically because a timeout is not a
  failure). The triage section **100 lines below it in the same file** already
  recorded it fixed.

### What the audit found beyond the report

The second symptom was not an isolated stale item. It sat inside a block whose
own header reads *"Do not read their checkboxes as current."* **Eighteen** open
boxes were covered by that sentence. A blockquote is not a status field: a
consumer greps `^- \[ \]`, and the disclaimer is invisible to it. That single
block was 18 of 75 boxes — a quarter of the entire backlog — and none of it was
work.

Three more, each verified against the tree:

- `2026-07-29-docs-compound-restatement-drift.md` — the `model-pins.yml:8-10`
  "heuristic and only warns" comment. **Fixed in PR #27 on 2026-07-30**; the
  workflow now cites §9f instead of describing the checker. The closure was
  recorded in a *different* shard's "Applied this run" section. Open for seven
  days.
- `2026-08-01-feat-mutation-sweep-harness.md` — "`exit 3` and the detector's
  `UNVERIFIED` have no rule in §9f". **Shipped in `d28ae7a` (1.18.1)**: §9f now
  carries a four-row exit-code table and an explicit paragraph resolving the
  UNVERIFIED collision, in the very words the residual asked for. Open across
  three subsequent PRs.
- `2026-08-01-chore-plan-review-mutation-sweep.md` deferred #2 and #13 — both
  answered on the branch the deferral pointed at, recorded in that branch's
  shard, never walked back here.

**And the inverse defect, previously unreported.** Both 2026-08-06 shards
(`checkout-node24-bump`, `derive-changelog-on-release`) were written with plain
`- **P2 —**` bullets instead of checkboxes. Six genuinely-open items — including
the node24 runtime P2 — were invisible to the same scan that was over-reporting
elsewhere. Every earlier shard uses checkboxes, and `2026-08-02` uses `- [x]`,
so this is drift, not a convention change. Restored to `- [ ]`.

The sink was therefore wrong in **both** directions at once, which is why a
count of open boxes had stopped being evidence about anything.

### What was applied

- 3 struck-prose items → `- [x]`, keeping the strikethrough and the paired
  RESOLVED entry (the file's established convention).
- 3 verified-shipped items → `- [x]` with the shipping commit or PR named and a
  dated re-verification against the tree.
- 18 superseded review-time items → **plain bullets, not `- [x]`**. Marking them
  complete would be the other wrong answer: 5 were skipped and several were
  mooted when the per-PR fast path was deleted. Evidence is not a task, so it no
  longer carries a task's syntax.
- 4 duplicate boxes (plan-review #12/#20/#21/#23, PR #25's finding-#4
  cross-reference) → pointers naming the owning shard, per `cepa:autonomy` §5
  dedup. One item, one box.
- 6 open items in the 2026-08-06 shards → `- [ ]`.

### Open, verified against the tree this run (not closed here)

Each was re-read at its cited construct, not taken from its own description:

- **Leg 4 still scopes to `§N<letter>` by construction** — bare `§N` (§7 among
  them) is out of scope, stated inline in the checker. The `§8`/`§5`/`§4`
  citations still do not resolve.
- **The line-wrapped-qualifier hole is live** — `CITE_RE` is still matched by
  line-based `grep`.
- **`--selftest` is still wired only to `mutation-sweep.yml`**, never to
  `model-pins.yml`; the PR gate remains a week behind.
- **`mutation-sweep.yml`'s selftest step still has no `timeout-minutes`** — the
  job carries 180 and the sweep step 150, so it is still the only unbounded
  step, and it is the one containing deliberate multi-second hang fixtures.
- **`brain-client.sh:32` still resolves `.env.local` CWD-relative**
  (`${BRAIN_ENV_FILE:-.env.local}`), while `:128` uses `show-toplevel` for the
  participant manifest — the asymmetry the residual describes.
- **`compound.md:35` still prescribes `git diff <trunk>...HEAD`**, and its only
  residual-routing mention (`:185`) is still inside the brain-writeback step.
- **CLAUDE.md's version-scope rule still names only plugin content**, not
  `scripts/`.
- **Control ids are still unique today** (`--list | uniq -d` empty) and `reg()`
  still does not enforce it.
- **`check-model-pins-controls.sh`'s trap is still flagless** (`trap cleanup
  EXIT INT TERM`), so an interrupt still misattributes remaining cases to the
  checker.
- **`--only` still exits 0** on a passing subset, deliberately.
- **`registry.sh` still has `l2-grep-binary` and `l2-grep-rc` both citing
  `check-model-pins.sh:311`** — the STATED LIMIT line-vs-content gap.

### The durable lesson

The pattern reached **seven occurrences** with this audit and finally has a
solution doc. Its Detection section is the deliverable, because every instance
so far was found by a human reading prose and noticing it disagreed with a
field — which does not scale and did not happen for seven days, seven days, and
three PRs respectively in the three cases above.

Worth stating plainly: this sink's consumers (`/cepa:sweep`,
`/cepa:triage`) read the box. Every phantom item is a unit of attention
spent re-deriving that nothing is wrong, and the derived signal — "the backlog
is growing" — was measuring record decay, not work.
