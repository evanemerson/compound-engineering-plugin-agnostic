# Residuals — feat/roles/coord-wt-write-guard (punch-list item 12)

## 2026-10-06 — /cepa:plan-review findings deferred with a build decision

Source: `todos/review-2026-10-06-092800.md` (12 findings; #1-#4 applied to the
local plan, the 8 below are `judgment`). Each carries the decision this worker
took at build; the decision is reviewable in the PR.

1. **P2 #5 — checker legs can pass on zero matches** — zero command files, or
   zero or several probe blocks, are MISS.
2. **P2 #6 — parked writes have no landing branch** — a parked run that
   commits branches first per autonomy §10b.
   Narrowed by PR #87 review #1: only task and lfg write from a park, and
   both already branch.
3. **P3 #7 — mid-rebase or bisect reads as parked** — fourth probe condition:
   no operation marker in the absolute git-dir.
4. **P3 #8 — git-dir handoff document dies with the worktree** — a failed
   `check-ignore` takes the git-dir path; the prompt names the hazard.
   Superseded by PR #87 review #4: the git-dir fallback is removed; the
   report carries a document whose normal path is tracked.
5. **P3 #9 — report-only does not name skipped steps** — autonomy §10f's
   table names them per command.
6. **P3 #10 — checker not in the mutation-sweep registry** — not registered,
   matching `check-batch-sibling-match.sh`; in-script mutants are the proof.
7. **P3 #11 — U2/U4 lack test scenarios** — added to the local plan.
8. **P3 #12 — undefined "brief"; unlabeled gate numbers** — fixed in the
   local plan.

## 2026-10-06 — /cepa:review PR #87 findings deferred

Source: `todos/review-2026-10-06-095036.md` (19 findings; 16 applied on this
branch, the 3 below deferred). Numbers are the findings file's.

9. **P2 #7 — §10f grows the autonomy skill** — roles shard item 19 (layering
   #16) is still open; the split now owes §10f as well as §10a-10e.
10. **P3 #16 — a worker that branches during a PARKED coordinator run moves
    HEAD under it** — stated limit in §10f; a per-commit
    `git symbolic-ref --short HEAD` re-check at every commit site is not built.
11. **P3 #17 — roles items 17 (lfg autostash) and 18 (resolve-pr author
    gating) stay open** — the new pointers sit above them and change neither.

## 2026-10-06 — compound candidates (inline capture; a worker cannot write the main checkout's gitignored docs/solutions)

12. **[learning] A state guard that every command measures for itself turns
    on its own parent run.** The first cut of §10f had each command run the
    probe at its own start. A PARKED `/cepa:task` then branched — correctly —
    and its own plan-review and review steps re-measured, read "on a branch",
    and wrote their findings outside `todos/`, where lfg would parse zero.
    Measure once per top-level run, and let every step inherit the verdict.
    Found by three review agents, not by the checker: the checker tests the
    measurement, and the defect was in where the measurement was called.
    Candidate solution doc for `/cepa:compound`, with a Detection bullet: "a
    guard cited at the top of a command that other commands invoke as a step".
13. **[learning] `sequencer/` is the only trace of a paused multi-commit
    cherry-pick or revert after `git reset --hard`.** `CHERRY_PICK_HEAD`,
    `MERGE_MSG` and `AUTO_MERGE` are gone, the tree is clean, HEAD is detached
    inside the trunk, and `git status` still says "Cherry-pick currently in
    progress". Reproduced by the adversarial reviewer. Any "is an operation in
    progress" probe needs it in its marker list.
