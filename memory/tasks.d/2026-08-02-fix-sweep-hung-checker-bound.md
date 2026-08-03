# Residuals — fix/sweep-hung-checker-bound

## 2026-08-02 — review of PR #35 (todos/review-2026-08-02-231333.md)

5 findings — 0 P1, 3 P2, 2 P3; 3 applied in the same commit as the findings
file, 2 deferred below.

- [ ] P2 — **the hang-path refutation evidence is prose, not a committed
  executable artifact** (finding #3, conf 70, judgment) —
  memory/tasks.d/2026-08-01-feat-mutation-sweep-harness.md:284. The
  23s-at-outer-bound measurement should become a driver selftest or controls
  case that plants a hung/TERM-ignoring checker, runs the real
  `> $WORK/controls.out` capture at a scaled bound, and asserts
  return-at-bound + HARNESS-ERROR/exit 2. Deferred: new-control design work
  in the harness's stated zero-mutant-coverage zone, not a mechanical edit.
  Same class as
  docs/solutions/logic-errors/verification-evidence-must-be-a-committed-executable-artifact.md.

- [ ] P3 — **RESOLVED marker format in the finding-#12 entry** (finding #5,
  conf 65, judgment) — same file, :274. architecture-reviewer: reformat to
  the file's `- [x] **RESOLVED <date> —**` lead; previous-comments-reviewer:
  current styling is a reasonable fusion with no in-section precedent to
  diverge from. Agents disagree; operator's call, cost is one cosmetic edit
  either way.
