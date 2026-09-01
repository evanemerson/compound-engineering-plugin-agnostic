# Residual — feat/check-residual-integrity

## 2026-09-01 — findings from the checker's first clean run

`scripts/check-residual-integrity.sh` (commit `37692e1`) reported **2 MISS,
2 WARN** over the tracked tree on its first clean run. The tree now reports
**0 MISS, 2 WARN** — see below for why the deferral did not survive review.

### Closed in this PR

- [x] ~~P2 — **`todos/review-2026-08-25-194437.md` severity counters disagree
  with its body.**~~ **FIXED 2026-09-01, same PR (#49).** Declared
  `p1: 3, p2: 4, p3: 4`; the body carries **3 P1, 5 P2, 3 P3**. `total: 11` was
  correct either way and every state counter agreed (`applied: 11` over 11
  applied findings), so the file was wrong in exactly the way the spec says a
  sum-only check cannot see:

  > Every wrong distribution with the same total satisfies it… That shipped,
  > was reported as "counters verified", and was caught only by a later review
  > — twice.

  Third instance of that shape, and the first caught by a machine rather than
  by a human reading prose. Hand-verified twice against the body tally before
  and after. Fix was `p2: 5, p3: 3` — one line, no body change. The file is
  **PR #48's own review**, whose run reported its counters as verified.

  **Why the deferral was reversed.** This was filed as "fix in a follow-up, the
  checker lands first" — sound reasoning, and it stopped being available the
  moment review surfaced that the checker had no CI wiring. Wiring it in makes
  the drift a **red workflow on main**, and a gate that ships red is not a
  deferral, it is a broken gate that trains everyone to ignore it. Deferring
  the fix and wiring the checker were mutually exclusive; wiring won, because
  an unenforced checker catches nothing. Recorded because the original
  reasoning was not wrong — it was scoped to a PR that did not yet include CI.

- [ ] P3 — **two `- **P[123]` bullets with no checkbox** in
  `memory/tasks.d/2026-08-01-chore-plan-review-mutation-sweep.md:61,72`. These
  are the leg-4 WARNs, and they are the **known-legitimate** hits the
  2026-08-06 reconciliation deliberately created as an evidence block — not
  drift. They are why leg 4 ships WARN rather than MISS: promoting it today
  would fail a correct tree, and the only fix available would be to mangle
  correct prose. Decide one of: give them checkboxes (they are genuinely
  stateless items a consumer cannot read), mark the block in a way leg 4 can
  see, or accept them permanently and record that leg 4 can never be promoted
  while they exist. **Do not "fix" them by deleting the evidence.**

  **If you act on this, update control `real` in the same commit.** It pins the
  live tree at `0 MISS, 2 WARN`, and those 2 WARN are exactly these bullets —
  so resolving them turns the controls suite red with a message asserting the
  checker regressed, which is not what happened. The coupling is recorded at
  both ends deliberately: adversarial review found that the *first* version of
  this trap (the case pinned 2 MISS against a drift this shard told the next
  session to fix) would have handed whoever did the right thing a red suite
  blaming them for it.

### Applied from the /cepa:review pass on PR #49

All fixed in the same PR; each was verified by running the thing it changed.

**The four silent-pass paths below shared one root shape, and it is this
checker's own subject matter one level down:** a check that reads the right
invariant over the **wrong row set**. Leg 1 trusted that a path returned by
`find()` meant the file was read, that a regex match *anywhere* meant the field
was declared, and that a field row *anywhere* meant a finding existed. Each
produced `0 MISS, exit 0` — indistinguishable from a genuinely clean file. Every
one was reproduced with a real fixture before being fixed, and re-run after.

- [x] **P1 (silent-failure, adversarial) — an unparseable file was dropped
  whenever a sibling parsed cleanly.** Two bare `continue`s (no `summary:`
  block; `summary:` with no `total:`) skipped a file without emitting anything.
  The only backstop fired at `leg1_files -eq 0`, so one well-formed sibling —
  which every real run has — disarmed it permanently. Measured: a two-file
  fixture with one clean file and one whose `total:` was typo'd to
  `grand_total:` (declaring `p1: 5, completed: 5` over a body of one applied P1)
  reported `0 MISS, 0 WARN`, exit 0. An ordinary typo, not an adversarial input.
  Each path now emits its own MISS, `grep`'s exit 2 (file deleted or made
  unreadable mid-scan) is distinguished from exit 1 rather than folded into it,
  and a walked-vs-accounted reconciliation catches any FUTURE `continue` added
  without one. Controls `nosum`, `nototal`.
- [x] **P1 (adversarial) — `counter_convention:` anywhere in the file granted a
  total exemption.** The grep was file-wide while the spec puts the field in
  frontmatter, so a writer could exempt their own drifted file by mentioning it
  in prose or a ```yaml fence — and this repo's findings files routinely discuss
  their own format. Measured at `0 MISS, 0 WARN` on a genuinely drifted file.
  Now scoped to the frontmatter block. Control `fenceconv`; mutation-verified
  that restoring the file-wide grep turns the suite red.
- [x] **P2 (adversarial) — field rows bound to no heading counted as findings.**
  `headings` was computed and then compared against nothing but zero, so any
  non-zero mismatch was invisible: deleting a finding while leaving the counters
  whole, with its field rows surviving in a fence or before the first `### N`,
  kept every counter agreeing. Fences are now stripped before tallying and
  `headings == body_status_rows` is asserted. Controls `fencerow`, `orphan`.
- [x] **P2 (silent-failure) — frontmatter with no closing `---` read as
  verified.** The body extractor needs a second delimiter to enter the body
  state; without one `$body` is empty, which agrees perfectly with `total: 0`
  and every counter 0. Checked structurally (delimiter count) rather than by
  testing for an empty body, because a findings file may legitimately have one.
  Control `nofm`.
- [x] **P3 (adversarial) — a suppressed diagnostic passed the whole suite.**
  Cases read counts from the verdict line alone, so a mutant that incremented
  the counter while silencing the message emitted `N MISS` with no MISS line
  anywhere. `run_checker` now asserts the emitted line count matches the
  verdict, killing the class in one place. Also added `gapneg`, which pins the
  `gap < 0` arm's message — deleting that arm as "redundant" preserved
  detection but lost the sentence naming the cause.

- [x] **P2 (architecture) — the checker had no CI wiring.** The sibling
  `check-model-pins.sh` is PR-gated by `.github/workflows/model-pins.yml`; this
  one was gated by nothing, so a merged checker would have had zero automated
  executions. Added `.github/workflows/residual-integrity.yml` on the sibling's
  two-step pattern (policy first, controls second with `if: always()`, so
  neither hides the other). It **cites** model-pins.yml for action pinning, the
  bump recipe, and the JS-runtime constraint rather than restating them — a
  second copy is how the model-pin rule's two rationales diverged. Both `run:`
  blocks were extracted with `yaml.safe_load` and executed under `bash -e`
  before pushing, per CLAUDE.md. That test is what surfaced the deferral
  conflict above.
- [x] **P3 (security) — `chmod 000` fixture leaked on signal-driven exit.** The
  `trav` case plants a mode-000 directory and `rm -rf` cannot descend into one,
  so a Ctrl-C or cancelled CI job mid-case leaked a fixture tree. Reproduced
  directly before fixing. Adopted the sibling's exact guard: `chmod -R u+rwX`
  inside `cleanup()` before `rm -rf`, a WARN on failed removal, and
  `trap cleanup EXIT INT TERM`.
- [x] **P3 (architecture) — the env-override surface had zero control coverage.**
  `RESIDUAL_TODOS_DIR`/`RESIDUAL_SHARDS_DIR` are real configuration that no
  case exercised, so a typo in either `${VAR:-default}` expansion would have
  shipped green. Added control `envdir`, which relocates the whole fixture and
  asserts the checker still finds it. Mutation-verified: hardcoding
  `TODOS_DIR=todos` turns it red.
- [x] **P3 (architecture) — the copied `traverse()` dropped the sibling's stated
  limit.** Neither half of its two-part predicate is individually pinned by any
  control, here or in the sibling, and cannot be. Now cited (not restated) at
  the copy site, along with why `dedup_resolved()` was deliberately NOT copied
  — so the omission reads as a decision rather than an oversight.
- [x] **P3 (architecture) — the `STATES` array had no link to its spec.** It
  tracks `file-todos` SKILL.md's `status` enum, but that skill has no
  `### N<letter>` anchors, so `check-model-pins.sh` leg 4 has nothing to
  resolve and no machine link forces the array to follow a spec edit. Recorded
  in a comment naming the exact field table to grep, since that note is now the
  only thing covering the gap.
- [x] **P3 (security) — no forward marker for the §7 relay question.** Verified no
  consumer reads this script's stdout today, so no relay point exists and
  CLAUDE.md's rule does not yet bind. Added a header note for whoever wires the
  next consumer, because PR #9's Detection relay shipped as an injection
  channel precisely by being wired up without re-asking at the new site.

### Found by wiring CI — a latent defect in the deprecation observer

- [x] **P2 — `runtime-deprecation` dies on any workflow with no runs yet.**
  Adding `residual-integrity.yml` turned that job red with **no diagnostic**.
  The new workflow is not the cause; it is the trigger. Every newly-added
  workflow in this repo would have done the same until its first run landed on
  the default branch. **FIXED 2026-09-01, commit `9f512fe`.**

  `.workflow_runs[0]` is `null` for a workflow with no completed run on the
  branch, and `null | [...] | @tsv` renders as a **two-character string of
  empty fields**, not the empty string. So `[ -z "$run" ]` is false, the SKIP
  is bypassed, and the loop proceeds with empty `run_id`/`head_sha`/`suite`.
  The next call becomes a compare against an empty base, which 404s — and
  under `set -o pipefail` with GitHub's `bash -e` shell the **assignment**
  takes gh's non-zero status and kills the step before the `|| ...` guard
  written for exactly that case can run.

  Two things worth keeping:

  1. **The guard must precede `@tsv`.** `... | @tsv // empty` was the first
     fix and does **nothing** — `@tsv` has already produced a non-null string,
     so the `//` alternative never fires. It was caught by testing against the
     live API rather than by reading the filter, which looked correct.
  2. **The step was never reaching `Dependabot Updates` at all.** It died two
     entries earlier, so a fifth workflow had gone uninspected for as long as
     it has existed — and the job reported success the whole time, because it
     failed only once a workflow sorted before that one lacked runs. A partial
     scan reporting as a clean pass is this repo's most-documented defect
     class; here it was inside the job whose own header forbids it.

  Verified by extracting the step with `yaml.safe_load` and replaying it under
  `bash -e` with a real token, before and after. Before: 3 lines then exit 1,
  no summary. After: exit 0, all five workflows reached, the new one correctly
  SKIPped with its reason named.

### Recorded — the checker's own first-run defect

Its first cut reported **21 MISS** over this tree. The tally grepped `status:`
file-wide, so frontmatter provider blocks (`status: available`,
`status: unavailable`, `status: fresh`) each counted as an extra finding. Every
message read "body carries N+1, total says N" — plausible, uniform, and wrong.

Caught by noticing the *shape* of the result, not by reading any one message: a
uniform off-by-one across twenty unrelated files is the signature of a broken
pattern, not twenty independent drifts. That is the same reasoning the sink's
own history rewards — the 2026-08-09 pass reported "12 files with counter
drift" when the honest number was 7, by a regex that excluded legitimate batch
notation.

Filed because it is the third recorded instance of a checker miscounting this
exact tree, and the second where the wrong count was *more* believable than the
right one. Control `fm` keeps this one dead.

### Recorded — two limits, in the script header

Both are in `scripts/check-residual-integrity.sh` rather than here, so they sit
where someone changing the code will read them. Named here only so a reader of
the sink knows they exist:

1. **Leg 1c cannot see the rejected encoding on a single file.** A `total`
   shrunk to absorb a removal, with every counter shrunk consistently, is
   byte-identical to a file that only ever had that many findings. Control
   `gapeq` pins this limit so a future revision claiming to close it has to
   change the case deliberately.
2. **This checks internal agreement, never truth.** A file whose body and
   counters agree can still describe work that never happened — and a
   cross-repo shard item can be perfectly consistent and three days stale, as
   `memory/tasks.d/2026-09-01-main.md` records from earlier the same day.
3. **The walked-vs-accounted reconciliation has no control that reddens it,
   and cannot have one today.** Every `continue` in the leg-1 loop is already
   accounted for, so no plantable fixture makes the arithmetic fail —
   mutation-verified: replacing its condition with `false` leaves the suite at
   28/28. It is a tripwire for the next `continue` added without a MISS, which
   is exactly the shape of the P1 above. Proven live by planting that future
   defect in a mutant copy: the guard caught the dropped file where the old
   code reported clean. Recorded rather than left looking pinned, per
   `an-assertion-must-name-the-edit-that-reddens-it` — the edit that reddens it
   has not been written yet.
