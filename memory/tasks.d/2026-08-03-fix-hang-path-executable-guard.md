# Residuals — fix/hang-path-executable-guard

## 2026-08-03 — plan review (todos/review-2026-08-03-090808.md)

20 findings — 5 P1, 11 P2, 4 P3; 19 applied to the plan before build, 1 deferred.

## 2026-08-03 — PR #36 review (todos/review-2026-08-03-134500.md)

31 findings across six agents — 4 P1, 7 P2, 20 P3. The P1s and every mechanical
P2/P3 were applied in the same commit as this file; the items below are what
remains open.

**22 items open below:** 1 operator call carried from the 2026-08-02 shard, 2
recorded by plan-review findings that are themselves `status: applied` (their
fix was "record it as a residual"), 7 deferred by the PR #36 review, and 12
surfaced by the compound pass (10 live instances of the same class elsewhere in
the tooling, plus 2 proposals needing a decision).

- [ ] P3 — **RESOLVED marker format in the finding-#12 entry** (carried from
  `2026-08-02-fix-sweep-hung-checker-bound.md`, finding #5, conf 65, judgment) —
  `memory/tasks.d/2026-08-01-feat-mutation-sweep-harness.md:274`.
  architecture-reviewer: reformat to the file's `- [x] **RESOLVED <date> —**`
  lead; previous-comments-reviewer: current styling is a reasonable fusion with
  no in-section precedent to diverge from. **Still the operator's call — asked,
  not decided.** This branch edited that file's neighbourhood and deliberately
  left the marker untouched in both directions rather than settling it by
  omission.

  **The question has narrowed since it was filed.** This branch's own new entry
  at `2026-08-02-fix-sweep-hung-checker-bound.md:8` uses the
  `- [x] **RESOLVED <date> —**` lead, so the in-section precedent
  previous-comments-reviewer said was absent now exists and favours one answer.
  What remains is whether to backfill `:274` for consistency.

  `sinks:` when settled, flip all three —
  `todos/review-2026-08-02-231333.md` finding #5,
  `memory/tasks.d/2026-08-02-fix-sweep-hung-checker-bound.md`, and this bullet.
  Written down because "flipped one sink, not the other" has now recurred twice
  in this repo, and this item's sink count just went from two to three.

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

- [ ] P2 — **`case_timeout()` is the pinning gap verbatim, unfixed, on the only
  hang guard the 75-control suite has.** `scripts/check-model-pins-controls.sh:927`
  + `:936`. Control 32's `why` says its regression is a hang, so the bound *is*
  the mechanism; `32) printf 0` unbounds it and all 75 controls stay green,
  because a healthy checker finishes in under a second. Byte-for-byte the defect
  just fixed in `capture_controls`. Compounding: `120` is hardcoded twice, and
  the comment at `:257` points readers at `CASE_TIMEOUT`, an identifier that does
  not exist in the file.

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

- [ ] **A second mutation-sweep tier that mutates the sweep itself.** The mutant
  loop is already generic over `MUT_TARGET`; only the harness is hardcoded. A
  `MUT_HARNESS` column in `scripts/mutants/registry.sh`, defaulting to the
  controls suite, would let mutants target `run-mutation-sweep.sh` classified
  from its own `-- N/M classifier selftests passed --` trailer. All four defects
  this branch shipped become one-line registry entries
  (`sweep-fixture-trailer`, `sweep-rm-guard`, `sweep-anchor-inline`,
  `sweep-zero-bound`, `sweep-nap-margin`). At ~25s it is PR-gate affordable in a
  way the 64-minute controls sweep explicitly is not. **This is the construct
  that stops the next instance from needing a list** — everything above is a
  list.

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
