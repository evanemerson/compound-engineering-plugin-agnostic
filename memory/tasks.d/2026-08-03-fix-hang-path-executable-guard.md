# Residuals — fix/hang-path-executable-guard

## 2026-08-03 — plan review (todos/review-2026-08-03-090808.md)

20 findings — 5 P1, 11 P2, 4 P3; 19 applied to the plan before build, 1 deferred.

## 2026-08-03 — PR #36 review (todos/review-2026-08-03-134500.md)

31 findings across six agents — 4 P1, 7 P2, 20 P3. The P1s and every mechanical
P2/P3 were applied in the same commit as this file; the items below are what
remains open.

**20 items open below** (the operator call, the `case_timeout()` pinning gap and
the sweep-tier proposal are now resolved; the tier's own stated limit is filed
as the new `refuse`-mode item): 2 recorded by plan-review findings that are themselves
`status: applied` (their fix was "record it as a residual"), 7 deferred by the
PR #36 review, and 12 surfaced by the compound pass (10 live instances of the
same class elsewhere in the tooling, plus 2 proposals needing a decision).

- [x] **RESOLVED 2026-08-03 — operator chose to backfill.** The finding-#12
  entry at `memory/tasks.d/2026-08-01-feat-mutation-sweep-harness.md:274` now
  leads with the file's `- [x] **RESOLVED <date> — summary**` opener, matching
  the six prior entries, with the original text preserved verbatim under a
  `Was:` lead. The disagreement resolved once the question narrowed:
  previous-comments-reviewer's only objection was that the section had no
  resolution precedent to diverge from, and this branch created one.

  All three sinks flipped in the same commit, per the `sinks:` list recorded
  here when the item was filed — `todos/review-2026-08-02-231333.md` finding #5
  (`status: completed`, counters `deferred: 0 / completed: 2`),
  `memory/tasks.d/2026-08-02-fix-sweep-hung-checker-bound.md`, and this bullet.
  Writing the list down is what made the third flip automatic rather than
  remembered.

- [ ] P3 — **`--selftest` is wired only to the weekly job, not the PR gate**
  (plan review finding #11, cut from scope).
  `.github/workflows/mutation-sweep.yml:84-85` is its only invocation;
  `model-pins.yml` has none.
  `docs/solutions/logic-errors/verification-evidence-must-be-a-committed-executable-artifact.md`
  says it *"belongs in the PR gate"*, so today a change breaking the hang guard
  stays green for up to a week. Wiring it in changes the gate for every future
  PR and drags `model-pins.yml:53`'s "Both checks finish in seconds" with it.
  Deliberately not built here: separate deliverable, own CI review surface.

- [ ] P3 — **the driver's `exit 2` statement has no direct coverage** (plan
  review finding #10). `scripts/run-mutation-sweep.sh:1057-1063` exits 2 on
  `CLASS = HARNESS-ERROR`; the hang cases assert that *condition* but not the
  statement, because the loop exits before `resolve_outcome` and covering the
  statement itself needs a whole-driver subprocess run.

### Deferred from the PR #36 review

- [ ] P3 — **the anchor detects replacement of the call site, never addition
  beside it** (finding #22, conf 85). `== 1` cannot express "and nowhere else";
  a second capture added beside the surviving call keeps the count at 1 and
  stays green. Fix: pair it with a zero-count assertion on the raw
  `> "$WORK/controls.out"` shape, which occurs 0 times today.

- [ ] P3 — **no solution doc for "an environment failure reported as a code
  finding"** (finding #24, conf 75). Four instances in this one file, each fixed
  at the site it was reported at while the construct stayed live. Run
  `/cepa:compound` with a Detection section keyed on `|| <var>=''`,
  `2>/dev/null ||`, and bare `$( … || printf '')` in assertion contexts.

- [ ] P3 — **CLAUDE.md's version-scope rule does not cover `scripts/`**
  (finding #25, conf 85). It names only plugin content as bumping, while three
  scripts-only bumps have now shipped on precedent. Verified: 1.16.2 and 1.18.2
  support it; **1.16.1 does not** — it also changed
  `plugins/cepa/skills/autonomy/SKILL.md`. Amend the rule to name `scripts/`,
  citing 1.16.2 and 1.18.2 only. Own branch — it is a contract change.

- [ ] P3 — **the selftest's temp dir is outside the TMPDIR-inside-repo guard**
  (finding #26, conf 50). The containment check runs after `--selftest` exits.
  Hoist it above that block so both temp roots are covered by one check.

- [ ] P3 — **two more inline paraphrases of §9f's control→mutant sentence**
  (finding #27, conf 50). Correct citations with a one-clause gloss, but this
  policy's history is "seven longhand copies with two divergent rationales".

- [ ] P3 — **`CAP_RC` is a declared output nothing reads** (finding #28,
  conf 85). Either assert it in arm 1 — the guarded capture returns 124/137 when
  the bound fires, separating "returned at the bound" from "the suite exited on
  its own" — or drop it, or comment it as deliberately unread.

- [ ] P3 — **process-substitution capture is green but unproven** (finding #31,
  conf 40). `> >(cat > "$out_file")` stays green and a read-after-write race is
  real in principle; 0/10 truncations at a 20,000-line transcript, so it was
  reported as unproven rather than as a finding. Recorded so it is not
  re-derived.

## 2026-08-03 — surfaced by /cepa:compound, not fixed here

Documented in `docs/solutions/logic-errors/an-assertion-must-name-the-edit-that-reddens-it.md`
(local-only — `docs/` is gitignored). These are live instances of the same four
detachment modes, found while generalizing the class. Each was verified against
source by the prevention agent; none is fixed.

- [x] **RESOLVED 2026-08-03 — fixed in `fix/case-timeout-unpinnable-bound`
  (1.18.4).** `run_checker` now refuses a non-numeric or zero per-case bound at
  the callee, where every caller passes through, because the bound arrives in
  caller position and no textual anchor can pin it. The `120` default is named
  once (`CASE_TIMEOUT_DEFAULT`) instead of spelled in two places that could
  drift, `-k 30` likewise (`CASE_KILL_GRACE`), and the comment at `:257`
  pointing at a non-existent `CASE_TIMEOUT` identifier now cites `case_timeout`.

  Proven in both directions against fixture copies: on `main`, planting
  `32) printf 0` — which deletes the suite's only hang guard — left it at
  **75/75, exit 0**, confirming the defect was real and invisible. On this
  branch the same plant is **exit 2** with a named reason, while intact stays
  75/75.

  PR #37 review then found two more doors of identical silence and one bug in
  the fix itself: a huge bound (`999999`) is arithmetically a bound and
  operationally none; `-k 0` disables the KILL escalation entirely (verified —
  a TERM-ignoring child ran its full 12s at `-k 0` versus a kill at 5s with
  `-k 3`), and the PR had *named* `CASE_KILL_GRACE` while validating only its
  sibling — a fix scoped to the reported instance, in the PR closing that class.
  The guard now takes a range (`1..CASE_TIMEOUT_DEFAULT`), rejects leading
  zeros, and checks length before arithmetic. It also validates each operand
  **separately**: the reviewer's suggested `case "$grace$bound"` one-liner
  masked an empty bound (`"30" + "" = "30"`, all digits, passes) — caught by
  running the proof rather than reading it.

  Nine bypass attempts plus two legitimate edits, all measured: bound `0`,
  `999999`, empty, overflow-length, `032`, and grace `0`, `999999` all reach
  exit 2 with an accurate diagnosis; bound `45` and a raised default still pass
  75/75.

  Stated limit, deliberately not closed here: this is a **runtime refusal, not
  an assertion**. The controls suite tests the checker, and `run_checker` is
  harness, so a control asserting it would be the category error §9f's
  control→mutant rule exists to prevent. The assertion arrives with the sweep
  tier below.

- [ ] P2 — **leg 4's zero-coverage floor greps its own source.**
  `scripts/check-model-pins.sh:470` + `:663`. `CITE_ROOTS` includes `scripts`,
  where the checker lives, and its own comments carry 29 `§` tokens — so the
  floor is satisfied by the file's header block and can fire only if the file is
  deleted. The observability gap, at the detector layer, on the guard whose whole
  job is refusing a vacuous pass. `roots_scanned` at `:585` recomputes numerator
  and denominator from the same list, so they drift together and read plausible
  in every state.

- [ ] P3 — **~16 controls forbid an arithmetically impossible token.**
  `scripts/check-model-pins-controls.sh:1076` vs `:1059`. Gate 2 returns before
  gate 5, and `miss()` prints one `MISS ` line per increment, so `EXP_MISS == 0`
  implies zero `^MISS ` lines by construction. Affects controls 9, 15, 18, 21,
  22, 23, 32, 39, 41, 42, L1h, L1k, L1m, L3e (plus L2g/L2h for `^WARN `). Related
  dead forbids: control 20's `'unbound variable'`, 10a/10b's
  `'cited as .grounding.'`.

- [ ] P3 — **six `say()` controls pass by non-observation.**
  `scripts/check-model-pins-controls.sh:168-210`. They plant into `README.md` and
  expect a state byte-identical to the baseline, so dropping `README.md` from the
  scan roots entirely — never opening the planted line — passes all six. The file
  already documents the remedy (case 40's comment, case 18's before/after probe)
  and applies it to two rows out of eight.

- [ ] P3 — **the classifier's fixtures are hand-typed and tied to nothing.**
  `scripts/run-mutation-sweep.sh:414-490`. Thirteen assertions run against string
  constants; the real emitters are in `check-model-pins-controls.sh`, connected
  by prose only. Silent direction: rename the `ERROR %-4s` prefix and a mixed
  transcript (setup error plus a genuine red) stops hitting the `^ERROR ` branch,
  falls through, and classifies **CAUGHT/exit 0** — the false CAUGHT
  `classify_transcript`'s own comment records reproducing — with all 13 selftests
  green.

- [ ] P3 — **`--selftest` has no minimum-assertion floor**, though its own
  subject (`check-model-pins-controls.sh:1113`) refuses a zero-case run. Live
  instance already in the tree: this branch's `rm -f` case is skipped under
  `id -u -eq 0`, so in any root container it vanishes into a green trailer.

- [ ] P3 — **`mutation-sweep.yml:86` has no `timeout-minutes`**, and is now the
  only unbounded step in the job while deliberately containing two multi-second
  hang fixtures. The same file's comment at `:66-68` states the rule this
  violates.

- [ ] P3 — **`plugins/cepa/scripts/check-health.sh` bypasses its own helper.**
  `check_ignore_leg()` at `:80-84` exists to split `git check-ignore` exit 1 from
  exit >1; three call sites 25 lines later use the raw
  `&& … || …` form, so a broken git (exit 128) prints `OK … is not ignored`.
  Compounding: `miss()` is `printf`-only with no accumulator and the file
  contains no `exit`, so ~25 MISS conditions all return 0.

- [ ] P3 — **unvalidated caller-position values** (the pinning gap's family):
  `brain-backfill.sh:33,40` (`batch` never validated; a non-numeric value makes
  the loop never break and hands out the whole corpus as one batch),
  `brain-backfill.sh:37,46` and `brain-client.sh:139` (grep exit 2 collapsed into
  a legitimate answer), `model-pins.yml:112` (`STALE_AFTER_DAYS` unbounded).

- [ ] P3 — **`reg()` does not enforce id uniqueness** and `run_one`'s
  `cp -a "$PRISTINE" "$dir"` copies *into* an existing directory returning 0, so
  a duplicate id would run against the previous row's planted tree with both able
  to print PASS. Currently clean; nothing keeps it that way. Check:
  `bash scripts/check-model-pins-controls.sh --list | awk '{print $1}' | sort | uniq -d`.

### Proposed, needs a decision before building

- [x] **RESOLVED 2026-08-03 — built in `feat/sweep-harness-tier` (1.19.0).**
  `MUT_HARNESS` + an `hmut` verb; `classify_transcript` gains a `selftest` mode
  matched separately from the controls mode (never one loosened trailer regex,
  which would let each tier silently accept the other's transcript);
  `capture_controls` takes trailing args with a now-REQUIRED label; a per-tier
  report header; and a recursion marker.

  Three mutants registered and all CAUGHT, each naming the assertion that killed
  it: `sweep-rm-guard`, `sweep-anchor-inline`, `sweep-zero-bound`. The 63
  checker mutants are unaffected (t-predicate still CAUGHT by 31/33/35).

  **Two of the five intended mutants are deliberately absent, and that is the
  tier's stated limit rather than an oversight.** Plan review measured all five:
  `sweep-nap-margin` makes the driver exit 2 before its trailer, which is
  HARNESS-ERROR, which aborts the whole sweep — it would take the run down
  instead of reporting a kill. So **a guard that kills by REFUSING cannot be a
  harness mutant at all today**, which also covers #37's `run_checker` bound
  guard. See the `refuse`-mode item below.

  Recursion is real and was measured: mutating `--selftest) SELFTEST=1 ;;` to
  `SELFTEST=0` made the mutated child print the sweep header and begin a real
  sweep. The time bound does not contain it — the child's captures spawn
  grandchildren in their own process groups that survive the outer group-kill —
  so the exported marker is the only bound on depth.

- [ ] P2 — **a `refuse` expectation mode, so guards that kill by refusing can be
  registered.** Needed by `sweep-nap-margin` and by #37's `run_checker` bound
  guard, which is currently a runtime refusal with no assertion. Design
  constraint that makes it non-trivial: keying `refuse` on HARNESS-ERROR alone
  would report CAUGHT for **any** broken environment — the
  environment-failure-as-finding inversion this repo documents. It needs a
  machine token on the harness's exit path, never English FATAL prose, which
  means touching each guard that should be killable.

- [ ] **CLAUDE.md rule — drafted, NOT applied** (full autonomy never edits
  CLAUDE.md mid-run). Two agents disagree on placement: the prevention agent
  proposes a new Critical Rules section citing §9f once; the related-docs agent
  cites `each-fix-reintroduced-the-defect-class-one-layer-down.md` Prevention,
  which says explicitly **do not add a fourth CLAUDE.md rule section for this
  family** — append to the existing enumeration instead. Operator's call. Draft
  content: the verification chain has a last link and nothing verifies it; every
  assertion in that link records the single-line edit to production code that
  reddens it; the four bad answers (capability, reachability, observability,
  pinning); and a suite that verifies a suite inherits the assertion-count floor
  it enforces.

## Deliberate divergences from an applied finding

Recorded because both were marked `applied` while narrowing what was specified —
a silent narrowing is what this file exists to prevent.

- **Plan review finding #3 (PID + PGID escape assertion): only the PID half
  shipped.** The fixture records the sleeper's PID; escape is asserted as
  liveness *after* the capture returned, which is sufficient — a descendant
  still inside the killed group would already be dead — and it discriminates
  (no-oping the plant fails that assertion). The PGID comparison was dropped as
  redundant and as an extra `ps`/procps dependency. Residual risk: if a future
  change made the file arm's bound exceed `ST_NAP`, liveness would fail for a
  reason unrelated to escape and the message would misdirect.

- **PR review, adversarial F3 (pin the bound into the anchor): not taken.**
  Pinning `30 900` into the needle would enlarge the false-red surface that the
  same review's F4 documents. The bound is validated inside `capture_controls`
  instead, so a zero or non-numeric bound is fatal at the first mutant rather
  than silently unbounded. Consequence, stated: `--selftest` never executes the
  production call site, so no selftest assertion can ever pin its arguments —
  only the runtime refusal protects that.

## Known-open, not fixed here

- **An escaped writer still holds the transcript's fd at read time**
  (reliability F5, conf 40). The file redirect bounds the driver's *wait*, not
  the transcript's *writers*: a descendant that escaped the group-kill keeps the
  inherited fd open, and the selftest asserts exactly such a writer is alive
  three lines before it classifies that file. Not reachable today — no
  production descendant has both required properties — and the next mutant is
  safe because `rm -f` unlinks the inode. No cheap total fix exists; an unlink
  does not revoke an open fd.

- **`--selftest` cost rose from ~0.08s to ~25s** (adversarial/previous-comments).
  `.github/workflows/mutation-sweep.yml:82` still describes the step as "cheap,
  so a broken one fails in seconds". Amended in this branch; noted here because
  the same claim in `model-pins.yml:53` is the reason the PR-gate item above
  stays open.
