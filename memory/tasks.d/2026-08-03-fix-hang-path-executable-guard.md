# Residuals — fix/hang-path-executable-guard

## 2026-08-03 — plan review (todos/review-2026-08-03-090808.md)

20 findings — 5 P1, 11 P2, 4 P3; 19 applied to the plan before build, 1 deferred
below. The build then closed `todos/review-2026-08-02-231333.md` finding #3.

- [ ] P3 — **RESOLVED marker format in the finding-#12 entry** (carried from
  `2026-08-02-fix-sweep-hung-checker-bound.md`, finding #5, conf 65, judgment) —
  `memory/tasks.d/2026-08-01-feat-mutation-sweep-harness.md:274`.
  architecture-reviewer: reformat to the file's `- [x] **RESOLVED <date> —**`
  lead; previous-comments-reviewer: current styling is a reasonable fusion with
  no in-section precedent to diverge from. **Still the operator's call — asked,
  not decided.** This branch edited that file's neighbourhood and deliberately
  left the marker untouched in both directions rather than settling it by
  omission. Cost is one cosmetic edit either way.

- [ ] P3 — **`--selftest` is wired only to the weekly job, not the PR gate**
  (plan review finding #11, cut from scope). `.github/workflows/mutation-sweep.yml:84-85`
  is its only invocation; `model-pins.yml` has none.
  `docs/solutions/logic-errors/verification-evidence-must-be-a-committed-executable-artifact.md`
  says it *"belongs in the PR gate"*, so today a change breaking the new hang
  guard stays green for up to a week. Wiring it in changes the gate for every
  future PR and drags `model-pins.yml:53`'s "Both checks finish in seconds" with
  it — now measurably false, since `--selftest` costs ~24s (two deliberate
  multi-second waits). Deliberately not built here: separate deliverable, own CI
  review surface, nothing in this branch depends on it.

- [ ] P3 — **the driver's `exit 2` statement has no direct coverage** (plan
  review finding #10). `scripts/run-mutation-sweep.sh:675-681` exits 2 on
  `CLASS = HARNESS-ERROR`; the new hang case asserts that *condition* but not
  the statement, because the loop exits before `resolve_outcome` and covering
  the statement itself needs a whole-driver subprocess run. Recorded so the gap
  is stated rather than implied by a passing suite.
