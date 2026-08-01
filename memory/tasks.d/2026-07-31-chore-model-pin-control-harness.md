# Residuals — chore/model-pin-control-harness

## 2026-07-31 — PR #29, control suite for `scripts/check-model-pins.sh`

Findings file: `todos/review-2026-07-31-152556.md` (23 findings — 5 P1, 5 P2,
13 P3; 18 applied, 5 deferred). Five review agents: security-sentinel,
architecture-reviewer, silent-failure-hunter, adversarial-reviewer,
previous-comments-reviewer.

### Deferred

- [x] P3 — *(struck 2026-08-01: `scripts/mutants/registry.sh` +
  `scripts/run-mutation-sweep.sh`. This is the ORIGINAL copy of the item; the
  descendant copy in
  `memory/tasks.d/2026-07-31-fix-checker-symlink-traversal-symmetry.md` was
  struck in the same commit. Carrying an item forward duplicates it, so
  striking only the descendant leaves a plain `memory/tasks.d/*.md` checkbox
  scan still reporting it open.)* `scripts/mutants/` — **the mutant set is not
  a committed artifact.** 20 single-line mutants were built with build-time assertions,
  run against the suite, and discarded. `cepa:autonomy` §9f now requires each
  control to name the mutant it kills, which makes the mapping *readable*;
  committing the patches with a driver would make it *executable*.
  **Deferred because** a full sweep is 47 cases × 20 mutants ≈ 10 minutes —
  too slow for per-PR CI — so it needs a cadence decision (weekly tier?
  manual-only?) larger than this PR. (review finding #19, confidence 90.)

- [ ] P3 — `scripts/check-model-pins-controls.sh:313` — **an interrupt
  mid-run misattributes every remaining case.** SIGINT during a case removes
  `$TMPROOT`; the remaining cases then fail with "could not copy fixture" and
  the summary reads "the checker no longer behaves the way its record
  claims". Fails **safe** — never a false pass — but blames the checker for
  an interrupted run. Fix is a flag set in the trap. (finding #20,
  confidence 60.)

- [ ] P3 — `scripts/check-model-pins-controls.sh:320-330` — **untracked
  working-tree files are invisible to the fixture.** Verified: an unpinned
  command file that is not `git add`ed leaves the suite at 47/47. By design
  (the fixture is the tracked tree, and CI always checks out) and documented
  in the script. **Deferred rather than fixed** because a staging-aware
  fixture would diverge from what CI actually reviews, which is worse.
  (finding #21, confidence 60.)

- [ ] P3 — `scripts/check-model-pins-controls.sh:470-476` — **a filtered run
  still exits 0.** Partially applied: `--only` now prints a loud PARTIAL RUN
  banner naming how many controls did not run. The exit code stays 0
  deliberately — `--only` is a developer affordance and a non-zero exit on a
  passing subset would be wrong. CI does not pass `--only`, and the workflow
  is in this diff. Revisit if a caller ever filters. (finding #22,
  confidence 70.)

- [ ] P3 — `memory/tasks.d/2026-07-30-fix-cite-trunk-ladder-once.md:94-95` —
  **the shard and the script share the phrase "the baseline gate cannot catch
  it".** Informational; the shard is a point-in-time record and is not
  supposed to track script edits, so there is no authority ambiguity. Flagged
  only because it is the same phrase-reuse shape as findings #5 and #10.
  (finding #23, confidence 55.)

### Applied this run (recorded so a future run does not re-derive it)

The PR shipped a control suite whose stated purpose is preventing "a suite
that only exercises the branch it happens to reach", and **the first cut
reproduced that defect one grain coarser**: 22 of its 26 cases targeted leg 4
— the region the recorded case list was transcribed from — and **12 material
single-line mutants of the checker survived it at 26/26**. It also **dropped
three recorded cases (21-23)** while four artifacts claimed all 24 landed,
with arithmetic that did not close (24+1+4=29, not 26); three agents caught
that independently.

That is the durable lesson: building the harness the solution doc asked for
produced a fresh instance of the defect the solution doc is about. The
**case-list framing**, not the execution method, was the load-bearing
mistake — "plants each recorded case" is not coverage, because the recorded
cases came from one leg's incidents. The generalization now lives in
`cepa:autonomy` §9f: every control must name the mutant it kills.

Also fixed, each reproduced before and after:

- **No case asserted the checker's exit code.** Mutating the final `exit 1`
  to `exit 0` left every count and message identical and passed 26/26 — a
  permanently green CI with a correct-looking log. Now asserted per case;
  35 of 47 cases catch that mutant.
- **The fixture builder silently truncated the tree.** No `pipefail` on the
  `tar | tar` pipeline (the guard saw only the extract stage), and `[ -e ]`
  rather than `[ -r ]` on the file filter. With one tracked file unreadable
  the real checker reported 3 MISS while the suite reported a clean baseline
  and 26/26. Now: `pipefail`, unreadable-is-FATAL, and a post-extract file
  count that also closes the TOCTOU window.
- **A tracked symlink escaped the fixture.** `git ls-files | tar` preserves
  symlinks; `>>` and `cat >` follow them. Reproduced independently twice: a
  planting write landed outside the fixture. Now refused outright — with
  `tar --dereference` rejected as the alternative, since it would trade the
  write-escape for pulling linked content *into* the fixture.
- **CI ordering was backwards.** Controls-first meant an ordinary unpinned
  dispatch tripped the controls' *baseline* gate, so the red step was named
  after the harness and the step named after the policy was skipped. The
  original rationale described a failure GitHub Actions already prevents
  (it skips steps after a failure). Now: policy check first, controls second
  with `if: always()`.
- **Three restatement-drift instances**, all diff-introduced: the workflow
  comment restated §9f near-verbatim then cited it; the CLAUDE.md bullet
  *originated* control-suite policy §9f did not contain (directly under the
  "cite it, do not restate it" paragraph); the case-10 comment restated the
  §9f gap-table row. Rule relocated into §9f; the other two trimmed to
  citations.

Verification after fixes: **47 controls, all passing; 20 mutants, all 20
caught**; checker 0 MISS / 0 WARN; tree clean; no fixture leaks. Each mutant
was built with a build-time assertion that its literal matched exactly once —
a mutation that silently fails to apply manufactures a fake survivor, which
happened once during this work and was caught only by diffing.
