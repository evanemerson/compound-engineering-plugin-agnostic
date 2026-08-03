# Residuals — fix/sweep-hung-checker-bound

## 2026-08-02 — review of PR #35 (todos/review-2026-08-02-231333.md)

5 findings — 0 P1, 3 P2, 2 P3; 3 applied in the same commit as the findings
file, 2 deferred below.

- [x] **RESOLVED 2026-08-03 — built in `fix/hang-path-executable-guard`
  (1.18.3).** Ten `--selftest` cases drive the real `capture_controls` path at a
  scaled bound against a TERM-ignoring checker whose descendant escapes the
  group-kill, plus an exactly-once anchor on the production call site. The pair
  asserts the *discrimination* — same fixture through both capture shapes in one
  run — rather than an absolute threshold, so the guard-removed direction runs
  every time instead of living in a PR body. Proven three ways: intact 27/27;
  `$( )` pipe restored → exit 1 (24/27); plant no-oped → exit 1 (23/27).
  Chosen home is the driver's `--selftest`, not the controls suite (§9f: every
  control must kill a named mutant, and all 63 target the checker; a 20s case
  there costs ~21 min across a ~43 min sweep). Asserts the CURRENT file-redirect
  bound — it does not replay the 23s measurement, which was taken against the
  retired `$( )` topology. Selftest coverage is not mutant coverage, so the
  stated zero-mutant-coverage limit is unchanged.

  Was: P2 finding #3 (conf 70, judgment) — the hang-path refutation evidence is
  prose, not a committed executable artifact
  (memory/tasks.d/2026-08-01-feat-mutation-sweep-harness.md:284), the same class
  as
  docs/solutions/logic-errors/verification-evidence-must-be-a-committed-executable-artifact.md.
  Deferred at the time as new-control design work in the harness's stated
  zero-mutant-coverage zone rather than a mechanical edit. That read held up:
  plan review found two defects in the first design — a function closing over
  globals unset on the selftest path, and assertions that a fixture writing
  nothing would have satisfied — either of which would have shipped a control
  that passes with the guard removed.

- [ ] P3 — **RESOLVED marker format in the finding-#12 entry** (finding #5,
  conf 65, judgment) — same file, :274. architecture-reviewer: reformat to
  the file's `- [x] **RESOLVED <date> —**` lead; previous-comments-reviewer:
  current styling is a reasonable fusion with no in-section precedent to
  diverge from. Agents disagree; operator's call, cost is one cosmetic edit
  either way.
