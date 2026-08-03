# Residuals — fix/hang-path-executable-guard

## 2026-08-03 — plan review (todos/review-2026-08-03-090808.md)

20 findings — 5 P1, 11 P2, 4 P3; 19 applied to the plan before build, 1 deferred.

## 2026-08-03 — PR #36 review (todos/review-2026-08-03-134500.md)

31 findings across six agents — 4 P1, 7 P2, 20 P3. The P1s and every mechanical
P2/P3 were applied in the same commit as this file; the items below are what
remains open.

**10 items open below:** 1 operator call carried from the 2026-08-02 shard, 2
recorded by plan-review findings that are themselves `status: applied` (their
fix was "record it as a residual"), and 7 deferred by the PR #36 review.

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
