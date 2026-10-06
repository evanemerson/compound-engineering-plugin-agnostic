# Residuals — feat/roles/coord-wt-write-guard (punch-list item 12)

## 2026-10-06 — /cepa:plan-review findings deferred with a build decision

Source: `todos/review-2026-10-06-092800.md` (12 findings; #1-#4 applied to the
local plan, the 8 below are `judgment`). Each carries the decision this worker
took at build; the decision is reviewable in the PR.

1. **P2 #5 — checker legs can pass on zero matches** — zero command files, or
   zero or several probe blocks, are MISS.
2. **P2 #6 — parked writes have no landing branch** — a parked run that
   commits branches first per autonomy §10b.
3. **P3 #7 — mid-rebase or bisect reads as parked** — fourth probe condition:
   no operation marker in the absolute git-dir.
4. **P3 #8 — git-dir handoff document dies with the worktree** — a failed
   `check-ignore` takes the git-dir path; the prompt names the hazard.
5. **P3 #9 — report-only does not name skipped steps** — autonomy §10f's
   table names them per command.
6. **P3 #10 — checker not in the mutation-sweep registry** — not registered,
   matching `check-batch-sibling-match.sh`; in-script mutants are the proof.
7. **P3 #11 — U2/U4 lack test scenarios** — added to the local plan.
8. **P3 #12 — undefined "brief"; unlabeled gate numbers** — fixed in the
   local plan.
