# Residuals — chore/plan-review-mutation-sweep

## 2026-08-01 — `/cepa:plan-review` of the mutation-sweep harness plan

Plan reviewed: `docs/plans/2026-07-31-mutation-sweep-harness.md` (gitignored —
`docs/` is local by convention, so the plan revisions are local-only and this
shard plus `todos/review-2026-08-01-000851.md` are the tracked record).

Panel of six personas (coherence, feasibility always-on; scope-guardian,
security-lens, product-lens, adversarial all activated). No persona failed, no
finding dropped below anchor, no SUSPECT block stripped. Origin downgraded to
`none` — the plan cites a residual shard, which is neither an approved design
doc in `docs/plans/` nor a scope-pinning issue — so premise scrutiny was on.

28 findings (14 P1, 11 P2, 3 P3). 9 applied to the plan, 19 pending triage.

> **Status of everything in this section is SUPERSEDED by the triage section at
> the bottom of this file.** The lists below are the review-time snapshot and are
> kept as evidence; 8 were subsequently fixed and 5 skipped. The triage section
> is authoritative for what is open.
>
> **The items below are deliberately NOT checkboxes** (reconciled 2026-08-06).
> They were `- [ ]` until then, and this warning — which asked the reader not to
> read those checkboxes as current — was the only thing standing between them
> and a consumer. A consumer greps `^- \[ \]`; it does not read blockquotes. The
> 18 open boxes in this section were phantom work for five days, and one of them
> (the weekly sweep's "no named observer") was contradicted by the triage
> section 100 lines further down in the same file *and* by
> `.github/workflows/mutation-sweep.yml`, which has shipped an observer since
> day one. Evidence is not a task, so it no longer carries a task's syntax.
> Marking them `[x]` would have been the other wrong answer: 5 were skipped and
> several were mooted when the fast path was deleted, and none of that is
> "completed".

### The headline: the plan's central mechanism does not work as written

Three independent personas reproduced it. The controls harness runs a **baseline
gate before its runner loop** and FATALs if the mutated checker's verdict on the
clean tree is not 0 MISS / 0 WARN. For every mutant that changes the verdict on
the repo's own content — roughly a third of them — **zero controls execute**. A
driver classifying on exit status scores that CAUGHT and reports green having
proven nothing.

Two more of the same shape, both measured, both now fixed in the plan:

- `--only` matches on **commas**; the plan declared `expect` space-separated.
  Every multi-control mutant would have selected nothing, hit
  `FATAL: no controls ran`, exited 1 — and been read as a kill. The fast path
  would have been uniformly, silently green.
- `expect: SURVIVOR` is not a control id, so the two declared survivors would
  have taken the same path and been misclassified as CAUGHT — inverting the exact
  accounting D4 exists to produce.

**All three are the plan's own subject matter happening to the plan**: a
verification artifact reporting success because it checked nothing. Recorded here
because the pattern held for a fourth time in this thread, at design stage rather
than at implementation.

### At review time — the two contradictions block U2/U3 as designed

- **P1 — how the driver reaches the mutated checker is undecided.**
  `CEPA_PIN_CHECKER` is the harness's purpose-built mutation hook and is
  hard-refused whenever `CI` is set (i.e. exactly where U3 runs). "Copy tree to a
  throwaway dir" also fails as written: the harness resolves its root via
  `git rev-parse --show-toplevel` and builds its fixture from `git ls-files`, so
  a bare file copy exits 2. Panel split: clone including `.git` (or
  `git worktree add`) and leave the hook unset, versus use the hook and add a
  narrow `CEPA_MUTATION_SWEEP=1` exemption to the CI guard. The first touches no
  existing guard but pays a full tree copy per mutant; the second is cheaper and
  uses the documented path but weakens a deliberate control. (findings #2, #10)

- **P1 — whether the per-PR fast path should exist at all.** product-lens
  argues the residual deferred on cadence and named weekly-or-manual as its own
  acceptable answers, neither of which needs an `expect` mapping; dropping the
  fast path removes `expect`, `--only`, and CAUGHT-BY-OTHER — about a third of
  the design — and moots several other findings. The rest of the panel repaired
  the fast path rather than removing it. This is the one decision that changes
  what gets built. (finding #7)

### At review time — correctness of the mechanism (P1)

- Adding `mutation-sweep.yml` **breaks controls 17 and 36** on the first
  commit: both neutralize `model-pins.yml` by name, so a second workflow file
  leaves `.github` still scannable and the expected MISS never appears.
  Reproduced (`2/2 passed` → `FAIL 17` / `FAIL 36`). Fix is to replant both on
  every scannable file under `.github`, in the same commit. (finding #8)
- Mutation confinement to the throwaway copy is unstated; an interrupted run
  can leave a weakened checker in the working tree, whose diff looks like a
  one-line edit. No constraint stops a `target` with `..` or an absolute path
  either. (finding #10)
- `expect` is a list but CAUGHT is defined singular — a partially-firing list
  passes both modes, so a declared control can be dead from birth. (finding #11)
- SURVIVOR declarations are unverified: relabelling a real gap as expected is
  a one-word diff, and D3 guards only the opposite direction. This repo has
  shipped that remedy shape before (deleting a leg-3 marker to quiet the
  checker). (finding #12)
- The driver's classifier ships with one of six outcomes tested — the defect
  this plan exists to detect, one layer down. (finding #13)
- The blocking PR gate contradicts "gaps become residuals": the branch becomes
  unmergeable the moment the harness works. Proposed `SURVIVED-KNOWN-GAP`, valid
  only with a residual-shard reference. (finding #14)

### At review time — scope, cost, record-keeping (P2/P3)

- "§9f already requires every control to name the mutant it kills, so the
  mapping is half-written already" is **measured wrong**: 49 of 57 controls name a
  mutant, and the eight that do not (6, 9, 10a, 10b, 18, L2g, L2h, L3e) are every
  one a zero-MISS false-positive guard — the only controls that can kill a
  loosened predicate. The unwritten half is the half covering the mutant class
  where the checker silently stops catching things. (finding #16)
- `scripts` is a leg-4 citation root and `.sh` is scanned, with no
  prose-suppression hatch: a literal `§N<letter>` in either new file must resolve
  or the baseline reddens and takes the sweep, the controls, and the model-pins
  job down together. (finding #17)
- The weekly run's failure has no named observer — no PR check, no
  notification. The CAUGHT-BY-OTHER mitigation depends on someone reading it.
  Needs `permissions: issues: write` if it files an issue. (finding #19)
- The new workflow drops `model-pins.yml`'s documented security posture (no
  event-data interpolation into `run:`, never `pull_request_target`, no
  secrets) — it carried forward only the mechanical SHA pin and timeout.
  (finding #20)
- A sourced `registry.sh` makes running the sweep on a contributor branch
  equivalent to running that branch's code, before any validation. Trust boundary
  unstated. (finding #21)
- `--allow-dirty` brands every local run INVALID, including U2's own verify —
  the person who needs the sweep is mid-edit by construction. Proposal: split
  "dirty at start" (LOCAL, runs normally) from "changed during the run"
  (INVALID), which also matches the incident that motivated the gate.
  (finding #22)
- The accounting figure is a coverage claim with nothing bounding it; §9f's
  gap table needs a row saying a green sweep is not checker coverage.
  (finding #23)
- No rule for re-anchoring or retiring an ANCHOR-MISSING mutant — deleting it
  is the cheapest route to green CI on exactly the PRs that edit the checker,
  which is how a suite loses coverage silently. §9f already forbids this for
  controls. (finding #24)
- Fast-mode fallback cost is uncapped and correlates with the trigger:
  fallbacks cluster on the PRs that edit the checker. ~8 fallbacks exhaust a
  5-minute budget. (finding #25)
- Advisory (confidence 50, below the auto-apply anchor): `--only` names two
  different things inside U2; "the solution doc" in Out of scope is cited without
  a path. (findings #27, #28)

### Applied this run

Findings 1, 3, 4, 5, 6, 9, 15, 26 (corroborated or mechanical, confidence ≥ 75)
plus 18. Notable:

- `BASELINE-DIRTY` added as a sixth outcome, with the rule that the driver
  classifies by parsing `PASS`/`FAIL <id>` lines and the `-- N/M --` trailer,
  never by exit status (baseline-abort, no-controls-ran, and a genuine kill all
  exit 1).
- The fixed count of 30 was removed everywhere. U1 mandated "enumerate by
  construct, not by incident history" while also targeting the prior round's
  exact count — an implementer hitting 30 would have enumerated by incident
  history and still passed the stated criterion.
- The opening section no longer claims the cadence question is dissolved. U3 now
  lands `workflow_dispatch` + weekly first, and the per-PR trigger ships only if
  U2's **measured CI** wall-clock comes in under ~4 minutes.
- Local measurements corrected the headline: ~50s, not 40s (there is a fixed
  ~0.6s per invocation for fixture rebuild + baseline run that the original
  arithmetic amortized away).

**Irregularity worth seeing:** finding 18 is `judgment` class and was not
auto-apply eligible, but landed anyway — applying finding 6 left U3's Verify
contradicting the new two-step landing, and the autofix self-review's natural
reconciliation was exactly finding 18's fix. Marked `applied` rather than left
`pending` so triage does not re-apply it.

The self-review also caught three inconsistencies the autofix itself introduced
or left behind: a `### D3. Five outcomes` heading above a six-row table, and two
surviving hardcoded `30`s in D1 and Risks.

---

## 2026-08-01 — `/cepa:triage` of the above (batch mode)

19 pending findings; **zero auto-apply eligible** (18 `judgment`, and the one
`mechanical` sat at confidence 50). Operator decisions: 8 fixed, 6 deferred,
5 skipped. Findings file now has 0 pending.

### The decision that mattered: finding 7 — the per-PR fast path was dropped

Approved. The plan's first draft built a fast path so the sweep could run on every
PR: each mutant declaring which control should kill it, so only that control runs.
Everything expensive in the design existed to serve it — the hand-maintained
mutant→control mapping, `--only` plumbing, a `CAUGHT-BY-OTHER` state, and a
measured-timing gate on the CI trigger.

The reasoning for dropping it: **the control suite can only develop holes when the
checker or the controls change**, which is rare, so a per-PR run mostly re-proves
the previous answer. The mapping was also a second list requiring sync with the
controls — a drift generator whose staleness the design itself could not detect
for up to a week. Roughly a third of the design deleted.

The sweep is now `schedule:` weekly + `workflow_dispatch`. No PR trigger, no gate.
This also leaves `model-pins.yml`'s "Deliberately NOT path-filtered" rationale
untouched rather than contradicted by an opposite convention two files away.

**Operator context that drove it:** stated philosophy is preventing unnecessary
bloat and drift. Recorded because it is the standing tiebreaker for this repo, not
a one-off preference — when a design's cost exists to serve a redundant run,
delete the run.

### Superseded by that decision

Findings 3 and 4 were auto-applied during the review run (comma-joining `expect`;
`SURVIVOR` bypassing `--only`) and are recorded `applied`, but the construct they
fixed no longer exists. Their evidence stands as why the fast path was fragile
enough to question. Findings 11, 14, 16, 25, 27 were skipped and removed for the
same reason — all artifacts of the fast path.

### Fixed in the plan (findings 7, 8, 10, 17, 19, 22, 24, 28)

- Adding any second workflow file **breaks controls 17 and 36** — both neutralize
  `model-pins.yml` by name. Replant both on every scannable file under `.github`
  in the same commit. (Reproduced: `2/2 passed` → `FAIL 17` / `FAIL 36`.)
- Mutation confinement stated: `mktemp -d` outside the repo, `trap EXIT INT TERM`,
  `target` must resolve inside the copy after `readlink -f`. An interrupted run
  must never leave a weakened checker in the working tree.
- `scripts` is a leg-4 citation root with no prose-suppression hatch — the new
  `.sh` files construct any section sign at runtime.
- The weekly job opens/updates a GitHub issue on failure (`permissions: issues:
  write`). A `schedule:` failure produces no PR check and no notification, and
  weekly is now the only run.
- D5 split into two states: **dirty at start** → `LOCAL — not a gate result`, runs
  normally; **changed during the run** → `INVALID`, non-zero exit. The original
  blanket refusal would have branded every useful local run invalid, training the
  operator to read past the banner — the exact misread the gate exists to prevent.
- Re-anchoring rule: an `ANCHOR-MISSING` mutant is re-anchored; retiring one
  requires naming the construct that is no longer mutable. Deleting it to green
  the build is never the fix.
- Out-of-scope now names the solution doc by path.

### Deferred — build-time detail, nothing to decide until the code is written

**Reconciled 2026-08-06.** All six were deferred *toward the build*, and the
build happened on `feat/mutation-sweep-harness`. Two were answered there, one
was folded, and three are live but **owned by that branch's shard** — carrying
an open box in both files is the duplication `cepa:autonomy` §5 dedup exists to
prevent, and it double-counts the backlog. The owner is
`memory/tasks.d/2026-08-01-feat-mutation-sweep-harness.md`.

- [x] ~~**#2 (P1) — how the driver reaches the mutated checker. Must be answered
  before U2 is written.** `CEPA_PIN_CHECKER` is the harness's purpose-built hook
  and is hard-refused whenever `CI` is set; a bare file copy is not a git work
  tree (root via `git rev-parse`, fixture from `git ls-files`), so it exits 2.
  Options: clone including `.git` / `git worktree add` with the hook unset, or use
  the hook and add a narrow `CEPA_MUTATION_SWEEP=1` exemption to the CI guard.~~
  **Answered 2026-08-01 — option (a).** `cp -a` the tree *including* `.git` to a
  temp dir, cwd inside the copy, `CEPA_PIN_CHECKER` left unset. The cost
  objection did not survive measurement (1.7 MB tree + 9.1 MB `.git`, copied
  once per *run*, not per mutant); `git worktree add` was rejected inside option
  (a) because it checks out HEAD and would test the committed checker while the
  operator is mid-edit — the exact moment the sweep matters. Full reasoning and
  its stated consequence: the feat shard, "Decided this run".
- [x] ~~#13 — the classifier's own coverage beyond U2's per-outcome fixtures.~~
  **Closed by `--selftest`** — assertions across every classifier branch, wired
  as its own CI step ahead of the sweep
  (`.github/workflows/mutation-sweep.yml:87-88`). Verified 2026-08-06.
- [x] ~~#12 — nothing machine-checks a `SURVIVOR` declaration beyond D4's
  stated-limit reference; relabelling a real gap as expected is a one-word
  diff.~~ **Not closed — folded**, and tracked at its owner. The driver now
  enforces a floor (the cited `<file>:<line>` must live in the mutant's own
  target and still carry the words `STATED LIMIT`), which is #12's floor, not
  its ceiling. Live as "nothing machine-checks that a `SURVIVOR` declaration is
  *honest*" in the feat shard, refined there by a further finding: two mutants
  cite the same line whose two claims sit on separate lines.
- #20 — whether the workflow header rules belong in prose or a shared include.
  **Still open**; box lives in the feat shard.
- #21 — whether the registry should be data rather than sourced shell.
  **Still open**; box lives in the feat shard.
- #23 — exact wording of §9f's gap-table row. **Partially done and still open**:
  a row was written and is live in §9f ("Which control kills which mutant is
  prose, in both files, checked by nobody"), but its wording is not settled.
  Box lives in the feat shard.

### Still open: whether to build this at all

Recorded because it was raised and consciously not taken. This is a fourth-order
artifact — a sweep guarding controls guarding a checker guarding a prose policy —
and the zero-surface option is to write down why the mutant set isn't committed
and stop. The operator chose to build the reduced version, on the grounds that the
mutant set has been rebuilt and discarded three times and committing it once ends
that loop. The counter-argument, if the checker stabilizes: layer 4 would then be
guarding something that stopped moving.
