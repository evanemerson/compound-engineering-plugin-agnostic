# Residual — feat/check-residual-integrity

## 2026-09-01 — findings from the checker's first clean run

`scripts/check-residual-integrity.sh` (commit `37692e1`) reports **2 MISS,
2 WARN** over the tracked tree. Both categories are recorded here rather than
fixed in the same PR: the checker lands first, and a PR that both introduces a
check and edits the files it flags makes neither half reviewable.

### Open

- [ ] P2 — **`todos/review-2026-08-25-194437.md` severity counters disagree
  with its body.** Declares `p1: 3, p2: 4, p3: 4`; the body carries **3 P1,
  5 P2, 3 P3**. `total: 11` is correct either way, and every state counter
  agrees (`applied: 11` over 11 applied findings), so the file is wrong in
  exactly the way the spec says a sum-only check cannot see:

  > Every wrong distribution with the same total satisfies it… That shipped,
  > was reported as "counters verified", and was caught only by a later review
  > — twice.

  Third instance of that shape, and the first caught by a machine rather than
  by a human reading prose. Hand-verified before filing: the body tally is
  `3 P1 / 5 P2 / 3 P3`. Fix is `p2: 5, p3: 3` — one line, no body change. The
  file is PR #48's own review, which is worth noting: the run that produced it
  reported its counters as verified.

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
