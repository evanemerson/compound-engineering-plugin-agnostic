# Residuals — fix/checker-symlink-traversal-symmetry

## 2026-07-31 — PR #30, `-L`/`-R` traversal symmetry in the model-pin checker

Findings file: `todos/review-2026-07-31-213513.md` (14 findings — 2 P1, 4 P2,
8 P3; 11 applied, 3 deferred). Four review agents: security-sentinel,
adversarial-reviewer, silent-failure-hunter, previous-comments-reviewer.

### Deferred

**All three struck 2026-08-01 by the mutation sweep harness (PR for
`feat/mutation-sweep-harness`).** Named by content rather than ordinal: the
first is now a *declared* survivor pair rather than an open question, the
second is built as D5's two-state quiescence check, and the third is the
committed mutant set itself.

- [x] P3 — `scripts/check-model-pins.sh` `traverse()` — **neither half of the
  traversal predicate is individually pinned, and no fixture can pin them.**
  Measured, not assumed: every failure a fixture can stage (permission denied,
  symlink cycle, missing root) sets a non-zero exit **and** writes stderr, so a
  mutant dropping either half passes the full suite — both appear as SURVIVED
  in the sweep. Both halves are kept for failures a fixture cannot stage: death
  by signal sets the status with no diagnostic, and a future `find` could warn
  at exit 0. Recorded as a stated limit in the code rather than papered over
  with a contrived control. This is the control suite's own "proves only the
  branch it exercises" shape, one level down. (finding #11, confidence 100.)

- [x] P3 — **the mutation sweep is only valid against a quiescent tree, and
  nothing enforces or records that.** Observed live this session: a sweep run
  while the session was committing and two review agents were working reported
  40 spurious failures for a mutant that, re-run in isolation, is caught by
  exactly one case. The fixture is built from the working tree, so any
  concurrent write corrupts the run — **and the corruption reads as "the suite
  caught it"**, which is the flattering direction and therefore the dangerous
  one. A `git status --porcelain` + HEAD-SHA check at sweep start would make it
  self-evident. Not built because the sweep itself is still ad-hoc — see the
  item below. (finding #12, confidence 100.)

- [x] P3 — `scripts/mutants/` — **the mutant set is still not a committed
  artifact.** Third PR in a row. 30 mutants were built this round with
  build-time assertions and discarded; the evidence is verifiable only by
  hand-rebuilding them. `cepa:autonomy` §9f's name-the-mutant rule keeps the
  mapping readable, but committing `scripts/mutants/*.patch` plus a driver
  would make it executable — and would give the two items above somewhere to
  live. **Deferred on the same cadence question as before:** a full sweep is
  57 cases x 30 mutants, roughly 18 minutes, too slow for per-PR CI. Carried
  from `memory/tasks.d/2026-07-31-chore-model-pin-control-harness.md`.
  (finding #13, confidence 80.)

### Applied this run (recorded so a future run does not re-derive it)

**The durable lesson: each fix on this branch reintroduced the defect class it
was fixing, one layer down.**

1. The residual asked for `grep -R` to close a symlinked-file gap. `grep -R`
   opens whatever a symlink points at with **no file-type check**, so a
   symlinked `/dev/zero` or writerless FIFO blocks it forever — an unbounded
   hang reachable from any PR branch, on a workflow that had no timeout.
   Reproduced twice independently; `grep -r` returns immediately on the same
   fixture.
2. Fixing *that* by moving leg 4 to `find -L … -type f` "for symmetry with
   legs 1-3" adopted their blind spot. **Leg 4 was the only leg that checked
   its traversal's exit status** — `grep -r` returns 2 on an unreadable path
   and the code tested for it. An unreadable subtree holding an unpinned agent
   went from `1 MISS` on `main` to `0 MISS, 0 WARN — 5 of 5 roots`: verbatim
   the signature of the original leg-4 defect this branch descends from.
   Two agents bisected it independently.
3. The first guard for the loop hazard grepped `find`'s stderr for the word
   `loop`. It missed permission errors and ELOOP chains entirely, and reported
   "filesystem loop" for any unreadable path merely **named** `ralph-loop`.

What finally generalized: **one `traverse()` helper that every discovery goes
through, reading find's exit status AND stderr, where non-empty stderr is a
MISS.** Keying on emptiness rather than on message text costs nothing, is
locale-proof, and subsumed the loop probe along with all three of its defects.
"Make it consistent" felt like the safe move at every one of these steps; it
was the failure mode twice.

Also fixed, each reproduced before and after:

- Leg 4's read-error branch had **no control** — a mutant deleting it passed
  52/52 in both agents' sweeps. It is also the only guard against an ARG_MAX
  exec failure. Control 34.
- The replacement coverage probe counted *listed* files, not readable content,
  so a root of zero-byte files regressed to silent. The guard is also what
  keeps `grep` from being called with no operands, which makes it read stdin —
  `/dev/null` under CI, i.e. a root reporting as scanned having scanned
  nothing. Control 36.
- The loop probe's root set was pinned by nothing; narrowing it to `plugins`
  passed 52/52. Control 35.
- `-L` double-counted a definition reachable through two symlinked `agents/`
  directories, inflating the coverage counter the suite's baseline trusts.
  `dedup_resolved()` + control L1f.
- The struck residual in the PR #28 shard still recorded **"Fix is `grep -R`"**
  as shipped. Left uncorrected that hands the hang to the next reader who mines
  the file for the fix.
- `c2affff`'s security paragraph gave two wrong reasons for a correct
  conclusion (leg 1 prints a path, not a basename; leg 4 prints a parsed
  anchor, not `-o` matches). Corrected in the findings file; the commit is
  pushed and not rewritten.

Verification: **57 controls, all passing; 30 mutants, 28 caught**, the 2
survivors being the unpinnable pair recorded above. Checker 0 MISS / 0 WARN.
No fixture leaks — cleanup now restores traversal bits first, since controls
33/34 plant mode-000 paths that `rm -rf` cannot descend into.
