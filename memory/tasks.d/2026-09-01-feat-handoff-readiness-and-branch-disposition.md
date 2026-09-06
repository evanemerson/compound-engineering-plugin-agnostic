## 2026-09-01 — feat/handoff-readiness-and-branch-disposition

- **Deferred from the handoff change (decision D2): the merged-local-branch
  inventory belongs in `/cepa:sweep`, not `/cepa:handoff`.**
  The source prompt asked `/cepa:handoff` to list every merged local branch no
  worktree holds (capped ~20, worktree-held skipped), as a cleanup byproduct.
  Motivation is measured and real: one operator repo had **88 local branches,
  14 of the first 40 checked had merged PRs**, and nothing in the normal
  workflow ever deletes one — `gh pr merge` squashes on GitHub, a ship is a
  ref-to-ref push, `git fetch --prune` only touches remote-tracking refs.

  Not built in handoff because it is the only part of that command probing
  state unrelated to the session being wrapped up, and it costs N `gh pr list`
  calls — making it the slowest step in a command run *often* and *under
  context pressure*. The proposed cap was itself an admission the output does
  not fit the document.

  `/cepa:sweep` is the right home: already the scheduled unattended janitor,
  already reads residual sinks, already runs when nobody is waiting on it.
  Handoff keeps the **current branch's** disposition only (cheap, session
  state, load-bearing for the emitted prompt).

  Suggested shape for the sweep implementation: one `gh pr list --state merged
  --json headRefName --limit N` call matched against `git branch` locally,
  rather than per-branch `gh` calls. Skip anything in `git worktree list` and
  say so. Never emit a deletion for an unverified branch — `git branch -D` is
  unconditional (verified 2026-09-01: it destroys an unmerged branch with no
  refusal).

- Readiness conditions are a **starting set, not closed** (handoff Step 2.5).
  Refine against real sessions: a condition that never fires is noise; a
  missing one is the next incident. Worth revisiting after ~10 real runs.
